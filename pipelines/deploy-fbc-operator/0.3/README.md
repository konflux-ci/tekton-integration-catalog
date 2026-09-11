# "deploy-fbc-operator pipeline"
The deploy-fbc-operator pipeline automates the provisioning of an ephemeral HyperShift cluster via **OpenShift CI** and the deployment of an operator from a given FBC (File-Based Catalog) fragment. It automates the process of fetching an image digest mirror set, retrieving an unreleased bundle from the FBC, selecting an appropriate OpenShift version and architecture for cluster provisioning, installing the operator, and gathering cluster artifacts.

## 🚀 New in Version 0.3

Version `0.3` migrates cluster provisioning from the deprecated **Environment-as-a-Service (EaaS)**
to **OpenShift CI** ephemeral HyperShift clusters:

* The multi-step EaaS flow is replaced by the single
  [`provision-ephemeral-cluster`](https://github.com/openshift/konflux-tasks/blob/9751a2028f2b3b88e4204d5c42de8eda4ebb466f/tasks/provision-ephemeral-cluster/0.1/provision-ephemeral-cluster.yaml)
  task (`hypershift-hostedcluster-workflow`).
* The target OpenShift version is read directly from the FBC fragment (no EaaS supported-versions
  list is required).
* The image digest mirror set is injected via the provisioning task's `env-files` workspace as an
  `IMAGE_CONTENT_SOURCES` file.
* A new parameter was added: `CLUSTER_PROFILE` (default `aws-konflux-prod`). The
  `provision-ephemeral-cluster` task is resolved from a pinned `openshift/konflux-tasks` commit.

Versions `0.1` and `0.2` remain available and unchanged (EaaS-based) to avoid breaking existing
consumers, but they will stop working once EaaS reaches end of life. See the
[Migration Guide](MIGRATION.md) for upgrade instructions.

> **Prerequisite:** Using OpenShift CI shared cluster profiles requires access. See
> [requesting access to shared cluster profiles](https://konflux.pages.redhat.com/docs/users/testing/integration/third-parties/openshift-ci.html).

## Pipeline Flow
The pipeline consists of the following tasks:

1. **Validate Parameters (`validate-parameters`)**

   Validates whether all required parameters are properly passed to the pipeline.

2. **Parse Metadata (`parse-metadata`)**
   Extracts metadata from the provided *snapshot*, including:
     * FBC fragment container image
     * Source Git URL
     * Git revision

3. **Log Non Push Tasks (`log-non-push-tasks`)**
   Informs which tasks are going to be skipped for non `push` events, such as
   `pull_request` or `retest-all-comment`.

4. **Fetch Config Files (`fetch-config-files`)**
   - Retrieves the authorization token if the source Git repository is private.
   - Downloads `.tekton/images-mirror-set.yaml` and `bundle/tests/scorecard/config.yaml` from the source Git repository.
   - Stores the raw ImageDigestMirrorSet in a shared workspace for bundle mirror substitution, and writes the serialized mirror set to the `env-files/IMAGE_CONTENT_SOURCES` file consumed by the provisioning task. Records the scorecard configuration images as a task result.

5. **Get Unreleased Bundle (`get-unreleased-bundle`)**
   - Retrieves the **unreleased bundle** from the FBC fragment.
   - Processes `.tekton/images-mirror-set.yaml` to resolve mirrored image references, if available.

6. **Pick Cluster Params (`pick-cluster-params`)**
   - Determines the **target OpenShift version** directly from the FBC fragment.
   - Identifies the **supported cluster architecture and instance type** (`amd64` / `m5.large`, or `arm64` / `m6g.large`).

7. **Provision Cluster (`provision-cluster`)**
   - Provisions an ephemeral **HyperShift cluster via OpenShift CI** using the
     `hypershift-hostedcluster-workflow`, the selected OpenShift version and compute node type,
     and the `IMAGE_CONTENT_SOURCES` supplied through the `env-files` workspace.

8. **Deploy Operator (`deploy-operator`)**
   - Consumes the **kubeconfig Secret** returned by the provisioning task for cluster access.
   - Installs the **operator** on the newly provisioned cluster.
   - Gathers **cluster artifacts** for analysis and validation.
   - Verifies the cluster artifacts directory is downloaded.
   - Pushes gathered artifacts to an **OCI artifact repository** (e.g. Quay).
   - Fails the pipeline if operator installation fails.

9. **Verify Image Sources (`verify-image-sources`)**
   - Validates that each pulled image comes from an approved registry:
      * `registry.redhat.io`
      * `registry.access.redhat.com`
   - Ensures images are referenced by digest.
   - Ignores images that are in an allow list.
   - Fails if any image does not meet the criteria.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|SNAPSHOT| Snapshot of the application|| true|
|PACKAGE_NAME| An OLM package name present in the fragment or leave it empty so the step will determine the default package. If there is only one 'olm.package', it's name is returned. If multiple 'olm.package' entries contain unreleased bundles, user input is required; the PACKAGE_NAME parameter must be set by the user| ""| false|
|CHANNEL_NAME| An OLM channel name or leave it empty so the step will determine the default channel name. The default channel name corresponds to the 'defaultChannel' entry of the selected package| ""| false|
|CREDENTIALS_SECRET_NAME| Name of the secret containing registry credentials in .dockerconfigjson format, used for pushing artifacts to an OCI registry. The key holding the credentials is configurable via CREDENTIALS_SECRET_KEY|| true|
|CREDENTIALS_SECRET_KEY| Key within the CREDENTIALS_SECRET_NAME secret's "data" field that holds the registry credentials in .dockerconfigjson format| "oci-storage-dockerconfigjson"| false|
|OCI_REF| Untagged Quay repository reference in the format "quay.io/org/repo"|| true|
|REPO_TOKEN| Name of the Kubernetes Secret that contains the access token for a private GitHub or GitLab repository| ""| false|
|REPO_KEY| Key within the Secret's "data" field that holds the GitHub/GitLab access token| ""| false|
|PATH_TO_MIRROR_SET| Path to where the image digest mirror set is saved in the repository| ".tekton/images-mirror-set.yaml"| false|
|CLUSTER_PROFILE| The OpenShift CI cluster profile that holds the cloud provider account used to provision the ephemeral cluster| "aws-konflux-prod"| false|
|SLACK_SECRET_NAME| Name of the secret containing the Slack webhook URL. Leave empty to disable Slack notifications| ""| false|
|SLACK_KEY_NAME| Key name within the secret that contains the Slack webhook URL| "webhook_url"| false|
|SLACK_MESSAGE| Custom message for Slack notifications. If empty, a default failure message will be used| ""| false|
|KONFLUX_UI_URL| Base URL of the Konflux UI for constructing log links| "https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"| false|

## Pipeline Usage Guide

### Create an IntegrationTestScenario

Create an `IntegrationTestScenario` YAML file for your FBC component using the following [template](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/tenants-config/cluster/stone-prd-rh01/tenants/konflux-samples-tenant/integration-test-scenarios.yaml?ref_type=heads#L24).

Open a merge request (MR) to your [tenants-config](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config/cluster?ref_type=heads) repository, and update the fields with the appropriate details for your Konflux tenant:

- `metadata.namespace`
- `spec.application`
- `spec.contexts[0].name` -> Use the `component_COMPONENT` syntax to run the integration test only for a specific component build. More information about when to run integration tests can be found [here](https://konflux.pages.redhat.com/docs/users/testing/integration/choosing-contexts.html).
- `spec.params[*].value` -> the pipeline parameters described above. Konflux supplies `SNAPSHOT`;
  all other parameters are optional except `CREDENTIALS_SECRET_NAME` and `OCI_REF`.

```yaml
apiVersion: appstudio.redhat.com/v1beta2
kind: IntegrationTestScenario
metadata:
  labels:
    test.appstudio.openshift.io/optional: "false"
  name: deploy-fbc-operator
  namespace: konflux-samples-tenant
spec:
  application: cnv-fbc-v4-17
  contexts:
    - description: Component testing for v417-cnv-fbc
      name: component_v417-cnv-fbc
  params:
    - name: PACKAGE_NAME
      value: "kubevirt-hyperconverged"
    - name: CHANNEL_NAME
      value: "candidate"
    - name: CREDENTIALS_SECRET_NAME
      value: "quay-dockerconfig"
    - name: OCI_REF
      value: "quay.io/org/repo"
    - name: REPO_TOKEN
      value: "git-auth"
    - name: REPO_KEY
      value: "git-auth-key"
    - name: PATH_TO_MIRROR_SET
      value: "config/imageDigestMirrorSet.yaml"
    - name: CLUSTER_PROFILE
      value: "aws-konflux-prod"
    - name: SLACK_SECRET_NAME
      value: "slack-webhook-secret"
    - name: SLACK_KEY_NAME
      value: "webhook_url"
    - name: SLACK_MESSAGE
      value: "Production deployment "
    - name: KONFLUX_UI_URL
      value: "https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"
  resolverRef:
    resourceKind: pipelinerun
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelineruns/deploy-fbc-operator/0.2/deploy-fbc-operator-run.yaml
    resolver: git
```

### Parameters Descriptions

#### PACKAGE_NAME (Optional)

An OLM package name present in the FBC fragment.

If omitted:

  - If there's only one `olm.package`, its name is used automatically.

  - If multiple `olm.package` entries exist, you *must* provide the `PACKAGE_NAME` parameter.

#### CHANNEL_NAME (Optional)

An OLM channel name. If omitted, the step will default to the package’s `defaultChannel`.

#### CREDENTIALS_SECRET_NAME

Name of the secret containing registry credentials (in `.dockerconfigjson` format). It is used to push cluster artifacts to an OCI registry. The key that holds the credentials within the secret's `data` field is configurable via `CREDENTIALS_SECRET_KEY` (default `oci-storage-dockerconfigjson`).

Example:

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

**IMPORTANT**: The secret must contain a key holding the `.dockerconfigjson` credentials, and the key name must match `CREDENTIALS_SECRET_KEY`. If they do not match, the push step will fail with the following error:
*failed to decode config file at /home/tool-box/.docker/config.json: invalid config format: read /home/tool-box/.docker/config.json: is a directory*

#### CREDENTIALS_SECRET_KEY (Optional)

Key within the `CREDENTIALS_SECRET_NAME` secret's `data` field that holds the registry credentials in `.dockerconfigjson` format. Defaults to `oci-storage-dockerconfigjson`. Override it when your secret stores the credentials under a different key (for example `.dockerconfigjson`).

#### OCI_REF

Untagged Quay repository reference in the format `quay.io/org/repo`. The pipeline appends a
generated tag containing the source revision and TaskRun UID.

#### REPO_TOKEN (Optional)

Name of the Kubernetes Secret that contains the access token for a private GitHub or GitLab repository.

#### REPO_KEY (Optional)

Key within the Secret's `data` field that holds the GitHub/GitLab access token.

Example:

```yaml
data:
  gitlab-auth-token: <BASE64_ENCODED_TOKEN>
```

In the example above, the `REPO_KEY` value should be `gitlab-auth-token`.

#### PATH_TO_MIRROR_SET (Optional)

Path to where the image digest mirror set is saved in the repository. The serialized mirror set is
supplied to the provisioning task as `IMAGE_CONTENT_SOURCES`, allowing the ephemeral cluster to pull
mirrored images.

#### CLUSTER_PROFILE (Optional)

The OpenShift CI cluster profile that holds the cloud provider account used to provision the
ephemeral cluster. Defaults to `aws-konflux-prod`. Using the shared cluster profile requires
access.

#### SLACK_SECRET_NAME (Optional)

Name of the secret containing the Slack webhook URL. Leave this parameter empty to disable Slack notifications.

When a Slack webhook secret is provided, the pipeline will send a notification to the configured Slack channel if the pipeline fails.

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: slack-webhook-secret
  namespace: sample-tenant
type: Opaque
data:
  webhook_url: <BASE64_ENCODED_WEBHOOK_URL>
```

#### SLACK_KEY_NAME (Optional)

Key name within the secret that contains the Slack webhook URL. Defaults to `webhook_url`.

This parameter specifies which key in the secret contains the actual Slack webhook URL. In the
example above, the `SLACK_KEY_NAME` value should be `webhook_url`.

#### SLACK_MESSAGE (Optional)

Custom message for Slack notifications. If empty, a default failure message will be used.

This parameter allows you to add a custom message prefix to the Slack notification. The message
will be displayed before the default "PipelineRun failed" text.

Example: If you set `SLACK_MESSAGE` to "Production deployment ", the notification will read:
```
❌ Production deployment PipelineRun <name> failed
```

#### KONFLUX_UI_URL (Optional)

Base URL of the Konflux UI for constructing log links. Defaults to `https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com`.

This parameter is used to construct a direct link to the pipeline run logs in the Konflux UI. The
notification includes a "View logs" link to the full pipeline run details.

If your Konflux instance is hosted at a different URL, update this parameter accordingly.

### What Happens Next

Once your FBC component is built, the `deploy-fbc-operator` pipeline will be triggered.

**NOTE**: To reduce resource consumption, this pipeline runs only for `push` events (i.e., when a PR is merged).

### Impact of Pipeline Failure

Currently, pipeline failures only block the auto-release of the Snapshot. They do *not* prevent users from manually releasing.

Until [KONFLUX-7345](https://issues.redhat.com/browse/KONFLUX-7345) is implemented, it is the product team’s responsibility to review test results and address any failures before release.

### Suitable for upstream communities
