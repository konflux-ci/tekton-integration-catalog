# pick-cluster-arch stepaction

This StepAction retrieves the supported architectures for a bundle by checking the
`operatorframework.io/arch` labels on the bundle CSV. It returns the selected architecture
and AWS instance type as separate results. If arm64 is supported, it returns `arm64` and
`m6g.large`; otherwise, it returns `amd64` and `m5.large`. If architecture labels are not
defined in the bundle CSV, it defaults to `amd64` and `m5.large`.

## Parameters

| name | description | default value | required |
|---|---|---|---|
| bundleImage | A bundle image. | | true |

## Results

| name | description |
|---|---|
| arch | A bundle-supported architecture, `arm64` or `amd64`. |
| awsInstanceType | The AWS instance type corresponding to the selected architecture. |

## Example Usage

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
            value: stepactions/bundles/pick-cluster-arch/0.2/pick-cluster-arch.yaml
      params:
        - name: bundleImage
          value: $(params.bundleImage)
```
