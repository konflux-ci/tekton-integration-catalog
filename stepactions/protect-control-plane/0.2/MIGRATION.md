# Migration from protect-control-plane 0.1 to 0.2

Update the StepAction resolver path to `stepactions/protect-control-plane/0.2/protect-control-plane.yaml` to use the new resource parameters. Version 0.2 keeps the 32-vCPU / 64-GiB profile values as defaults, so callers that do not set the new parameters retain the existing tuning.

The existing `max-pods`, `max-parallel-image-pulls`, `etcd-cpu`, and
`etcd-memory` parameter names are retained. The new tuning parameters use
kebab-case.

For a 24-vCPU / 48-GiB machine, override the parameters as follows:

| Parameter | Value |
| --- | --- |
| `apiserver-cpu` | `1500m` |
| `apiserver-memory` | `3Gi` |
| `apiserver-max-inflight` | `400` |
| `apiserver-max-mutating-inflight` | `200` |
| `controller-manager-cpu` | `1000m` |
| `controller-manager-memory` | `2Gi` |
| `scheduler-cpu` | `500m` |
| `scheduler-memory` | `1Gi` |
| `etcd-cpu` | `2000m` |
| `etcd-memory` | `4Gi` |
| `containerd-memory-min` | `4G` |
| `containerd-gomaxprocs` | `6` |
| `containerd-gomemlimit` | `8GiB` |
| `containerd-max-concurrent-downloads` | `30` |
| `max-pods` | `250` |
| `max-parallel-image-pulls` | `10` |
| `coredns-replicas` | `2` |

The StepAction does not detect the instance size automatically; callers must supply these overrides for 24-vCPU / 48-GiB instances.
