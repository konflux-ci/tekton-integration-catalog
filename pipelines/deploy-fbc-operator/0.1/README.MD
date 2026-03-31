# "deploy-fbc-operator pipeline"
The deploy-fbc-operator pipeline automates the provisioning of a EaaS Hypershift cluster and the deployment of an operator from a given FBC (File-Based Catalog) fragment. It automates the process of fetching an image digest mirror set, retrieving an unreleased bundle from the FBC, selecting an appropriate OpenShift version and architecture for cluster provisioning, installing the operator, and gathering cluster artifacts.

## Pipeline Flow
The pipeline consists of the following tasks:

1. **Parse Metadata (`parse-metadata`)**  
   Extracts metadata from the provided *snapshot*, including:
     * FBC fragment container image
     * Source Git URL
     * Git revision

2. **Provision EAAS Space (`provision-eaas-space`)**  
   Allocates an **Environment-as-a-Service (EaaS) space** for cluster provisioning.

3. **Fetch Config Files (`fetch-config-files`)**
   - Retrieves the authorization token if the source Git repository is private.
   - Downloads `.tekton/images-mirror-set.yaml` and `bundle/tests/scorecard/config.yaml` from the source Git repository.
   - Stores the raw YAML and the serialized versions of the ImageDigestMirrorSet and scorecard config images as Tekton results for use by downstream tasks.

4. **Get Unreleased Bundle (`get-unreleased-bundle`)**
   - Retrieves the **unreleased bundle** from the FBC fragment.
   - Processes **.tekton/images-mirror-set.yaml** to resolve mirrored image references, if available.

5. **Pick Cluster Params (`pick-cluster-params`)**
   - Fetches a list of supported **OpenShift versions** for Hypershift.
      
      The version of Multi-Cluster Engine (MCE) that is deployed for Hypershift dictates what cluster versions can be provisioned. For example, MCE 2.7 supports provisioning OCP 4.14–4.17.

      Current MCE is defined [here](https://github.com/redhat-appstudio/infra-deployments/blob/main/components/cluster-as-a-service/base/multicluster-engine.yaml).

      A new MCE version is generally released shortly after the corresponding OCP GA release.
   - Selects the **target OpenShift version** for deployment.
   - Identifies the **supported cluster architecture** (`arm64`, `amd64`).

6. **Provision Cluster (`provision-cluster`)**
   - Retrieves the latest OpenShift **version tag**.
   - Provisions a **Hypershift AWS cluster** using the parameters selected above, along with the `imageContentSources` parameter, which contains the serialized image mirror set YAML used to apply IDMS to the running cluster.

7. **Deploy Operator (`deploy-operator`)**  
   - Retrieves **Kubeconfig credentials** for cluster access.
   - Installs the **operator** on the newly provisioned cluster.
   - Gathers **cluster artifacts** for analysis and validation.
   - Verifies the cluster artifacts directory is downloaded.
   - Pushes gathered artifacts to an **OCI artifact repository** (e.g. Quay).
   - Fails the pipeline if operator installation fails.

8. **Verify Image Sources (`verify-image-sources`)**  
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
|CREDENTIALS_SECRET_NAME| Name of the secret containing the oci-storage-dockerconfigjson key with registry credentials in .dockerconfigjson format, used for pushing artifacts to an OCI registry|| true|
|OCI_REF| Full OCI artifact reference in a format "quay.io/org/repo:tag"|| true|
|REPO_TOKEN| Name of the Kubernetes Secret that contains the access token for a private GitHub or GitLab repository| ""| false|
|REPO_KEY| Key within the Secret's "data" field that holds the GitHub/GitLab access token| ""| false|
|PATH_TO_MIRROR_SET| Path to where the image digest mirror set is saved in the repository| ".tekton/images-mirror-set.yaml"| false|
|SLACK_SECRET_NAME| Name of the secret containing the Slack webhook URL. Leave empty to disable Slack notifications| ""| false|
|SLACK_KEY_NAME| Key name within the secret that contains the Slack webhook URL| "webhook_url"| false|
|SLACK_MESSAGE| Custom message for Slack notifications. If empty, a default failure message will be used| ""| false|
|KONFLUX_UI_URL| Base URL of the Konflux UI for constructing log links| "https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"| false|

## Pipeline Usage Guide

### Create an IntegrationTestScenario

Create an `IntegrationTestScenario` YAML file for your FBC component using the following [template](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/tenants-config/cluster/stone-prd-rh01/tenants/konflux-samples-tenant/integration-test-scenarios.yaml?ref_type=heads#L24).

Open a merge request (MR) to your [tenants-config](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config/cluster?ref_type=heads) repository, and update the following fields with the appropriate details for your Konflux tenant:

- `metadata.namespace`
- `spec.application`
- `spec.contexts[0].name` -> Use the `component_COMPONENT` syntax to run the integration test only for a specific component build. More information about when to run integration tests can be found [here](https://konflux.pages.redhat.com/docs/users/testing/integration/choosing-contexts.html).
- `spec.params[0].value`  -> PACKAGE_NAME (Optional)
- `spec.params[1].value`  -> CHANNEL_NAME (Optional)
- `spec.params[2].value`  -> CREDENTIALS_SECRET_NAME
- `spec.params[3].value`  -> OCI_REF
- `spec.params[4].value`  -> REPO_TOKEN (Optional)
- `spec.params[5].value`  -> REPO_KEY (Optional)
- `spec.params[6].value`  -> PATH_TO_MIRROR_SET (Optional)
- `spec.params[7].value`  -> SLACK_SECRET_NAME (Optional)
- `spec.params[8].value`  -> SLACK_KEY_NAME (Optional)
- `spec.params[9].value`  -> SLACK_MESSAGE (Optional)
- `spec.params[10].value` -> KONFLUX_UI_URL (Optional)

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
      value: "quay.io/org/repo:tag"
    - name: REPO_TOKEN
      value: "git-auth"
    - name: REPO_KEY
      value: "git-auth-key"
    - name: PATH_TO_MIRROR_SET
      value: "config/imageDigestMirrorSet.yaml"
    - name: SLACK_SECRET_NAME
      value: "slack-webhook-secret"
    - name: SLACK_KEY_NAME
      value: "webhook_url"
    - name: SLACK_MESSAGE
      value: "Production deployment "
    - name: KONFLUX_UI_URL
      value: "https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com"
  resolverRef:
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelines/deploy-fbc-operator/0.1/deploy-fbc-operator.yaml
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

Name of the secret containing the `oci-storage-dockerconfigjson` key with registry credentials (in `.dockerconfigjson` format). It is used to push cluster artifacts to an OCI registry.

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

**IMPORTANT**: The secret must contain the key `oci-storage-dockerconfigjson`. If the key name is different, the step will fail with the following error:
*failed to decode config file at /home/tool-box/.docker/config.json: invalid config format: read /home/tool-box/.docker/config.json: is a directory*

#### OCI_REF

Full OCI artifact reference in the format: `quay.io/org/repo:tag`

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

Path to where the image digest mirror set is saved in the repository.

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

This parameter specifies which key in the secret contains the actual Slack webhook URL. In the example above, the `SLACK_KEY_NAME` value should be `webhook_url`.

#### SLACK_MESSAGE (Optional)

Custom message for Slack notifications. If empty, a default failure message will be used.

This parameter allows you to add a custom message prefix to the Slack notification. The message will be displayed before the default "PipelineRun failed" text.

Example: If you set `SLACK_MESSAGE` to "Production deployment ", the notification will read:
```
❌ Production deployment PipelineRun <name> failed
```

#### KONFLUX_UI_URL (Optional)

Base URL of the Konflux UI for constructing log links. Defaults to `https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com`.

This parameter is used to construct a direct link to the pipeline run logs in the Konflux UI. The notification will include a "View logs" link that directs users to the full pipeline run details.

If your Konflux instance is hosted at a different URL, update this parameter accordingly.

### What Happens Next

Once your FBC component is built, the `deploy-fbc-operator` pipeline will be triggered.

**NOTE**: To reduce resource consumption, this pipeline runs only for `push` events (i.e., when a PR is merged).

**NOTE**: Average pipeline runtime: 10–15 minutes.

### Impact of Pipeline Failure

Currently, pipeline failures only block the auto-release of the Snapshot. They do *not* prevent users from manually releasing.

Until [KONFLUX-7345](https://issues.redhat.com/browse/KONFLUX-7345) is implemented, it is the product team’s responsibility to review test results and address any failures before release.

### Suitable for upstream communities