
# 🚀 Tekton Task: `kind-aws-provision`

**Version:** 0.1

Create a Kind (Kubernetes in Docker) cluster on AWS using the [Mapt CLI](https://github.com/redhat-developer/mapt).
This task is ideal for managing **ephemeral clusters** in Tekton-based CI/CD workflows.

---

## ✅ Requirements

- Tekton Pipelines v0.44.x or newer
- Valid AWS credentials stored as a Kubernetes Secret

---

## 📘 Overview

This task provisions a single-node Kubernetes cluster on AWS using Mapt. It outputs a `kubeconfig` as a Kubernetes Secret for use in later pipeline steps.

### Supported Features

- Spot instance provisioning for cost savings
- Nested virtualization support
- Customizable CPU, memory, and architecture
- Optional timeout for auto-destroy
- Owner-referenced Secret creation for lifecycle management

---

## 🔧 Parameters

| Name                          | Description                                                                 | Default     | Required |
|-------------------------------|-----------------------------------------------------------------------------|-------------|----------|
| `secret-aws-credentials`      | Kubernetes Secret with AWS credentials (`access-key`, `secret-key`, etc.)  | —           | ✅       |
| `id`                          | Unique identifier for the Kind cluster environment                         | —           | ✅       |
| `cluster-access-secret-name` | Optional: name for the output kubeconfig Secret                             | `''`        | ❌       |
| `ownerKind`                   | Type of resource owning the Secret (`PipelineRun`, `TaskRun`)               | `PipelineRun`| ❌       |
| `ownerName`                   | Name of the owning resource                                                 | —           | ✅       |
| `ownerUid`                    | UID of the owning resource                                                  | —           | ✅       |
| `arch`                        | Instance architecture (`x86_64`, `arm64`)                                   | `x86_64`    | ❌       |
| `cpus`                        | Number of vCPUs to provision                                                | `16`        | ❌       |
| `memory`                      | Memory in GiB                                                               | `64`        | ❌       |
| `nested-virt`                 | Enable nested virtualization                                                | `false`     | ❌       |
| `spot`                        | Use spot instances                                                          | `true`      | ❌       |
| `spot-increase-rate`         | % increase on spot price to improve instance allocation                     | `20`        | ❌       |
| `version`                     | Kubernetes version                                                          | `v1.32`     | ❌       |
| `tags`                        | AWS resource tags                                                           | `''`        | ❌       |
| `debug`                       | Enable verbose output (prints credentials; use with caution)               | `false`     | ❌       |
| `timeout`                     | Auto-destroy timeout (`1h`, `30m`, etc.)                                    | `''`        | ❌       |

---

## 📤 Result

| Result                   | Description                                                   |
|--------------------------|---------------------------------------------------------------|
| `cluster-access-secret` | Name of the generated Kubernetes Secret containing kubeconfig  |

### Example output Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <generated-or-specified-name>
type: Opaque
data:
  kubeconfig: <base64-encoded>
```

---

## 🔐 AWS Credentials Secret Format

Create a Kubernetes Secret like this:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-my-creds
type: Opaque
data:
  access-key: <base64>
  secret-key: <base64>
  region: <base64>
  bucket: <base64>
```

---

## 📦 Example: How to Use the Kubeconfig in Another Task

After provisioning the cluster, you can make the generated `kubeconfig` available to all task steps by directly mounting the Secret containing it.
**Use a `stepTemplate` and a Secret-based volume to simplify kubeconfig access.**

### ✅ Recommended Configuration

```yaml
volumes:
  - name: credentials
    secret:
      secretName: $(params.cluster-access-secret)

stepTemplate:
  env:
    - name: KUBECONFIG
      value: "/credentials/kubeconfig"
  volumeMounts:
    - name: credentials
      mountPath: /credentials
```

### 💡 Benefits

- Automatically sets the `KUBECONFIG` environment variable for every step.
- No need to manually decode or copy the kubeconfig.
- Compatible with CLI tools like `kubectl`, `helm`, etc.

---

## 🔐 Permissions Note

The **ServiceAccount** (used to run the `Konflux PipelineRun`) must have RBAC permissions to manage Secrets in the namespace where the `cluster-access-secret` will be created. These permissions are required to dynamically create and manage the kubeconfig Secret for testing in Ephemeral Clusters.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-kind-role
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create"]
```

Bind this role to your pipeline's ServiceAccount with a `RoleBinding`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tekton-secret-manager-binding
subjects:
  - kind: ServiceAccount
    name: <your-service-account>
    namespace: <namespace>
roleRef:
  kind: Role
  name: tekton-secret-manager
  apiGroup: rbac.authorization.k8s.io
```

> **Note:** Without these permissions, the task will fail when attempting to create the kubeconfig Secret.
