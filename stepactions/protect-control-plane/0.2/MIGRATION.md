# Migration from protect-control-plane 0.1 to 0.2

Update the StepAction resolver path to `stepactions/protect-control-plane/0.2/protect-control-plane.yaml` to use the new resource parameters. Version 0.2 keeps the 32-vCPU / 64-GiB profile values as defaults, so callers that do not set the new parameters retain the existing tuning.

The former `max-pods` and `max-parallel-image-pulls` parameters are now named `KUBELET_MAX_PODS` and `KUBELET_MAX_PARALLEL_IMAGE_PULLS`. `etcd-cpu` and `etcd-memory` are unchanged.

For a 24-vCPU / 48-GiB machine, override the parameters as follows:

| Parameter | Value |
| --- | --- |
| `APISERVER_CPU` | `1500m` |
| `APISERVER_MEMORY` | `3Gi` |
| `APISERVER_MAX_INFLIGHT` | `400` |
| `APISERVER_MAX_MUTATING_INFLIGHT` | `200` |
| `CONTROLLER_MANAGER_CPU` | `1000m` |
| `CONTROLLER_MANAGER_MEMORY` | `2Gi` |
| `SCHEDULER_CPU` | `500m` |
| `SCHEDULER_MEMORY` | `1Gi` |
| `etcd-cpu` | `2000m` |
| `etcd-memory` | `4Gi` |
| `CONTAINERD_MEMORY_MIN` | `4G` |
| `CONTAINERD_GOMAXPROCS` | `6` |
| `CONTAINERD_GOMEMLIMIT` | `8GiB` |
| `CONTAINERD_MAX_CONCURRENT_DOWNLOADS` | `30` |
| `KUBELET_MAX_PODS` | `250` |
| `KUBELET_MAX_PARALLEL_IMAGE_PULLS` | `10` |
| `COREDNS_REPLICAS` | `2` |

The StepAction does not detect the instance size automatically; callers must supply these overrides for 24-vCPU / 48-GiB instances.
