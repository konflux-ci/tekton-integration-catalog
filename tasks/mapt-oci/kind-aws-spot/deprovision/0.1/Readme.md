
# 🚀 Tekton Task: `kind-aws-deprovision`

**Version:** 0.1

Safely deprovision a Kind cluster on AWS that was previously created using the [`kind-aws-provision`](../../provision/0.1/kind-aws-provision.yaml) task.

---

## 📘 Overview

This task uses the [Mapt CLI](https://github.com/redhat-developer/mapt) to tear down infrastructure created for ephemeral Kubernetes clusters.

In addition to the basic teardown, it can optionally:

- Retrieve and use the cluster’s `kubeconfig`
- Collect artifacts from the cluster (logs, metrics)
- Push collected artifacts to an OCI-compliant registry

### Key Features

- Safe and scoped cluster destruction based on a unique ID
- Uses AWS credentials from a Kubernetes Secret
- Supports debug mode for troubleshooting
- Artifact collection and optional registry upload

---

## 🔧 Parameters

| Name                      | Description                                                                                      | Default              | Required |
|---------------------------|--------------------------------------------------------------------------------------------------|----------------------|----------|
| `secret-aws-credentials`  | Kubernetes Secret name containing AWS credentials (`access-key`, `secret-key`, etc.)            | —                    | ✅        |
| `id`                      | Unique identifier for the Kind cluster environment to destroy                                   | —                    | ✅        |
| `debug`                   | Enable verbose output (prints sensitive info, use with caution)                                 | `false`              | ❌        |
| `pipeline-aggregate-status` | Status of the overall pipeline run (e.g., Succeeded, Failed). Used for conditional logic.    | `None`               | ❌        |
| `cluster-access-secret`   | Name of the Kubernetes Secret containing the base64-encoded kubeconfig                           | —                    | ✅        |
| `oci-container`           | ORAS-compliant OCI registry reference where collected artifacts will be pushed                  | —                    | ✅        |
| `oci-credentials`         | Name of the secret containing the `oci-storage-dockerconfigjson` key with registry credentials  | `konflux-test-infra` | ✅        |

---

## 🪄 Steps Breakdown

### ✅ Step: `get-kubeconfig`

Fetches the `kubeconfig` from a Kubernetes Secret and writes it to `/var/workdir/.kube/config`.

### ✅ Step: `collect-artifacts`

If the pipeline did not succeed, this step gathers logs and system artifacts from the cluster.

### ✅ Step: `secure-push-oci`

Pushes the collected artifacts to the provided OCI registry for archiving or debugging.

### ✅ Step: `destroy`

Uses the Mapt CLI to destroy the Kind cluster based on the provided environment ID.

---

## 🔐 Required Secrets

This task requires several Kubernetes Secrets to operate. Below are the expected formats and required keys:

### 🔑 `secret-aws-credentials`

Holds AWS credentials used by the Mapt CLI for deprovisioning.

**Required keys:**

- `access-key`
- `secret-key`
- `region`
- `bucket`

**Example:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-example
  namespace: default
type: Opaque
data:
  access-key: <BASE64_ENCODED_AWS_ACCESS_KEY>
  secret-key: <BASE64_ENCODED_AWS_SECRET_KEY>
  region: <BASE64_ENCODED_AWS_REGION>
  bucket: <BASE64_ENCODED_BUCKET_NAME>
```

---

### 🔑 `cluster-access-secret`

Provides the `kubeconfig` needed to connect to the Kind cluster. This secret is being created by [kind-aws-provision](../../provision/0.1/kind-aws-provision.yaml).

**Required key:**

- `kubeconfig`

**Example:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cluster-access
  namespace: default
type: Opaque
data:
  kubeconfig: <BASE64_ENCODED_KUBECONFIG>
```

---

### 🔑 `oci-credentials`

Used for authentication when pushing cluster artifacts to an OCI registry.

> ⚠️ **IMPORTANT:** The key **must** be named `oci-storage-dockerconfigjson`.
> If the key is missing or misnamed, the task will fail with an error such as:
> *failed to decode config file at /home/tool-box/.docker/config.json: invalid config format: read /home/tool-box/.docker/config.json: is a directory*

**Required key:**

- `oci-storage-dockerconfigjson`

**Example:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example
  namespace: sample-tenant
type: Opaque
data:
  oci-storage-dockerconfigjson: <BASE64_ENCODED_DOCKERCONFIGJSON>
```

Ensure this is a properly formatted `.dockerconfigjson` file and base64-encoded.

---

## ✅ Requirements

- Tekton Pipelines v0.44.x or newer
- Kubernetes Secret with valid AWS credentials

---

## ⚠️ Notes

- **Graceful Failures**: Most steps have `onError: continue`, which ensures that even in failed pipelines, diagnostics can be gathered before final cleanup.
