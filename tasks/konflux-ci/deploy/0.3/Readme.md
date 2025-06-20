# 🚀 Tekton Task: `deploy-konflux-ci`

Version: 0.2

This task automates the deployment of [Konflux CI](https://github.com/konflux-ci/konflux-ci) into a Kubernetes or OpenShift environment.
It is tailored for use within OpenShift Pipelines (Tekton) and supports full setup, including dependencies, policies, and test resources.

---

## 📘 Overview

The task performs the following operations:

1. Clones the Konflux CI Git repository.
1. Checks out the specified branch.
1. Retrieves a `kubeconfig` from a Kubernetes Secret to access a target cluster.
1. Optionally modifies kustomization files if specific component overrides are provided.
1. Executes the deployment sequence using `deploy-deps.sh`, `wait-for-all.sh`, and `deploy-konflux.sh`.
1. Deploys image-controller, smee client and creates PaC secrets
1. Optionally deploys test resources using `deploy-test-resources.sh`.
1. Stores logs in specified OCI artifact

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
| `component-pr-source-branch`        | GitHub source branch of the pull request.     | `''`    | ❌       |
| `oci-ref`                     | Full OCI artifact reference used for storing logs from the Task's Steps    | -        | ✅       |
| `oci-credentials`             | The secret name containing credentials for container registry where the artifacts will be stored.  | -    | ✅       |
| `build-credentials`                     | A secret name containing credentials for deploying image-controller, smee.io and GitHub application used for building application using Konflux   | -        | ✅       |

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
1. **`update-kustomization`** *(conditional)*
    If `component-name` is provided, this step modifies the kustomization files to use custom images or manifest sources for the specified component.
1. **`get-kubeconfig`**
    Fetches and decodes the kubeconfig from the provided secret and sets up the Kubernetes context.
1. **`deploy-konflux-ci`**
    Runs main deployment scripts (`deploy-deps.sh`, `wait-for-all.sh`, `deploy-konflux.sh`).
1. **`deploy-image-controller-and-smee`** 
    Deploys image-controller and smee client and creates PaC secrets required for building Konflux Components
1. **`create-test-resources`** *(conditional)*
    Deploys additional test resources if `create-test-resources` is set to `true`.
1. **`secure-push-oci`**
    Stores logs from deploying konflux in OCI artifact
1. **`fail-if-any-step-failed`**
    If any of the previous steps fail, this step fails
---

## 🔐 Required Secrets Format

The task expects Kubernetes Secrets with kubeconfig that look like. It is also possible to have a single secret containing all required secret key/values:

1. A secret with kubeconfig for a Kubernetes/OpenShift cluster where konflux-ci will be deployed

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

2. A secret with container registry credentials valid for the specified OCI artifact ref that is used for storing artifacts (logs, cluster manifests, test results, etc.)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-secret-name>
  namespace: <your-namespace>
type: Opaque
data:
  oci-storage-dockerconfigjson: <container registry credentials in .dockerconfigjson format valid for the OCI artifact reference>
```

3. A secret with credential used for deploying image-controller, smee and configuring Pipelines as Code secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-secret-name>
  namespace: <your-namespace>
type: Opaque
data:
  quay-org-name: <A quay organization where repositories for component images will be created>
  quay-org-token: <A quay token of OAuth application for quay.io organization with scopes -  Administer organizations, Administer repositories, Create repositories>
  gh-app-id: <ID of the GitHub App used for sending events from GitHub repositories (to be built) to smee.io. See the doc here for more information: https://github.com/konflux-ci/konflux-ci?tab=readme-ov-file#enable-pipelines-triggering-via-webhooks>
  gh-app-private-key: <Private key of the GitHub App>
  gh-app-webhook-secret: <Webhook secret of the GitHub App>
  smee-channel: <smee.io URL used for redirecting events sent by GitHub App>
```