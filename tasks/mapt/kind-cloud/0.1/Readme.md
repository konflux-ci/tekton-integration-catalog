# 🚀 Tekton Task: `kind-aws`

Version: 0.1

Provision or destroy a Kind cluster on AWS using the [Mapt CLI](https://github.com/redhat-developer/mapt).
This task is ideal for managing ephemeral Kind clusters within Tekton CI/CD pipelines.

---

## 📘 Overview

This task orchestrates infrastructure creation or teardown on AWS and runs a Kind-based Kubernetes cluster using Mapt.
It also securely outputs a `kubeconfig` as a Kubernetes Secret for use in subsequent pipeline steps.

Supported capabilities include:

- Spot instance usage for cost optimization
- Nested virtualization for enhanced performance
- Customizable CPU, memory, and architecture settings
- Optional timeout-based auto-destroy functionality
- Clean secret generation with owner references to pipeline/task resources

---

## 🔧 Parameters

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `secret-aws-credentials` | Kubernetes Secret containing AWS credentials. | — | ✅ |
| `id` | Unique environment identifier. | — | ✅ |
| `operation` | Operation type: `create` or `destroy`. | — | ✅ |
| `cluster-access-secret-name` | Optional: Name for the output Secret containing kubeconfig. | `''` | ❌ |
| `ownerKind` | Owning resource type (`PipelineRun` or `TaskRun`). | `PipelineRun` | ❌ |
| `ownerName` | Name of the owning resource. | — | ✅ |
| `ownerUid` | UID of the owning resource. | — | ✅ |
| `arch` | Machine architecture: `x86_64` or `arm64`. | `x86_64` | ❌ |
| `cpus` | Number of CPUs to provision. | `8` | ❌ |
| `memory` | Memory (GiB) to allocate. | `64` | ❌ |
| `nested-virt` | Enable nested virtualization support. | `false` | ❌ |
| `spot` | Use spot instances where available. | `true` | ❌ |
| `version` | Kubernetes version to install. | `v1.32` | ❌ |
| `tags` | Tags for AWS resources. | `''` | ❌ |
| `debug` | Enable verbose logging and expose credentials (use with caution). | `false` | ❌ |
| `timeout` | Auto-destroy timeout duration (Go format). | `''` | ❌ |

---

## 📤 Result

| Result | Description |
|--------|-------------|
| `cluster-access-secret` | Name of the generated Secret containing the cluster's `kubeconfig`. |

Example Secret output:

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

The task expects the following Secret format for AWS authentication:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-<name>
type: Opaque
data:
  access-key: <base64>
  secret-key: <base64>
  region: <base64>
  bucket: <base64>
```

---

## 📦 Example PipelineRun

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: aws-cluster-run-
spec:
  pipelineSpec:
    tasks:
      - name: provision
        taskRef:
          name: kind-aws
        params:
          - name: secret-aws-credentials
            value: aws-my-creds
          - name: id
            value: test-cluster
          - name: operation
            value: create
          - name: ownerName
            value: $(context.pipelineRun.name)
          - name: ownerUid
            value: $(context.pipelineRun.uid)
```

---

## ⚠️ Notes and Warnings

- **Debug Mode**: If `debug` is set to `true`, credentials and logs will be printed to the output – use only in secured environments.
- **Auto Cleanup**: By specifying owner references, deleting the `PipelineRun` or `TaskRun` will automatically clean up generated secrets.

---

## 🛠️ Requirements

- Tekton Pipelines v0.44.x+
- Valid AWS Secret for resource provisioning
- Access to the Mapt container image: `quay.io/redhat-developer/mapt:v0.9.0`
