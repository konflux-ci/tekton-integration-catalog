"""Credential-free regression checks for the embedded hardening scripts."""

import os
import pathlib
import subprocess
import tempfile
import tomllib
import unittest

import yaml


STEP = pathlib.Path(__file__).resolve().parents[1] / "protect-control-plane.yaml"
SCRIPT = yaml.safe_load(STEP.read_text())["spec"]["script"]
HELPERS = "STEP_EXIT=0\n" + SCRIPT.split("STEP_EXIT=0\n", 1)[1].split("# ── Gate", 1)[0]


def embedded(name, marker):
    return SCRIPT.split(f"{name}=$(cat <<'{marker}'\n", 1)[1].split(f"\n{marker}\n", 1)[0]


def run_bash(body, env=None):
    return subprocess.run(
        ["bash", "-c", "set -o errexit -o nounset -o pipefail\n" + body],
        text=True,
        capture_output=True,
        env={**os.environ, **(env or {})},
        check=False,
    )


class RecoveryTests(unittest.TestCase):
    def test_transient_node_get_and_wrong_node_error(self):
        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() {
            if [[ "$1 $2" == "get node" ]]; then
              COUNT=$(cat "$STATE/count")
              echo $((COUNT + 1)) > "$STATE/count"
              if [[ "$MODE" == transient && "$COUNT" == 0 ]]; then
                echo 'temporary API timeout' >&2; return 1
              fi
              if [[ "$MODE" == wrong ]]; then
                echo 'Error from server (NotFound): nodes "wrong" not found' >&2; return 1
              fi
              echo True; return 0
            fi
            echo 'NAME STATUS'  # diagnostic node listing
          }
          wait_node_ready 6
        '''
        with tempfile.TemporaryDirectory() as state:
            pathlib.Path(state, "count").write_text("0")
            result = run_bash(HELPERS + mock, {"STATE": state, "MODE": "transient"})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("is Ready", result.stdout)
            self.assertNotIn("not found", result.stdout)
            pathlib.Path(state, "count").write_text("0")
            result = run_bash(HELPERS + mock, {"STATE": state, "MODE": "wrong"})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('nodes "wrong" not found', result.stdout)

    def test_pod_adoption_owner_and_cleanup_errors(self):
        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          kubectl() {
            local command=$1 object=${2:-}
            case "$command $object" in
              'run '*)
                echo "$object" > "$STATE/name"
                : > "$STATE/present"
                if [[ "$MODE" == late || "$MODE" == foreign ]]; then
                  echo 'etcdserver: request timed out' >&2; return 1
                fi
                echo "pod/$object created";;
              'get pod')
                [[ -f "$STATE/present" ]] || return 0
                if [[ "$*" == *go-template* ]]; then
                  if [[ "$MODE" == foreign ]]; then
                    echo "$3|someone-else"
                  else
                    echo "$3|${3##*-}"
                  fi
                else
                  echo Succeeded
                fi;;
              'logs '*) echo 'CHANGED=1';;
              'delete pod')
                if [[ "$MODE" == delete_fail ]]; then
                  echo 'deletion request timed out' >&2; return 1
                fi
                rm "$STATE/present";;
              *) echo "unexpected kubectl: $*" >&2; return 1;;
            esac
          }
          run_on_node setup-node ZWNobyBoaQ==
        '''
        for mode, success, expected in (
            ("late", True, "CHANGED=1"),
            ("foreign", False, "another invocation"),
            ("delete_fail", False, "cleanup unconfirmed"),
        ):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as state:
                result = run_bash(HELPERS + mock, {"STATE": state, "MODE": mode})
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                self.assertIn(expected, result.stdout, result.stdout + result.stderr)
                if success:
                    self.assertFalse(pathlib.Path(state, "present").exists())

    def test_late_created_pod_is_cleaned_before_failed_create_returns(self):
        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() {
            case "$1 $2" in
              'run '*) echo "$2" > "$STATE/name"; echo timeout >&2; return 1;;
              'get pod')
                COUNT=$(cat "$STATE/count")
                echo $((COUNT + 1)) > "$STATE/count"
                if [[ "$COUNT" -ge 3 && ! -f "$STATE/deleted" ]]; then
                  echo "$3|${3##*-}"
                fi;;
              'delete pod') : > "$STATE/deleted";;
              *) echo "unexpected kubectl: $*" >&2; return 1;;
            esac
          }
          run_on_node setup-node ZWNobyBoaQ==
        '''
        with tempfile.TemporaryDirectory() as state:
            pathlib.Path(state, "count").write_text("0")
            result = run_bash(HELPERS + mock, {"STATE": state})
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Found late pod", result.stdout)
            self.assertTrue(pathlib.Path(state, "deleted").exists())

    def test_named_node_poll_bounds_a_slow_request(self):
        mock = r'''
          NODE_NAME=wrong
          kubectl() {
            if [[ "$1 $2" == 'get node' ]]; then
              case "$*" in
                *--request-timeout=2s*|*--request-timeout=1s*) ;;
                *) echo 'request exceeded wait budget' >&2; return 2;;
              esac
              command sleep 1
              echo 'timed out looking up wrong' >&2
              return 1
            fi
            echo 'NAME STATUS'
          }
          wait_node_ready 2
        '''
        result = run_bash(HELPERS + mock)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timed out looking up wrong", result.stdout)
        self.assertNotIn("request exceeded wait budget", result.stdout)

    def test_new_ready_heartbeat_is_accepted(self):
        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() { echo 'True|2026-10-22T10:00:01Z'; }
          wait_node_ready 6 '2026-10-22T10:00:00Z'
        '''
        result = run_bash(HELPERS + mock)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("is Ready", result.stdout)

    def test_stale_ready_condition_is_rejected(self):
        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() { echo 'True|2026-10-22T10:00:00Z'; }
          wait_node_ready 6 '2026-10-22T10:00:00Z'
        '''
        result = run_bash(HELPERS + mock)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fresh=false", result.stdout)

    def test_changed_mirror_pod_waits_for_new_hash(self):
        mock = r'''
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() {
            COUNT=$(cat "$STATE/count")
            echo $((COUNT + 1)) > "$STATE/count"
            if [[ "$COUNT" -lt 2 ]]; then
              echo 'Running|true|old-hash|old-uid'
            else
              echo 'Running|true|new-hash|new-uid'
            fi
          }
          wait_pod_ready component=etcd 8 old-hash old-uid
        '''
        with tempfile.TemporaryDirectory() as state:
            pathlib.Path(state, "count").write_text("0")
            result = run_bash(HELPERS + mock, {"STATE": state})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(pathlib.Path(state, "count").read_text().strip(), "3")

    def test_patch_changed_noop_and_missing_inputs(self):
        patch = embedded("PATCH_SCRIPT", "PATCH")
        with tempfile.TemporaryDirectory() as root:
            script = pathlib.Path(root, "patch.sh")
            script.write_text(patch.replace("/etc/kubernetes", root))
            manifest_dir = pathlib.Path(root, "manifests")
            manifest_dir.mkdir()
            manifest = manifest_dir / "etcd.yaml"
            original = """spec:\n  containers:\n  - command:\n    - --data-dir=/var/lib/etcd\n    resources:\n      limits:\n        cpu: 100m\n        memory: 1Gi\n"""
            args = ["bash", str(script), "etcd", "2000m", "4Gi", "400", "200", "1000m", "2Gi", "500m", "1Gi", "2000m", "4Gi"]
            manifest.write_text(original)
            first = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            self.assertIn("CHANGED=1", first.stdout)
            second = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            self.assertIn("CHANGED=0", second.stdout)
            manifest.write_text(original.replace("--data-dir=/var/lib/etcd", "--other=1"))
            missing_anchor = subprocess.run(args, capture_output=True, text=True)
            self.assertNotEqual(missing_anchor.returncode, 0)
            self.assertIn("missing anchor", missing_anchor.stdout)
            self.assertNotIn("--quota-backend-bytes", manifest.read_text())
            manifest.unlink()
            missing_manifest = subprocess.run(args, capture_output=True, text=True)
            self.assertNotEqual(missing_manifest.returncode, 0)
            self.assertIn("not found", missing_manifest.stdout)

    def test_dead_cri_and_stale_lease_fail(self):
        node = embedded("NODE_SCRIPT", "INNER")
        with tempfile.TemporaryDirectory() as root:
            node = node.replace("/var/lib/kubelet", root + "/kubelet")
            node = node.replace("/etc/systemd/system", root + "/systemd")
            node = node.replace("/etc/containerd", root + "/containerd")
            for directory in ("kubelet", "containerd", "bin"):
                pathlib.Path(root, directory).mkdir()
            pathlib.Path(root, "kubelet/config.yaml").write_text("maxPods: 10\n")
            for command, content in (("systemctl", "exit 0"), ("crictl", "exit 1"), ("sleep", "exit 0"), ("containerd", 'cat "$2"')):
                executable = pathlib.Path(root, "bin", command)
                executable.write_text("#!/bin/sh\n" + content + "\n")
                executable.chmod(0o755)
            path = pathlib.Path(root, "node.sh")
            path.write_text(node)
            configs = (
                ('version = 2\n[plugins."io.containerd.grpc.v1.cri"]\nmax_concurrent_downloads = 3\n', "io.containerd.grpc.v1.cri"),
                ('version = 3\n[grpc]\n', "io.containerd.cri.v1.images"),
            )
            for config_text, local_section in configs:
                pathlib.Path(root, "containerd/config.toml").write_text(config_text)
                result = subprocess.run(
                    ["bash", str(path), "250", "10", "4G", "6", "8GiB", "30"],
                    capture_output=True, text=True,
                    env={**os.environ, "PATH": root + "/bin:" + os.environ["PATH"]},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("CRI unhealthy after 10 attempts", result.stdout)
                config = tomllib.loads(pathlib.Path(root, "containerd/config.toml").read_text())
                self.assertEqual(config["plugins"][local_section]["max_concurrent_downloads"], 30)
                self.assertEqual(config["plugins"]["io.containerd.transfer.v1.local"]["max_concurrent_downloads"], 30)

        mock = r'''
          NODE_NAME=kind-mapt-control-plane
          sleep() { SECONDS=$((SECONDS + $1)); }
          kubectl() { echo '2026-10-22T10:00:00Z'; }
          wait_lease_renewal '2026-10-22T10:00:00Z' 6
        '''
        result = run_bash(HELPERS + mock)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not renew its Lease", result.stdout)

    def test_support_failures_are_fatal(self):
        support = SCRIPT.split("configure_cluster_support() {", 1)[1].split("\n}\n\n# ================================================================\n#  Phase 1", 1)[0]
        for mode, expected in (
            ("fetch_fail", "installation failed"),
            ("image_entry_fail", "image entry missing or ambiguous"),
            ("apply_fail", "installation failed"),
            ("args_fail", "argument patch failed"),
            ("metrics_rollout_fail", "Metrics-server rollout failed"),
            ("scale_fail", "CoreDNS scale failed"),
            ("coredns_patch_fail", "CoreDNS resource patch failed"),
            ("coredns_rollout_fail", "CoreDNS rollout failed"),
        ):
            with self.subTest(mode=mode):
                mock = r'''
                  COREDNS_REPLICAS=2
                  curl() {
                    [[ "$MODE" == fetch_fail ]] && return 1
                    while (($#)); do
                      if [[ "$1" == --output ]]; then
                        if [[ "$MODE" == image_entry_fail ]]; then
                          printf 'image: unexpected-image\n' > "$2"
                        else
                          printf 'image: registry.k8s.io/metrics-server/metrics-server:v0.9.0\n' > "$2"
                        fi
                        return 0
                      fi
                      shift
                    done
                    return 1
                  }
                  kubectl() {
                    if [[ "$MODE" == apply_fail && "$1" == apply ]]; then return 1; fi
                    if [[ "$MODE" == args_fail && "$1 $2 $3" == 'patch deployment metrics-server' ]]; then return 1; fi
                    if [[ "$MODE" == metrics_rollout_fail && "$1 $2 $3" == 'rollout status deployment/metrics-server' ]]; then return 1; fi
                    if [[ "$MODE" == scale_fail && "$1" == scale ]]; then return 1; fi
                    if [[ "$MODE" == coredns_patch_fail && "$1 $2 $3" == 'patch deployment coredns' ]]; then return 1; fi
                    if [[ "$MODE" == coredns_rollout_fail && "$1 $2 $3" == 'rollout status deployment/coredns' ]]; then return 1; fi
                    if [[ "$1 $2 $3" == 'get deployment metrics-server' ]]; then
                      if [[ "$*" == *'.args}'* ]]; then
                        [[ "$MODE" == args_fail ]] && echo '[]' || echo '[--kubelet-insecure-tls]'
                      else
                        echo 'registry.k8s.io/metrics-server/metrics-server@sha256:d9862115e7c7881280d3d75ca26bda8ffc0fc213315979575bf23ce9826205c0'
                      fi
                    elif [[ "$1 $2 $3" == 'get deployment coredns' ]]; then
                      echo '2|2|512Mi|128Mi|200m'
                    fi
                    return 0
                  }
                  configure_cluster_support
                '''
                result = run_bash(HELPERS + "configure_cluster_support() {" + support + "\n}\n" + mock, {"MODE": mode})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(expected, result.stdout, result.stdout + result.stderr)
                self.assertNotIn("Cluster Ready", result.stdout)


if __name__ == "__main__":
    unittest.main()
