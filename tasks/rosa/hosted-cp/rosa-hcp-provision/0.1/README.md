# ROSA HCP Provision

**Version:** 0.1

## Overview

The `rosa-hcp-provision` Tekton task automates the creation and provisioning of an ephemeral OpenShift cluster using Red Hat OpenShift on AWS (ROSA) with Hosted Control Planes (HCP). This task allows users to define OpenShift versions, AWS machine types, and other configurations to deploy a ROSA cluster on AWS.

## Task Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ocp-version` | string | The OpenShift Container Platform (OCP) version to deploy. | - |
| `cluster-name` | string | The unique name of the OpenShift cluster to be created. | - |
| `machine-type` | string | AWS EC2 instance type for worker nodes (e.g., `m5.xlarge`). | - |
| `replicas` | string | Number of worker nodes to provision. | `3` |
| `konflux-test-infra-secret` | string | Kubernetes secret name containing AWS and ROSA configuration credentials. | - |
| `cloud-credential-key` | string | The key within the secret storing AWS ROSA configurations. | - |

## Task Results

| Result | Description |
|--------|-------------|
| `ocp-login-command` | Command to log in to the newly provisioned OpenShift cluster. |

## Prerequisites

- AWS account with necessary permissions for ROSA provisioning.
- Pre-configured ROSA and AWS credentials stored in a Kubernetes secret.
- Installed dependencies such as AWS CLI and ROSA CLI.

## How It Works

1. Fetches ROSA and AWS credentials from the provided Kubernetes secret.
2. Configures AWS credentials for use with ROSA CLI.
3. Retrieves the full ROSA HCP version matching the requested OCP version.
4. Provisions the cluster using ROSA CLI with specified parameters.
5. Monitors the cluster creation process and logs provisioning status.
6. Generates a login command to access the provisioned cluster.

## Usage Example

```yaml
      runAfter:
        - <skip if not need>
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/konflux-qe-definitions.git
          - name: revision
            value: main
          - name: pathInRepo
            value: common/tasks/rosa/hosted-cp/rosa-hcp-provision/rosa-hcp-provision.yaml
      params:
        - name: cluster-name
          value: "$(tasks.rosa-hcp-metadata.results.cluster-name)"
        - name: ocp-version
          value: "$(params.ocp-version)"
        - name: replicas
          value: "$(params.replicas)"
        - name: machine-type
          value: "$(params.machine-type)"
        - name: aws-credential-secret
          value: "$(params.aws-credential-secret)"
        - name: hcp-config-secret
          value: "$(params.hcp-config-secret)"
```

### Not suitable for upstream communities