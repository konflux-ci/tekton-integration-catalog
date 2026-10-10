# kind-ibm-provision

Creates a Kind cluster on an IBM Cloud VSI with mapt and writes kubeconfig and
SSH connection details into Kubernetes Secrets.

The `secret-ibmcloud-credentials` Secret must contain `IBMCLOUD_API_KEY`,
`IBMCLOUD_COS_ACCESS_KEY_ID`, and `IBMCLOUD_COS_SECRET_ACCESS_KEY`. It may also
contain `IBMCLOUD_COS_ENDPOINT`. The `backed-url` must be an IBM COS S3 URL
shared with the matching deprovision Task, for example:

```text
s3://mapt-tekton-state/mapt/kind/$(params.id)
```

Sizing defaults to the IBM Flex `cxf-24x48` profile (24 vCPUs and 48 GiB).
Override it with `compute-sizes`, for example `cxf-32x64`. When
`compute-sizes` is nonempty, it takes precedence over `cpus` and `memory`. Set
it to an empty string to select a profile from those CPU and memory values.
The effective default is smaller than v0.1's 32-vCPU, 64-GiB sizing. To retain
that sizing, set `compute-sizes` to `""`; the `cpus` and `memory` fallback
defaults remain 32 and 64. See [MIGRATION.md](MIGRATION.md) when upgrading.
The standard mapt tags are always applied:
`iac=mapt`, `k8s-type=kind`, and `cluster-name=<id>`.
