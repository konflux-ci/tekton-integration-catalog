# Tekton Task: `init-quay`

Version: 0.1

This task initializes a self-hosted [Quay](https://www.projectquay.io/) instance deployed on a Kind cluster for integration testing.

---

## Overview

The task performs the following operations:

1. Waits for the Quay pods to become ready in the target cluster.
2. Creates an admin user via the Quay initialization API.
3. Creates an organization and a robot account with owner permissions.
4. Stores the robot credentials and admin token as Kubernetes Secrets in the `quay` namespace.
5. Copies a source container image (including cosign signatures/attestations) into the local Quay registry.
6. Queries the Quay API for the copied image digest.
7. Stores image metadata in a ConfigMap for downstream test consumption.
8. Pushes task logs to an OCI artifact for archival.

---

## Parameters

| Name                     | Description                                                              | Default                                  | Required |
| :----------------------- | :----------------------------------------------------------------------- | :--------------------------------------- | :------- |
| `cluster-access-secret`  | Name of the Secret containing a `kubeconfig` for the target cluster.     | —                                        | Yes      |
| `source-image`           | Source image to copy into the self-hosted Quay (e.g. `quay.io/org/repo`).| `quay.io/hacbs-release-tests/dcmetromap` | No       |
| `org-name`               | Quay organization to create.                                             | `test-org`                               | No       |
| `robot-name`             | Robot account name to create within the organization.                    | `release-bot`                            | No       |
| `oci-ref`                | Full OCI artifact reference for storing task logs.                       | —                                        | Yes      |
| `credentials-secret-name`| Secret name containing OCI registry credentials for log storage.         | —                                        | Yes      |

---

## Results

| Name                | Description                                      |
| :------------------ | :----------------------------------------------- |
| `image-digest`      | The digest of the image copied into Quay.        |
| `quay-internal-host`| The in-cluster hostname of the Quay registry.    |

---

## Volumes

| Name             | Type     | Description                                                    |
| :--------------- | :------- | :------------------------------------------------------------- |
| `credentials`    | `secret` | Kubeconfig for the target cluster (from `cluster-access-secret`). |
| `logs`           | `emptyDir` | Working directory for log files.                              |
| `oci-credentials`| `secret` | OCI registry credentials for log artifact storage.             |

---

## Steps

1. **`init-quay`** — Initializes the Quay instance: creates admin user, organization, robot account, copies images, and stores credentials/metadata.
2. **`secure-push-oci`** — Pushes task logs to the specified OCI artifact reference.
3. **`fail-if-any-step-failed`** — Fails the task if any previous step encountered an error.

---

## Resources Created on the Target Cluster

The task creates the following resources in the target Kind cluster:

| Resource | Namespace | Name | Contents |
| :------- | :-------- | :--- | :------- |
| Secret   | `quay`    | `quay-robot-credentials` | `username`, `password`, `host` |
| Secret   | `quay`    | `quay-admin-token`       | `token` |
| ConfigMap| `quay`    | `quay-test-config`       | `image-digest`, `dest-repo`, `quay-internal-host` |

---

## Prerequisites

- A Kind cluster with Quay deployed in the `quay` namespace (service: `quay-service`).
- The Quay instance must be in its initial (uninitialized) state for admin user creation to succeed.

---

## Required Secrets Format

A Secret with a kubeconfig for the Kind cluster:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-secret-name>
type: Opaque
data:
  kubeconfig: <base64-encoded-kubeconfig>
```

A Secret with OCI registry credentials for log storage:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-secret-name>
type: Opaque
data:
  oci-storage-dockerconfigjson: <dockerconfigjson-content>
```
