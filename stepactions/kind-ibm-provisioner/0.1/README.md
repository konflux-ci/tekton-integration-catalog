# kind-ibm-provisioner StepAction

Runs `mapt ibmcloud kind create` directly from the pinned mapt image. It
requires IBM API and COS HMAC credentials in a parent-provided Secret volume,
and writes `host`, `username`, `id_rsa`, and `kubeconfig` to the cluster-info
volume.
