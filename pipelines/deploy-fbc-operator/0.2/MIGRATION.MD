# Migration from 0.1 to 0.2
Workspaces were introduced to the `deploy-fbc-operator` pipeline.  
Keeping the old version (0.1) avoids breaking changes for existing users, but if you migrate to 0.2 you need to update your configuration.

## Action from users

In your `IntegrationTestScenario` yaml in your [tenants-config](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config?ref_type=heads):
1. Set `spec.resolverRef.resourceKind` to `pipelinerun` (lowercase `r`).  
2. Update the `pathInRepo` to point to the new pipeline run file:
    ```yaml
    - name: pathInRepo
      value: pipelineruns/deploy-fbc-operator/0.1/deploy-fbc-operator-run.yaml
    ```
A full example of an IntegrationTestScenario can be found [here](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/tenants-config/cluster/stone-prd-rh01/tenants/konflux-samples-tenant/integration-test-scenarios.yaml?ref_type=heads#L24).

Alternatively, in your Konflux tenant UI:
1. Navigate to the `Integration Tests` tab.
2. Click `Edit` for your integration test.
3. Under `Where do we look for your integration test configurations?`, select `Pipeline Run`.
4. Set `Path in the repository` to:
`pipelineruns/deploy-fbc-operator/0.1/deploy-fbc-operator-run.yaml`
