# ROSA HCP Provision

**Version:** 0.3

## Overview

This Tekton Task automates the provisioning of an ephemeral OpenShift cluster using Red Hat OpenShift on AWS (ROSA) with Hosted Control Planes (HCP). It handles the following:

1. **Fetch and Configure AWS & ROSA Credentials**: Reads credentials from a Openshift secret.
2. **Provision OpenShift Cluster**: Deploys a ROSA HCP cluster with the specified configuration.
3. **Generate Cluster Login Credentials**: Outputs the `oc login` command to access the cluster.
4. **Validate Cluster Readiness**: Ensures all required cluster operators are operational.
5. **Push Logs to OCI Container**: Secures and stores provisioning logs in an OCI artifact registry.

## Changes from 0.2

- OCI registry credentials are now passed via a **dedicated secret** (`oci-credentials-secret`) instead of being bundled into the infrastructure secret (`konflux-test-infra-secret`). This keeps AWS/ROSA credentials and OCI push credentials separate.
- Each cluster run now gets fully isolated per-cluster AWS resources to avoid conflicts when provisioning against the same account and region:
  - A managed OIDC config is created dynamically (instead of using a static `aws-oidc-config-id`), giving each cluster a unique OIDC provider URL in IAM.
  - Operator roles are created per cluster using `cluster-name` as the prefix (instead of a static prefix), with their trust policy tied to the per-cluster OIDC config.
  - Account roles (Installer, Support, Worker) remain shared and are auto-discovered by the ROSA CLI via IAM tags.
- The static `operator-roles-prefix`, `aws-oidc-config-id`, `install-role-arn`, `support-role-arn`, and `worker-role-arn` keys are no longer read from the secret.
- The `oidc-config-id` result must be passed to `rosa-hcp-deprovision` 0.3 for cleanup.

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
| `oci-credentials-secret` | string | Secret containing OCI registry credentials. | - |
| `oci-credentials-secret-key` | string | Key within the OCI credentials secret that holds the registry credentials in `.dockerconfigjson` format. | `.dockerconfigjson` |

## Results

| Name | Description |
|------|-------------|
| `ocp-login-command` | Command to log in to the newly provisioned OpenShift cluster. |
| `oidc-config-id` | ID of the managed OIDC config created for this cluster. Pass this to `rosa-hcp-deprovision` for cleanup. |

## Volumes

- `konflux-test-infra-volume`: Mounts the `konflux-test-infra-secret` to access AWS/ROSA credentials.
- `oci-credentials-volume`: Mounts the `oci-credentials-secret` to access OCI registry credentials. The key within the secret is controlled by `oci-credentials-secret-key`.

## Usage

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
        value: tasks/rosa/hosted-cp/rosa-hcp-provision/0.3/rosa-hcp-provision.yaml
  params:
    - name: ocp-version
      value: "4.18"
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
    - name: oci-credentials-secret
      value: "my-quay-push-secret"
    - name: oci-credentials-secret-key
      value: ".dockerconfigjson"
```

The `oci-credentials-secret` must contain a key matching `oci-credentials-secret-key` (default: `.dockerconfigjson`) with a valid `.dockerconfigjson`-format value that has push access to the target registry.

## Requirements

- OpenShift CLI (`oc`)
- AWS CLI (`aws`)
- ROSA CLI (`rosa`)
- ORAS CLI (`oras`)
- jq (for JSON parsing)

## Secret structure

The `konflux-test-infra-secret` credential file must contain:

```json
{
  "aws": {
    "access-key-id": "...",
    "access-key-secret": "...",
    "aws-account-id": "...",
    "region": "...",
    "rosa-hcp": {
      "rosa-token": "...",
      "subnets-ids": "subnet-abc,subnet-def"
    }
  }
}
```

The following keys that were required in older versions are no longer needed: `aws-oidc-config-id`, `operator-roles-prefix`, `install-role-arn`, `support-role-arn`, `worker-role-arn`.

## Notes

- Account roles (Installer, Support, Worker) must exist in the AWS account and be tagged for ROSA discovery (i.e. created via `rosa create account-roles`). They are auto-discovered by the ROSA CLI and do not need to be specified explicitly.
- Cluster provisioning may take several minutes depending on AWS region and workload.
- Artifacts and logs are securely stored in the provided OCI container registry.

### Not suitable for upstream communities