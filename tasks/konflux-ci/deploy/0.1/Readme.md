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
4. Optionally modifies kustomization files if specific component overrides are provided.
5. Executes the deployment sequence using `deploy-deps.sh`, `wait-for-all.sh`, and `deploy-konflux.sh`.
6. Optionally deploys test resources using `deploy-test-resources.sh`.

---

## 🔧 Parameters

| Name                      | Description                                                                                                                               | Default                                        | Required |
| :------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------- | :------- |
| `cluster-access-secret`   | Name of the Secret containing a base64-encoded `kubeconfig`.                                                                              | —                                              | ✅       |
| `repo-url`                | Git repository URL of the Konflux CI deployment scripts.                                                                                  | `https://github.com/konflux-ci/konflux-ci.git` | ❌       |
| `repo-branch`             | Git branch to check out.                                                                                                                  | `main`                                         | ❌       |
| `create-test-resources`   | Flag to determine whether test resources should be deployed.                                                                              | `true`                                         | ❌       |
| `component-name`          | The GitHub repository name of the Konflux CI component to customize (e.g., `build-service`). Used for image or K8s manifest overrides. | `''`                                           | ❌       |
| `component-image-repository` | Overrides the container image repository for the `component-name` (e.g., `quay.io/my-org/my-custom-image`).                                | `''`                                           | ❌       |
| `component-image-tag`     | Overrides the container image tag for the `component-name` (e.g., `latest`, `my-feature-branch`).                                         | `''`                                           | ❌       |
| `component-pr-owner`      | GitHub owner (user/org) of the fork/PR providing custom Kubernetes manifests for the `component-name`.                                    | `''`                                           | ❌       |
| `component-pr-sha`        | Commit SHA of the PR (from `component-pr-owner`) supplying custom Kubernetes manifests for the `component-name`.                            | `''`                                           | ❌       |

---

### ✨ Advanced: Component Overrides

The parameters starting with `component-` allow for targeted customization of a specific Konflux CI component during deployment.

* To use these overrides, you **must** specify the `component-name`.
* **Image Override**: If you provide `component-name` along with `component-image-repository` and/or `component-image-tag`, the task will attempt to modify the deployment to use the specified container image for that component.
* **Kubernetes Manifest Override**: If you provide `component-name` along with `component-pr-owner` and `component-pr-sha`, the task will attempt to fetch the component's Kubernetes manifests from the specified GitHub pull request, allowing you to test changes from a specific fork and commit.

These parameters are particularly useful for development and testing of individual Konflux CI components.

---

## 📁 Volumes

| Name      | Type       | Description                                            |
| :-------- | :--------- | :----------------------------------------------------- |
| `workdir` | `emptyDir` | Used as working directory for cloning and running scripts. |

---

## 🧱 Steps

1. **`clone-konflux-ci`**
    Clones the Konflux CI repository and checks out the specified branch.
2. **`update-kustomization`** *(conditional)*
    If `component-name` is provided, this step modifies the kustomization files to use custom images or manifest sources for the specified component.
3. **`get-kubeconfig`**
    Fetches and decodes the kubeconfig from the provided secret and sets up the Kubernetes context.
4. **`deploy`**
    Runs main deployment scripts (`deploy-deps.sh`, `wait-for-all.sh`, `deploy-konflux.sh`).
5. **`create-test-resources`** *(conditional)*
    Deploys additional test resources if `create-test-resources` is set to `true`.

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
