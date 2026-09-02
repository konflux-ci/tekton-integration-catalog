# create-kubeconfig-secret stepaction

Creates an empty Kubernetes Secret with an owner reference to a PipelineRun or TaskRun.
The secret is intended to store a kubeconfig that will be populated by a subsequent step
(e.g. `update-kubeconfig-secret`). Deleting the owning resource automatically garbage-collects the secret.

## Parameters

|name|description|default value|required|
|---|---|---|---|
|secret-name|The name to assign to the Kubernetes Secret||true|
|namespace|The namespace where the Secret will be created||true|
|ownerKind|The Tekton resource type owning this Secret (`PipelineRun` or `TaskRun`)|PipelineRun|false|
|ownerName|The name of the owning PipelineRun or TaskRun||true|
|ownerUid|The UID of the owning PipelineRun or TaskRun||true|

## Results

|name|description|
|---|---|
|secret-name|The name of the created kubeconfig Secret (echoed back from the input param)|

## Example Usage

```yaml
steps:
  - name: create-kubeconfig-secret
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/create-kubeconfig-secret/0.1/create-kubeconfig-secret.yaml
    params:
      - name: secret-name
        value: $(params.cluster-access-secret-name)
      - name: namespace
        value: $(context.taskRun.namespace)
      - name: ownerKind
        value: $(params.ownerKind)
      - name: ownerName
        value: $(params.ownerName)
      - name: ownerUid
        value: $(params.ownerUid)
```

### Suitable for upstream communities
