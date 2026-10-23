# Migration from protect-control-plane 0.3 to 0.4

Update the StepAction resolver path to
`stepactions/protect-control-plane/0.4/protect-control-plane.yaml` and pass the
new required `kubernetes-version` parameter. Hardening accepts `v1.36` and
`v1.37`; all other tuning parameters retain their 0.3 defaults. Version 0.3
remains available for callers that have not opted into the stronger recovery
checks.

## Failure behavior

Version 0.4 fails when an owned node-operation pod cannot be confirmed
complete and removed, when a changed static-pod manifest has not reached a
Ready mirror pod, when kubelet does not renew its Lease and report a newer
Ready heartbeat after restart, or when metrics-server or CoreDNS setup fails. These cases could appear successful
in 0.3. The IBM Task continues diagnostic and upload steps, then reports the
hardening failure through `fail-if-any-step-failed`.

## CLI and diagnostics

The pinned image contains kubectl v1.37.0 and Bash. Kubectl is within the
supported one-minor skew for Kubernetes v1.36 and v1.37 API servers. IBM Task
0.4 defaults `version` to `v1.37` and passes it to this StepAction. When the parent
Task mounts `/var/log-dir`, hardening output is appended to the shared OCI log
file while remaining visible in Tekton step logs.
