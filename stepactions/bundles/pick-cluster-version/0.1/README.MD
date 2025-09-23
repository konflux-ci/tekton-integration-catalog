# pick-cluster-version stepaction

This StepAction selects a cluster version for provisioning. It determines the target OCP version of an FBC fragment. 
The version is returned if it is included in the list of supported Hypershift cluster versions.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|fbcFragment|A FBC fragment image.||true|
|clusterVersions|List of supported minor versions from newest to oldest. E.g. ["4.15","4.14","4.13"]||true|

## Results
|name|description|
|---|---|
|ocpVersion|OCP version for cluster provisioning.|

## Example Usage

Here’s an example Tekton YAML configuration using this StepAction:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: pick-cluster-version-task
spec:
  steps:
    - name: get-supported-versions
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/build-definitions
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/eaas-get-supported-ephemeral-cluster-versions/0.1/eaas-get-supported-ephemeral-cluster-versions.yaml
      params:
        - name: eaasSpaceSecretRef
          value: $(params.eaasSpaceSecretRef)
    - name: pick-cluster-version
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/bundles/pick-cluster-version/0.1/pick-cluster-version.yaml
      params:
        - name: fbcFragment
          value: $(params.fbcFragment)
        - name: clusterVersions
          value: ["$(steps.get-supported-versions.results.versions[*])"]
```

### Suitable for upstream communities