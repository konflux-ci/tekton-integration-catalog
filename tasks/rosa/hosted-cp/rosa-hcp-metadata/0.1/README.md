# Generate ROSA HCP Cluster Metadata

## Overview

The `rosa-hcp-metadata` Tekton Task is responsible for generating a unique cluster name for an OpenShift ROSA (Red Hat OpenShift on AWS) cluster using Hosted Control Planes (HCP). This ensures each cluster has a distinct, non-colliding identifier.

The generated cluster name follows a predefined pattern:

``` shell
kx-<random-hex>
```

where:

- `kx` is a fixed prefix.
- `<random-hex>` is a 10-character hexadecimal string ensuring uniqueness.

This name can then be used in subsequent tasks for cluster provisioning, management, and deletion.

## Results

| Name           | Description                                   |
| -------------- | --------------------------------------------- |
| `cluster-name` | The generated name for the OpenShift cluster. |

## Steps

### 1. Generate Cluster Name

- Uses the `openssl` command to create a random 10-character hexadecimal string.
- Constructs a cluster name in the format `kx-<random-hex>`.
- Outputs the generated name for use in subsequent pipeline tasks.

## Usage Example

This task can be included in a Tekton pipeline to dynamically generate a cluster name before provisioning:

```yaml
- name: generate-cluster-name
  taskRef:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: tasks/rosa/hosted-cp/0.1/rosa-hcp-metadata/rosa-hcp-metadata.yaml
```

Then, in a subsequent task (e.g., `rosa-hcp-provision`), reference the generated name:

```yaml
- name: provision-rosa-cluster
  taskRef:
    name: rosa-hcp-provision
  params:
    - name: cluster-name
      value: "$(tasks.generate-cluster-name.results.cluster-name)"
```

## Requirements

- OpenSSL CLI (`openssl`) for generating the random hexadecimal string.

## Notes

- This ensures unique cluster names in different pipeline runs.
- The fixed `kx` prefix helps in identifying clusters created via Tekton automation.
- The cluster name is capped at a reasonable length to comply with OpenShift and AWS naming conventions.

### Not suitable for upstream communities