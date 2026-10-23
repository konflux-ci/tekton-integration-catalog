# Migration from 0.3 to 0.4

Update the Task resolver path from
`tasks/mapt-oci/kind-ibm-provision/0.3/kind-ibm-provision.yaml` to
`tasks/mapt-oci/kind-ibm-provision/0.4/kind-ibm-provision.yaml`.

Version 0.4 changes the default Kind Kubernetes version from `v1.34` to
`v1.37` and resolves protect-control-plane StepAction 0.4. The `version`
parameter remains available: `v1.36` and `v1.37` are accepted when
`harden-control-plane=true`. Other versions fail in the hardening StepAction
before it patches the cluster. With hardening disabled, the Task still passes
the requested version to mapt.

Required hardening and readiness failures now propagate through the Task's
final failure-check step. The Task saves hardening diagnostics to a log file
named for its TaskRun UID before the OCI upload step. Pin `catalog-revision`
to a commit that contains both Task 0.4 and StepAction 0.4.
