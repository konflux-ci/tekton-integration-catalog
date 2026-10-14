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

Version 0.2 introduced the IBM Flex `cxf-24x48` sizing default (24 vCPUs and
48 GiB); version 0.3 retains it. Override it with `compute-sizes`, for example
`cxf-32x64`. When
`compute-sizes` is nonempty, it takes precedence over `cpus` and `memory`. Set
it to an empty string to select a profile from those CPU and memory values.
Version 0.1 used 32 vCPUs and 64 GiB by default. To retain that sizing, set
`compute-sizes` to `""`; the `cpus` and `memory` fallback defaults remain 32
and 64. See [MIGRATION.md](MIGRATION.md) when upgrading.
The standard mapt tags are always applied:
`iac=mapt`, `k8s-type=kind`, and `cluster-name=<id>`.

When `harden-control-plane` is `true`, the Task forwards control-plane tuning
parameters to the [protect-control-plane StepAction](../../../../stepactions/protect-control-plane/0.2/README.md).
Their defaults retain the 32-vCPU / 64-GiB profile. For the default
`cxf-24x48` machine, set the documented 24-vCPU / 48-GiB overrides.

## Parameters

### Provisioning and task parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `secret-ibmcloud-credentials` | — | Secret with IBM Cloud API key and COS HMAC credentials. |
| `id` | — | Unique cluster identifier. |
| `catalog-revision` | `main` | Git revision used to resolve nested StepActions. |
| `catalog-url` | `https://github.com/konflux-ci/tekton-integration-catalog.git` | Git repository used to resolve nested StepActions. |
| `cluster-access-secret-name` | PipelineRun name | Secret name for the generated kubeconfig. |
| `ssh-credentials-secret-name` | `""` | Secret name for SSH connection details; empty disables this Secret. |
| `ownerKind` | `PipelineRun` | Owner kind for generated Secrets. |
| `ownerName` | — | Name of the owner resource. |
| `ownerUid` | — | UID of the owner resource. |
| `region` | `us-south` | IBM Cloud region. |
| `zone` | `us-south-2` | IBM Cloud availability zone. |
| `version` | `v1.34` | Kubernetes version for the Kind cluster. |
| `compute-sizes` | `cxf-24x48` | mapt instance profile; overrides `cpus` and `memory` when nonempty. |
| `cpus` | `32` | vCPUs used when `compute-sizes` is empty. |
| `memory` | `64` | Memory in GiB used when `compute-sizes` is empty. |
| `backed-url` | — | Shared IBM COS S3 URL for provision and deprovision. |
| `tags` | `""` | Additional IBM Cloud resource tags. |
| `extra-port-mappings` | port 30012 → 8180 | Additional Kind port mappings as a JSON array. |
| `debug` | `false` | Enable verbose logging. |
| `timeout` | `""` | Automatic cluster destruction timeout. |
| `oci-ref` | — | OCI image reference for diagnostic logs. |
| `oci-credentials` | `konflux-test-infra` | Secret with OCI registry credentials. |

### Control-plane hardening and tuning parameters

`harden-control-plane` defaults to `false`. The tuning defaults target a
32-vCPU / 64-GiB machine. For `cxf-24x48`, use the override values documented
in the linked StepAction README.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `harden-control-plane` | `false` | Enable control-plane hardening. |
| `apiserver-cpu` | `2000m` | kube-apiserver CPU quantity applied to existing resource fields; missing requests or limits are not created. |
| `apiserver-memory` | `4Gi` | kube-apiserver memory quantity applied to existing fields; an entry is added only when none exists, without guaranteeing both requests and limits. |
| `apiserver-max-inflight` | `800` | Maximum concurrent non-mutating API requests. |
| `apiserver-max-mutating-inflight` | `400` | Maximum concurrent mutating API requests. |
| `controller-manager-cpu` | `2000m` | kube-controller-manager CPU quantity applied to existing resource fields; missing requests or limits are not created. |
| `controller-manager-memory` | `4Gi` | kube-controller-manager memory quantity applied to existing fields; an entry is added only when none exists, without guaranteeing both requests and limits. |
| `scheduler-cpu` | `2000m` | kube-scheduler CPU quantity applied to existing resource fields; missing requests or limits are not created. |
| `scheduler-memory` | `4Gi` | kube-scheduler memory quantity applied to existing fields; an entry is added only when none exists, without guaranteeing both requests and limits. |
| `etcd-cpu` | `3000m` | etcd CPU quantity applied to existing resource fields; missing requests or limits are not created. |
| `etcd-memory` | `8Gi` | etcd memory quantity applied to existing fields; an entry is added only when none exists, without guaranteeing both requests and limits. |
| `containerd-memory-min` | `8G` | containerd systemd memory reservation. |
| `containerd-gomaxprocs` | `8` | containerd Go runtime parallelism. |
| `containerd-gomemlimit` | `12GiB` | containerd Go runtime memory limit. |
| `containerd-max-concurrent-downloads` | `50` | Maximum concurrent container image downloads. |
| `max-pods` | `350` | Maximum pods allowed on the node. |
| `max-parallel-image-pulls` | `15` | Maximum concurrent kubelet image pulls. |
| `coredns-replicas` | `3` | Number of CoreDNS replicas. |

For the 24-vCPU / 48-GiB tuning overrides, see the
[StepAction README](../../../../stepactions/protect-control-plane/0.2/README.md).
