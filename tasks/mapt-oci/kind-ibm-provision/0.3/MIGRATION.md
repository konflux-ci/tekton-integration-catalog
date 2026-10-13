# Migration from 0.2 to 0.3

Version 0.3 adds parameters for the `protect-control-plane` StepAction's
resource tuning. Defaults retain the 32-vCPU / 64-GiB hardening profile.
Callers using a smaller machine profile should override the tuning values; for
`cxf-24x48`, use the documented 24-vCPU / 48-GiB values in the StepAction
[README](../../../../stepactions/protect-control-plane/0.2/README.md).

Update the Task resolver path from
`tasks/mapt-oci/kind-ibm-provision/0.2/kind-ibm-provision.yaml` to
`tasks/mapt-oci/kind-ibm-provision/0.3/kind-ibm-provision.yaml`.
