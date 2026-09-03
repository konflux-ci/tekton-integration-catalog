# Deprovision ROSA - Tekton Task

**Version:** 0.3

## Overview

This Tekton Task handles the collection of test artifacts and the deprovisioning of an OpenShift ROSA HCP cluster. It automates the following steps:

1. **Collect Artifacts**: Gathers test artifacts if the pipeline did not succeed.
2. **Inspect and Upload Artifacts**: Checks for sensitive information and uploads artifacts to an OCI container registry.
3. **Deprovision ROSA Cluster**: Deletes the OpenShift ROSA HCP cluster and, once deletion completes, removes the managed OIDC config that was created during provisioning.
4. **Remove Tags from Subnets**: Cleans up AWS subnet tags associated with the cluster.

## Changes from 0.2

The `deprovision-rosa` step now cleans up all per-cluster AWS resources created by `rosa-hcp-provision` 0.3. When `oidc-config-id` is provided, after the cluster deletion completes it:

1. Deletes the per-cluster operator roles (`rosa delete operator-roles --prefix <cluster-name>`).
2. Deletes the per-cluster managed OIDC config (`rosa delete oidc-config`).

This ensures each provisioning run starts with a clean slate and avoids OIDC provider or operator role conflicts.

The `remove-load-balancers` step has been removed. Load balancers are cleaned up automatically as part of cluster deletion.

## Parameters

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `test-name` | string | The name of the test being executed. | - |
| `ocp-login-command` | string | Command to log in to the OpenShift cluster. | - |
| `oci-container` | string | ORAS container registry URI where artifacts will be stored. | - |
| `cluster-name` | string | The name of the OpenShift cluster to be deleted. | - |
| `oidc-config-id` | string | ID of the managed OIDC config created during provisioning. Pass the `oidc-config-id` result from `rosa-hcp-provision`. | `""` |
| `konflux-test-infra-secret` | string | Secret containing credentials for testing infrastructure. | - |
| `cloud-credential-key` | string | Key within the secret that stores AWS ROSA configuration details. | - |
| `oci-credentials-secret` | string | Secret containing OCI registry credentials. | - |
| `oci-credentials-secret-key` | string | Key within the OCI credentials secret that holds the registry credentials in `.dockerconfigjson` format. | `.dockerconfigjson` |
| `pipeline-aggregate-status` | string | The status of the pipeline (e.g., `Succeeded`, `Failed`). | `None` |

## Volumes

- `konflux-test-infra-volume`: Mounts the `konflux-test-infra-secret` to access AWS/ROSA credentials.
- `oci-credentials-volume`: Mounts the `oci-credentials-secret` to access OCI registry credentials. The key within the secret is controlled by `oci-credentials-secret-key`.

## Steps

### 1. Collect Artifacts

- Logs into the OpenShift cluster.
- If the pipeline failed, gathers additional artifacts using `gather-extra.sh`.

### 2. Inspect and Upload Artifacts

- Scans artifacts for sensitive data and removes detected files.
- Authenticates to the OCI container registry.
- Pushes the artifacts with manifest annotations.
- Runs with `onError: continue` so that upload failures never block cluster deprovisioning.

### 3. Deprovision ROSA Cluster

- Reads AWS credentials and ROSA token from the secret.
- Logs into AWS and ROSA CLI.
- Initiates cluster deletion (`rosa delete cluster`). Failures are non-fatal and logged as warnings.
- If `oidc-config-id` is provided, waits for the cluster to finish uninstalling, then:
  - Deletes the per-cluster operator roles (`rosa delete operator-roles --prefix <cluster-name>`).
  - Deletes the per-cluster managed OIDC config (`rosa delete oidc-config`).
  - Each cleanup command is failure-tolerant: errors are logged as warnings and do not abort the step.

### 4. Remove Tags from Subnets

- Retrieves AWS subnet IDs related to the cluster.
- If the cluster no longer exists in ROSA (e.g. already deleted), subnet tag removal is skipped gracefully.
- Removes Kubernetes tags from the associated AWS subnets. Failures are non-fatal and logged as warnings.

## Usage

```yaml
- name: deprovision-rosa-collect-artifacts
  when:
    - input: "$(tasks.test-metadata.results.test-event-type)"
      operator: in
      values: ["pull_request"]
  taskRef:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: tasks/rosa/hosted-cp/rosa-hcp-deprovision/0.3/rosa-hcp-deprovision.yaml
  params:
    - name: test-name
      value: "$(context.pipelineRun.name)"
    - name: ocp-login-command
      value: "$(tasks.provision-rosa.results.ocp-login-command)"
    - name: oidc-config-id
      value: "$(tasks.provision-rosa.results.oidc-config-id)"
    - name: oci-container
      value: "$(params.oci-container-repo):$(context.pipelineRun.name)"
    - name: cluster-name
      value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
    - name: konflux-test-infra-secret
      value: "$(params.konflux-test-infra-secret)"
    - name: cloud-credential-key
      value: "$(params.cloud-credential-key)"
    - name: oci-credentials-secret
      value: "$(params.oci-credentials-secret)"
    - name: oci-credentials-secret-key
      value: "$(params.oci-credentials-secret-key)"
    - name: pipeline-aggregate-status
      value: "$(tasks.status)"
```

## Requirements

- OpenShift CLI (`oc`)
- AWS CLI (`aws`)
- ROSA CLI (`rosa`)
- ORAS CLI (`oras`)
- jq (for JSON parsing)

## Notes

- Ensure that the secret referenced by `konflux-test-infra-secret` contains the necessary AWS credentials and ROSA tokens.
- The `oci-credentials-secret` must contain a key matching `oci-credentials-secret-key` (default: `.dockerconfigjson`) with a valid `.dockerconfigjson`-format value that has push access to the target registry.
- `oidc-config-id` must be the result from `rosa-hcp-provision` 0.3. When using older provision versions that used a static OIDC config, leave this parameter empty and no operator roles or OIDC config cleanup will occur.
- Operator role and OIDC config deletion waits for the cluster to fully uninstall first. Both resources cannot be removed while the cluster is still active.

### Not suitable for upstream communities