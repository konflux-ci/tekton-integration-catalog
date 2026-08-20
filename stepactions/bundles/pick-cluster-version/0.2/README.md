# pick-cluster-version stepaction

This StepAction determines the target OCP version of an FBC fragment and returns it for cluster
provisioning.

## 🚀 New in Version 0.2

Version `0.2` drops the `clusterVersions` parameter and the associated supported-versions
validation that `0.1` required. It reports the OCP version encoded in the FBC fragment directly.
The OpenShift CI ephemeral cluster workflow does not use the Environment-as-a-Service (EaaS)
supported-versions list.

Version `0.1` remains available for consumers that still need to validate the fragment version
against an explicit list of supported versions.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|fbcFragment|A FBC fragment image.||true|

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
    - name: pick-cluster-version
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/bundles/pick-cluster-version/0.2/pick-cluster-version.yaml
      params:
        - name: fbcFragment
          value: $(params.fbcFragment)
```

### Suitable for upstream communities
