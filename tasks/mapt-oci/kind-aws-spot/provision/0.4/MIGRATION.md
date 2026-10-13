# Migration from 0.3 to 0.4

Version 0.4 adds parameters for the `protect-control-plane` StepAction's
resource tuning. Defaults retain the 32-vCPU / 64-GiB hardening profile.
Override the tuning values for smaller machines, using the documented
24-vCPU / 48-GiB values when applicable.

Update the Task resolver path from
`tasks/mapt-oci/kind-aws-spot/provision/0.3/kind-aws-provision.yaml` to
`tasks/mapt-oci/kind-aws-spot/provision/0.4/kind-aws-provision.yaml`.
