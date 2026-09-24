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

Sizing defaults to 32 vCPUs and 64 GiB and can be overridden with `cpus` and
`memory`. The standard mapt tags are always applied:
`iac=mapt`, `k8s-type=kind`, and `cluster-name=<id>`.
