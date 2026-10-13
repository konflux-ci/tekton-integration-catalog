# protect-control-plane StepAction

Configures a KinD node for burst E2E workloads. When enabled, it tunes
containerd and kubelet settings, installs metrics-server, scales CoreDNS, and
patches the Kubernetes control-plane components. Hardening is disabled by
default; set `harden-control-plane` to `"true"` to apply the configuration.

## Parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `harden-control-plane` | `"false"` | Enable cluster setup and control-plane tuning. |
| `kubeconfig-dir` | `"/opt/cluster-info"` | Directory containing the target cluster's `kubeconfig`. |
| `node-name` | `"kind-mapt-control-plane"` | KinD control-plane node to configure. |
| `kubeconfig-volume-name` | Required | Parent Task volume containing the `kubeconfig`. |

Control-plane resource and API server defaults:

| Parameter | Default |
| --- | --- |
| `APISERVER_CPU` | `"2000m"` |
| `APISERVER_MEMORY` | `"4Gi"` |
| `APISERVER_MAX_INFLIGHT` | `"800"` |
| `APISERVER_MAX_MUTATING_INFLIGHT` | `"400"` |
| `CONTROLLER_MANAGER_CPU` | `"2000m"` |
| `CONTROLLER_MANAGER_MEMORY` | `"4Gi"` |
| `SCHEDULER_CPU` | `"2000m"` |
| `SCHEDULER_MEMORY` | `"4Gi"` |
| `etcd-cpu` | `"3000m"` |
| `etcd-memory` | `"8Gi"` |

Node and runtime defaults:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `CONTAINERD_MEMORY_MIN` | `"8G"` | Containerd memory reservation. |
| `CONTAINERD_GOMAXPROCS` | `"8"` | Go runtime parallelism. |
| `CONTAINERD_GOMEMLIMIT` | `"12GiB"` | Go runtime memory limit. |
| `CONTAINERD_MAX_CONCURRENT_DOWNLOADS` | `"50"` | Concurrent image downloads. |
| `KUBELET_MAX_PODS` | `"350"` | Maximum pods on the node. |
| `KUBELET_MAX_PARALLEL_IMAGE_PULLS` | `"15"` | Parallel kubelet image pulls. |
| `COREDNS_REPLICAS` | `"3"` | CoreDNS replica count. |

The defaults are recommended for 32-vCPU / 64-GiB machines. For 24-vCPU /
48-GiB machines, use the following overrides:

| Parameter | Value |
| --- | --- |
| `APISERVER_CPU` | `"1500m"` |
| `APISERVER_MEMORY` | `"3Gi"` |
| `APISERVER_MAX_INFLIGHT` | `"400"` |
| `APISERVER_MAX_MUTATING_INFLIGHT` | `"200"` |
| `CONTROLLER_MANAGER_CPU` | `"1000m"` |
| `CONTROLLER_MANAGER_MEMORY` | `"2Gi"` |
| `SCHEDULER_CPU` | `"500m"` |
| `SCHEDULER_MEMORY` | `"1Gi"` |
| `etcd-cpu` | `"2000m"` |
| `etcd-memory` | `"4Gi"` |
| `CONTAINERD_MEMORY_MIN` | `"4G"` |
| `CONTAINERD_GOMAXPROCS` | `"6"` |
| `CONTAINERD_GOMEMLIMIT` | `"8GiB"` |
| `CONTAINERD_MAX_CONCURRENT_DOWNLOADS` | `"30"` |
| `KUBELET_MAX_PODS` | `"250"` |
| `KUBELET_MAX_PARALLEL_IMAGE_PULLS` | `"10"` |
| `COREDNS_REPLICAS` | `"2"` |

## Usage

Reference this StepAction from a parent Task and pass the name of its
kubeconfig volume. The example uses the default 32-vCPU / 64-GiB tuning:

```yaml
- name: protect-control-plane
  ref:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog
      - name: revision
        value: main
      - name: pathInRepo
        value: stepactions/protect-control-plane/0.2/protect-control-plane.yaml
  params:
    - name: harden-control-plane
      value: "true"
    - name: kubeconfig-volume-name
      value: cluster-info
```

For a 24-vCPU / 48-GiB machine, add the corresponding values from the override
table to `params`. The StepAction does not detect machine size automatically.

## Migration from 0.1

Version 0.2 keeps the existing 32-vCPU / 64-GiB tuning as its defaults. Existing
callers can opt into 0.2 without changing those values. The kubelet parameters
are now named `KUBELET_MAX_PODS` and `KUBELET_MAX_PARALLEL_IMAGE_PULLS`; callers
that set the former `max-pods` or `max-parallel-image-pulls` parameters must
update their names. `etcd-cpu` and `etcd-memory` are unchanged. See
[`MIGRATION.md`](MIGRATION.md) for the complete 24-vCPU / 48-GiB override list.
