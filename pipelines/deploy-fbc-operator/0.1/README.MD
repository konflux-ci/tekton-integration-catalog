# "deploy-fbc-operator pipeline"
The deploy-fbc-operator pipeline automates the provisioning of a EaaS Hypershift cluster and the deployment of an operator from a given FBC (File-Based Catalog) fragment. It automates the process of retrieving an unreleased bundle from the FBC, selecting an appropriate OpenShift version and architecture for cluster provisioning, installing the operator, and gathering cluster artifacts.

## Pipeline Flow
The pipeline consists of the following tasks:

1. **Parse Metadata (`parse-metadata`)**  
   Extracts metadata from the provided *snapshot*, including:
     * FBC fragment container image
     * Source Git URL
     * Git revision

2. **Provision EAAS Space (`provision-eaas-space`)**  
   Allocates an **Environment-as-a-Service (EaaS) space** for cluster provisioning.

3. **Get Unreleased Bundle (`get-unreleased-bundle`)**
   - Retrieves the **unreleased bundle** from the FBC fragment.
   - Processes **.tekton/images-mirror-set.yaml** to resolve mirrored image references, if available.

4. **Provision Cluster (`provision-cluster`)**  
   - Fetches a list of supported **OpenShift versions** for Hypershift.
      
      The version of Multi-Cluster Engine (MCE) that is deployed for Hypershift dictates what cluster versions can be provisioned. For example, MCE 2.7 supports provisioning OCP 4.14–4.17.

      Current MCE is defined [here](https://github.com/redhat-appstudio/infra-deployments/blob/main/components/cluster-as-a-service/base/multicluster-engine.yaml).

      A new MCE version is generally released shortly after the corresponding OCP GA release.
   - Selects the **target OpenShift version** for deployment.
   - Identifies the **supported cluster architecture** (`arm64`, `amd64`).
   - Retrieves the latest OpenShift **version tag**.
   - Provisions a **Hypershift AWS cluster** using the selected parameters.

5. **Deploy Operator (`deploy-operator`)**  
   - Retrieves **Kubeconfig credentials** for cluster access.
   - Installs the **operator** on the newly provisioned cluster.
   - Gathers **cluster artifacts** for analysis and validation.
   - Verifies the cluster artifacts directory is downloaded.
   - Pushes gathered artifacts to an **OCI artifact repository** (e.g. Quay).
   - Fails the pipeline if operator installation fails.


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

### What Happens Next

Once your FBC component is built, the `deploy-fbc-operator` pipeline will be triggered.

**NOTE**: To reduce resource consumption, this pipeline runs only for `push` events (i.e., when a PR is merged).

**NOTE**: Average pipeline runtime: 10–15 minutes.

### Impact of Pipeline Failure

Currently, pipeline failures only block the auto-release of the Snapshot. They do *not* prevent users from manually releasing.

Until [KONFLUX-7345](https://issues.redhat.com/browse/KONFLUX-7345) is implemented, it is the product team’s responsibility to review test results and address any failures before release.