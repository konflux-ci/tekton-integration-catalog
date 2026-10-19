# protect-control-plane StepAction

Configures a KinD node for burst E2E workloads. When enabled, it tunes
containerd and kubelet settings, installs metrics-server, scales CoreDNS, and
patches the Kubernetes control-plane components. Hardening is disabled by
default; set `harden-control-plane` to `"true"` to apply the configuration.

## Parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `harden-control-plane` | `"false"` | Enable cluster setup and control-plane tuning. |
| `kubeconfig-dir` | `"/opt/cluster-info"` | Directory containing the target cluster's `kubeconfig`. |
| `node-name` | `"kind-mapt-control-plane"` | KinD control-plane node to configure. |
| `kubeconfig-volume-name` | Required | Parent Task volume containing the `kubeconfig`. |

Control-plane resource and API server defaults:

| Parameter | Default |
| --- | --- |
| `apiserver-cpu` | `"2000m"` |
| `apiserver-memory` | `"4Gi"` |
| `apiserver-max-inflight` | `"800"` |
| `apiserver-max-mutating-inflight` | `"400"` |
| `controller-manager-cpu` | `"2000m"` |
| `controller-manager-memory` | `"4Gi"` |
| `scheduler-cpu` | `"2000m"` |
| `scheduler-memory` | `"4Gi"` |
| `etcd-cpu` | `"3000m"` |
| `etcd-memory` | `"8Gi"` |

Node and runtime defaults:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `containerd-memory-min` | `"8G"` | Containerd memory reservation. |
| `containerd-gomaxprocs` | `"8"` | Go runtime parallelism. |
| `containerd-gomemlimit` | `"12GiB"` | Go runtime memory limit. |
| `containerd-max-concurrent-downloads` | `"50"` | Concurrent image downloads. |
| `max-pods` | `"350"` | Maximum pods on the node. |
| `max-parallel-image-pulls` | `"15"` | Parallel kubelet image pulls. |
| `coredns-replicas` | `"3"` | CoreDNS replica count. |

The defaults are recommended for 32-vCPU / 64-GiB machines. For 24-vCPU /
48-GiB machines, use the following overrides:

| Parameter | Value |
| --- | --- |
| `apiserver-cpu` | `"1500m"` |
| `apiserver-memory` | `"3Gi"` |
| `apiserver-max-inflight` | `"400"` |
| `apiserver-max-mutating-inflight` | `"200"` |
| `controller-manager-cpu` | `"1000m"` |
| `controller-manager-memory` | `"2Gi"` |
| `scheduler-cpu` | `"500m"` |
| `scheduler-memory` | `"1Gi"` |
| `etcd-cpu` | `"2000m"` |
| `etcd-memory` | `"4Gi"` |
| `containerd-memory-min` | `"4G"` |
| `containerd-gomaxprocs` | `"6"` |
| `containerd-gomemlimit` | `"8GiB"` |
| `containerd-max-concurrent-downloads` | `"30"` |
| `max-pods` | `"250"` |
| `max-parallel-image-pulls` | `"10"` |
| `coredns-replicas` | `"2"` |

## Usage

Reference this StepAction from a parent Task and pass the name of its
kubeconfig volume. The example uses the default 32-vCPU / 64-GiB tuning:

```yaml
- name: protect-control-plane
  ref:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog
      - name: revision
        value: main
      - name: pathInRepo
        value: stepactions/protect-control-plane/0.2/protect-control-plane.yaml
  params:
    - name: harden-control-plane
      value: "true"
    - name: kubeconfig-volume-name
      value: cluster-info
```

For a 24-vCPU / 48-GiB machine, add the corresponding values from the override
table to `params`. The StepAction does not detect machine size automatically.

## Migration from 0.1

Version 0.2 keeps the existing 32-vCPU / 64-GiB tuning as its defaults. Existing
callers can opt into 0.2 without changing those values. It preserves the
`max-pods`, `max-parallel-image-pulls`, `etcd-cpu`, and `etcd-memory` parameter
names from v0.1. The additional tuning parameters use kebab-case. See
[`MIGRATION.md`](MIGRATION.md) for the complete 24-vCPU / 48-GiB override list.
