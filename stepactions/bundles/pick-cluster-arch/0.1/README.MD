# pick-cluster-arch stepaction

This StepAction retrieves the supported architectures for a bundle by checking the "operatorframework.io/arch" labels on the bundle CSV.
If arm64 is supported, the StepAction returns "m6g.large" instance type; otherwise, it returns "m5.large" (amd64).
If the architecture labels are not defined in the bundle CSV, the function defaults to returning "m5.large" (amd64).

## Parameters
|name|description|default value|required|
|---|---|---|---|
|bundleImage|A bundle image.||true|

## Results
|name|description|
|---|---|
|bundleArch|A bundle-supported architecture, m6g.large (arm64) or m5.large (amd64).|

## Example Usage

Here’s an example Tekton YAML configuration using this StepAction:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: pick-cluster-arch-task
spec:
  steps:
    - name: pick-cluster-arch
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/bundles/pick-cluster-arch/0.1/pick-cluster-arch.yaml
      params:
        - name: bundleImage
          value: $(params.bundleImage)
```