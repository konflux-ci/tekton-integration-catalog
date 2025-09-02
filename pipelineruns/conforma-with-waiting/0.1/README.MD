# conforma-with-waiting pipeline
The `conforma-with-waiting` pipeline is a custom version of the standard [Conforma](https://conforma.dev/docs/user-guide/index.html) (formerly known as enterprise-contract)
pipeline which first waits for all integration tests for the given Snapshot to finish before running the
Conforma verify task.

This allows users to either transfer build-time checks that are gated by conforma, or to add their own
custom checks which they can then reference in Conforma policies and gate on them.

## Pipeline Flow
The pipeline consists of the following tasks:

1. **Wait for integration tests (`wait-for-integration tests`)**  
   Waits for integration tests pipelineRuns for the given Snapshot to finish before proceeding with the pipeline.
   If the `SCENARIOS_TO_CHECK` parameter is set, the task waits only for the integration tests listed within it.
   The task waits until it timeouts. To control this, adjust the `timeout` field of the task spec according to your needs.

2. **Verify (`verify`)**  
   This task verifies a signature and attestation for an image and then runs 
   a policy against the image's attestation using the ec validate image command.

## Parameters
|name| description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | default value                          | required |
|---|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------|----------|
|SCENARIOS_TO_CHECK| A space-separated list of integrationTestScenarios that will be considered for the check, others will be ignored. If this parameter is not set, the task will wait for any of the integrationTestScenarios that haven't completed.                                                                                                                                                                                                                                                                     |                                    ""    | true     |
|SNAPSHOT| Snapshot of the application                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |                                        | true     |
|POLICY_CONFIGURATION| Name of the policy configuration (EnterpriseContractConfiguration object) to use. `namespace/name` or `name` syntax supported. If namespace is omitted the namespace where the task runs is used. bundles, user input is required; the PACKAGE_NAME parameter must be set by the user                                                                                                                                                                                                                  | "enterprise-contract-service/default"  | false    |
|SSL_CERT_DIR| Path to a directory containing SSL certs to be used when communicating with external services. This is useful when using the integrated registry and a local instance of Rekor on a development cluster which may use certificates issued by a not-commonly trusted root CA. In such cases, "/var/run/secrets/kubernetes.io/serviceaccount" is a good value. Multiple paths can be provided by using the ":" separator. channel name corresponds to the 'defaultChannel' entry of the selected package | ""                                     | false    |
|PUBLIC_KEY| Public key used to verify signatures. Must be a valid k8s cosign reference, e.g. k8s://my-space/my-secret where my-secret contains the expected cosign.pub attribute.                                                                                                                                                                                                                                                                                                                                  | "k8s://openshift-pipelines/public-key" | false    |
|TIMEOUT| Timeout setting for `ec validate`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | "5m0s"                                 | false    |
|WORKERS| Number of parallel workers to use for policy evaluation                                                                                                                                                                                                                                                                                                                                                                                                                                                | "1"                                    | false    |
|CA_TRUST_CONFIGMAP_NAME| The name of the ConfigMap to read CA bundle data from.                                                                                                                                                                                                                                                                                                                                                                                                                                                 | "trusted-ca"                           | false    |
|CA_TRUST_CONFIG_MAP_KEY| /home/kpavic/GolandProjects/integration-examples/pipelineruns/integration_enterprise_wait.yaml                                                                                                                                                                                                                                                                                                                                                                                                         | ".ca-bundle.crt"                       | false    |
|EXTRA_RULE_DATA| /home/kpavic/GolandProjects/integration-examples/pipelineruns/integration_enterprise_wait.yaml                                                                                                                                                                                                                                                                                                                                                                                                         | ""                                     | false    |
|SINGLE_COMPONENT| Reduce the Snapshot to only the component whose build caused the Snapshot to be created                                                                                                                                                                                                                                                                                                                                                                                                                | "false"                                | false    |
|SINGLE_COMPONENT_CUSTOM_RESOURCE| PipelineRun ID                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | "pr/$(context.pipelineRun.name)"       | false    |
|STRICT| A boolean flag that determines whether the result of the test will mark the TaskRun as passing or not. Swap to false to make the IntegrationTestScenario informative. Setting to false is useful on specific conditions but will always mark the integration test as successful and humans will tend to ignore the test results if they failed. Use with caution.                                                                                                                                      | "true"                                 | false    |

## Pipeline Usage Guide

### Create an IntegrationTestScenario

Create an `IntegrationTestScenario` YAML file for your application similar to the following [template](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/tenants-config/cluster/stone-prd-rh01/tenants/konflux-samples-tenant/integration-test-scenarios.yaml?ref_type=heads#L24).

Open a merge request (MR) to your [tenants-config](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config/cluster?ref_type=heads) repository, and update the following fields with the appropriate details for your Konflux tenant:

- `metadata.namespace`
- `spec.application`
- `spec.contexts[0].name` -> Change the context(s) for running this pipeline to your liking. More information about when to run integration tests can be found [here](https://konflux.pages.redhat.com/docs/users/testing/integration/choosing-contexts.html).

```yaml
apiVersion: appstudio.redhat.com/v1beta2
kind: IntegrationTestScenario
metadata:
  labels:
    test.appstudio.openshift.io/optional: "false"
  name: conforma-with-waiting
  namespace: konflux-samples-tenant
spec:
  application: your-application
  contexts:
    - description: Runs the test in in all cases. Change to your liking.
      name: application
  params:
    - name: SCENARIOS_TO_CHECK
      value: ""
  resolverRef:
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelineruns/conforma-with-waiting/0.1/conforma-with-waiting.yaml
    resolver: git
```