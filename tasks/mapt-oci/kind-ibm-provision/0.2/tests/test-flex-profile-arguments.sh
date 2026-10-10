#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
STEP_ACTION="${REPO_ROOT}/stepactions/kind-ibm-provisioner/0.2/kind-ibm-provisioner.yaml"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

mkdir -p "${WORK_DIR}/bin" "${WORK_DIR}/ibm-credentials" "${WORK_DIR}/cluster-info"
for file in IBMCLOUD_API_KEY IBMCLOUD_COS_ACCESS_KEY_ID IBMCLOUD_COS_SECRET_ACCESS_KEY; do
  printf 'test-value' > "${WORK_DIR}/ibm-credentials/${file}"
done

cat > "${WORK_DIR}/bin/mapt" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" > "${MAPT_ARGS_FILE}"
EOF
chmod +x "${WORK_DIR}/bin/mapt"

python3 - "${STEP_ACTION}" "${WORK_DIR}/step-action.sh" "${WORK_DIR}/ibm-credentials" <<'PY'
import pathlib
import sys
import yaml

step_action = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
script = step_action["spec"]["script"]
script = script.replace("/opt/ibm-credentials", sys.argv[3])
pathlib.Path(sys.argv[2]).write_text(script)
PY

assert_mapt_args() {
  python3 - "${WORK_DIR}/mapt-args" "$@" <<'PY'
import pathlib
import sys

args = pathlib.Path(sys.argv[1]).read_bytes().decode().split("\0")[:-1]
expected = sys.argv[2:]
if args != expected:
    raise SystemExit(f"expected mapt args {expected!r}, got {args!r}")
PY
}

run_step_action() {
  env \
    PATH="${WORK_DIR}/bin:${PATH}" \
    MAPT_ARGS_FILE="${WORK_DIR}/mapt-args" \
    CLUSTER_INFO_PATH="${WORK_DIR}/cluster-info" \
    PARAM_ID="test-flex" \
    PARAM_REGION="us-south" \
    PARAM_ZONE="us-south-2" \
    PARAM_VERSION="v1.34" \
    PARAM_COMPUTE_SIZES="$1" \
    PARAM_CPUS="24" \
    PARAM_MEMORY="48" \
    PARAM_BACKED_URL="s3://test-bucket/mapt/kind/test-flex" \
    PARAM_EXTRA_PORT_MAPPINGS="[]" \
    PARAM_TAGS="" \
    PARAM_DEBUG="false" \
    PARAM_TIMEOUT="" \
    bash "${WORK_DIR}/step-action.sh"
}

run_step_action "cxf-24x48"
assert_mapt_args \
  ibmcloud kind create \
  --project-name kind-test-flex \
  --backed-url s3://test-bucket/mapt/kind/test-flex \
  --conn-details-output "${WORK_DIR}/cluster-info" \
  --version v1.34 \
  --extra-port-mappings '[]' \
  --tags iac=mapt,k8s-type=kind,cluster-name=test-flex \
  --compute-sizes cxf-24x48

run_step_action ""
assert_mapt_args \
  ibmcloud kind create \
  --project-name kind-test-flex \
  --backed-url s3://test-bucket/mapt/kind/test-flex \
  --conn-details-output "${WORK_DIR}/cluster-info" \
  --version v1.34 \
  --extra-port-mappings '[]' \
  --tags iac=mapt,k8s-type=kind,cluster-name=test-flex \
  --cpus 24 \
  --memory 48
