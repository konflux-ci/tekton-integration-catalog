# kind-ibm-provisioner StepAction

Runs `mapt ibmcloud kind create` directly from the pinned mapt image. It
requires IBM API and COS HMAC credentials in a parent-provided Secret volume,
and writes `host`, `username`, `id_rsa`, and `kubeconfig` to the cluster-info
volume.

The `compute-sizes` parameter is passed to mapt as `--compute-sizes` and
defaults to IBM Flex profile `cxf-24x48`. If it is empty, the StepAction passes
`cpus` and `memory` instead.
