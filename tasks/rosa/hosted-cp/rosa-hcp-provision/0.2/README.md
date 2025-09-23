# ROSA HCP Provision

**Version:** 0.2

## Overview

This Tekton Task automates the provisioning of an ephemeral OpenShift cluster using Red Hat OpenShift on AWS (ROSA) with Hosted Control Planes (HCP). It handles the following:

1. **Fetch and Configure AWS & ROSA Credentials**: Reads credentials from a Openshift secret.
2. **Provision OpenShift Cluster**: Deploys a ROSA HCP cluster with the specified configuration.
3. **Generate Cluster Login Credentials**: Outputs the `oc login` command to access the cluster.
4. **Validate Cluster Readiness**: Ensures all required cluster operators are operational.
5. **Push Logs to OCI Container**: Secures and stores provisioning logs in an OCI artifact registry.

## Parameters

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `ocp-version` | string | The OpenShift Container Platform (OCP) version to deploy. | - |
| `cluster-name` | string | Unique name for the OpenShift cluster. | - |
| `machine-type` | string | AWS EC2 instance type for worker nodes (e.g., `m5.xlarge`). | - |
| `replicas` | string | Number of worker nodes in the cluster. | `3` |
| `konflux-test-infra-secret` | string | Secret containing AWS and ROSA credentials. | - |
| `cloud-credential-key` | string | Key within the secret storing AWS ROSA configurations. | - |
| `oci-container` | string | ORAS container registry URI to store provisioning logs. | - |

## Results

| Name | Description |
|------|-------------|
| `ocp-login-command` | Command to log in to the newly provisioned OpenShift cluster. |

## Volumes

- `konflux-test-infra-volume`: Mounts the `konflux-test-infra` secret to access credentials.

## Steps

### 1. Provision ROSA HCP Cluster

- Reads AWS credentials and ROSA token from the secret.
- Logs into AWS and ROSA CLI.
- Retrieves the correct OpenShift version for the Hosted Control Plane.
- Creates the cluster using predefined parameters.
- Waits for the cluster to become available.
- Generates an admin account for logging into the cluster.
- Outputs the `oc login` command as a result.

### 2. Push Logs to OCI Container

- Runs a secure log collection process.
- Pushes logs to the specified OCI container registry.

### 3. Validate Cluster Readiness

- Logs into the newly created cluster.
- Ensures all cluster operators are in a healthy state.

## Usage

This task can be integrated into a Tekton pipeline to automate the provisioning of a ROSA HCP cluster. Example pipeline snippet:

```yaml
- name: provision-rosa-hcp
  taskRef:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: tasks/rosa/hosted-cp/rosa-hcp-provision/0.2/rosa-hcp-provision.yaml
  params:
    - name: ocp-version
      value: "4.13"
    - name: cluster-name
      value: "test-cluster-123"
    - name: machine-type
      value: "m5.xlarge"
    - name: replicas
      value: "3"
    - name: konflux-test-infra-secret
      value: "aws-rosa-secret"
    - name: cloud-credential-key
      value: "credentials.json"
    - name: oci-container
      value: "quay.io/example/rosa-logs:latest"
```

## Requirements

- OpenShift CLI (`oc`)
- AWS CLI (`aws`)
- ROSA CLI (`rosa`)
- ORAS CLI (`oras`)
- jq (for JSON parsing)

## Notes

- Ensure the `konflux-test-infra` secret contains valid AWS credentials and ROSA tokens.
- Cluster provisioning may take several minutes depending on AWS region and workload.
- Artifacts and logs are securely stored in the provided OCI container registry.

### Not suitable for upstream communities