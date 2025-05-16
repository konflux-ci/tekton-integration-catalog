# 🚀 Tekton Task: `deploy-konflux-ci`

Version: 0.1

This task automates the deployment of [Konflux CI](https://github.com/konflux-ci/konflux-ci) into a Kubernetes or OpenShift environment.
It is tailored for use within OpenShift Pipelines (Tekton) and supports full setup, including dependencies, policies, and test resources.

---

## 📘 Overview

The task performs the following operations:

1. Clones the Konflux CI Git repository.
2. Checks out the specified branch.
3. Retrieves a `kubeconfig` from a Kubernetes Secret to access a target cluster.
4. Executes the deployment sequence using `deploy-deps.sh`, `wait-for-all.sh`, and `deploy-konflux.sh`.
5. Optionally deploys test resources using `deploy-test-resources.sh`.

---

## 🔧 Parameters

| Name | Description | Default | Required |
|------|-------------|---------|----------|
| `cluster-access-secret` | Name of the Secret containing a base64-encoded `kubeconfig`. | — | ✅ |
| `namespace` | Namespace where the `cluster-access-secret` is located. | — | ✅ |
| `repo-url` | Git repository URL of the Konflux CI deployment scripts. | `https://github.com/konflux-ci/konflux-ci.git` | ❌ |
| `repo-branch` | Git branch to check out. | `main` | ❌ |
| `create-test-resources` | Flag to determine whether test resources should be deployed. | `true` | ❌ |

---

## 📁 Volumes

| Name | Type | Description |
|------|------|-------------|
| `workdir` | `emptyDir` | Used as working directory for cloning and running scripts. |

---

## 🧱 Steps

1. **`clone-konflux-ci`**
   Clones the Konflux CI repository and checks out the specified branch.

2. **`deploy-konflux-ci`**
   - Fetches and decodes the kubeconfig from the provided secret.
   - Sets up the Kubernetes context.
   - Runs deployment and policy scripts.

3. **`deploy-test-resources`** *(conditional)*
   - Deploys additional test resources if `create-test-resources` is set to `true`.

---

## 🔐 Required Secret Format

The task expects a Kubernetes Secret with kubeconfig that looks like:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-secret-name>
  namespace: <your-namespace>
type: Opaque
data:
  kubeconfig: <base64-encoded-kubeconfig>
```

---

## 📦 Example Usage in a PipelineRun

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: deploy-konflux-
spec:
  pipelineSpec:
    tasks:
      - name: deploy
        taskRef:
          name: deploy-konflux-ci
        params:
          - name: cluster-access-secret
            value: my-kubeconfig-secret
          - name: namespace
            value: my-secret-namespace
          - name: repo-url
            value: https://github.com/konflux-ci/konflux-ci.git
          - name: repo-branch
            value: main
          - name: create-test-resources
            value: "true"
```

---

## ⚠️ Notes

- Make sure the `kubeconfig` provided has sufficient permissions to deploy resources.
- Scripts such as `deploy-deps.sh` and `deploy-konflux.sh` must exist in the specified Git repository.
- Test resources are deployed only when `create-test-resources` is explicitly set to `"true"`.
