# Deprovision ROSA - Tekton Task

## Overview

This Tekton Task is designed to handle the collection of test artifacts and the deprovisioning of an OpenShift ROSA cluster. It automates the following steps:

1. **Collect Artifacts**: Gathers test artifacts if the pipeline did not succeed.
2. **Inspect and Upload Artifacts**: Checks for sensitive information and uploads artifacts to an OCI container registry.
3. **Deprovision ROSA Cluster**: Deletes the OpenShift ROSA cluster if specified.
4. **Remove Tags from Subnets**: Cleans up AWS subnet tags associated with the cluster.
5. **Remove Load Balancers**: Deletes AWS load balancers linked to the cluster.

## Parameters

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `test-name` | string | The name of the test being executed. | - |
| `ocp-login-command` | string | Command to log in to the OpenShift cluster. | - |
| `oci-container` | string | ORAS container registry URI where artifacts will be stored. | - |
| `cluster-name` | string | The name of the OpenShift cluster to be deleted. | - |
| `konflux-test-infra-secret` | string | Secret containing credentials for testing infrastructure. | - |
| `cloud-credential-key` | string | Key within the secret that stores AWS ROSA configuration details. | - |
| `pipeline-aggregate-status` | string | The status of the pipeline (e.g., `Succeeded`, `Failed`). | `None` |

## Volumes

- `konflux-test-infra-volume`: Mounts the `konflux-test-infra` secret to access AWS and OCI credentials.

## Steps

### 1. Collect Artifacts

- Logs into the OpenShift cluster.
- If the pipeline failed, it gathers additional artifacts using `gather-extra.sh`.

### 2. Inspect and Upload Artifacts

- Scans artifacts for sensitive data and removes detected files.
- Authenticates to the OCI container registry.
- Pushes the artifacts with manifest annotations.

### 3. Deprovision ROSA Cluster

- Reads AWS credentials and ROSA token from the secret.
- Logs into AWS and ROSA CLI.
- Initiates the cluster deletion process.

### 4. Remove Tags from Subnets

- Retrieves AWS subnet IDs related to the cluster.
- Removes Kubernetes tags from the associated AWS subnets.

### 5. Remove Load Balancers

- Identifies AWS load balancers associated with the cluster.
- Deletes them in batches to avoid API limits.

## Usage

This task can be included in a Tekton pipeline to ensure proper cleanup and artifact handling after test execution. Example pipeline snippet:

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
        value: tasks/rosa/hosted-cp/rosa-hcp-deprovision/0.2/rosa-hcp-deprovision.yaml
  params:
    - name: test-name
      value: "$(context.pipelineRun.name)"
    - name: ocp-login-command
      value: "$(tasks.provision-rosa.results.ocp-login-command)"
    - name: oci-container
      value: "$(params.oci-container-repo):$(context.pipelineRun.name)"
    - name: pull-request-author
      value: "$(tasks.test-metadata.results.pull-request-author)"
    - name: git-revision
      value: "$(tasks.test-metadata.results.git-revision)"
    - name: pull-request-number
      value: "$(tasks.test-metadata.results.pull-request-number)"
    - name: git-repo
      value: "$(tasks.test-metadata.results.git-repo)"
    - name: git-org
      value: "$(tasks.test-metadata.results.git-org)"
    - name: cluster-name
      value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
    - name: konflux-test-infra-secret
      value: "$(params.konflux-test-infra-secret)"
    - name: cloud-credential-key
      value: "$(params.cloud-credential-key)"
    - name: pipeline-aggregate-status
      value: "$(tasks.status)"
```

## Requirements

- OpenShift CLI (`oc`)
- AWS CLI (`aws`)
- ROSA CLI (`rosa`)
- ORAS CLI (`oras`)
- Leak detection tool (`leaktk`)
- jq (for JSON parsing)

## Notes

- Ensure that the `konflux-test-infra` secret contains the necessary AWS credentials and ROSA tokens.
- Artifact storage requires authentication to an OCI container registry.

### Not suitable for upstream communities