# create-ssh-credentials-secret stepaction

Creates an empty Kubernetes Secret with an owner reference, intended to store SSH credentials
(`host`, `username`, `id_rsa`) for a provisioned VM. The data fields will be populated by a
subsequent step (e.g. `update-ssh-credentials-secret`). If `secret-name` is empty, the step
is skipped and the result is set to an empty string.

## Parameters

|name|description|default value|required|
|---|---|---|---|
|secret-name|The name to assign to the Kubernetes Secret. If empty, the step is skipped.|""|false|
|namespace|The namespace where the Secret will be created||true|
|ownerKind|The Tekton resource type owning this Secret (`PipelineRun` or `TaskRun`)|PipelineRun|false|
|ownerName|The name of the owning PipelineRun or TaskRun||true|
|ownerUid|The UID of the owning PipelineRun or TaskRun||true|

## Results

|name|description|
|---|---|
|secret-name|The name of the created SSH credentials Secret, or empty if the step was skipped|

## Example Usage

```yaml
steps:
  - name: create-ssh-credentials-secret
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/create-ssh-credentials-secret/0.1/create-ssh-credentials-secret.yaml
    params:
      - name: secret-name
        value: $(params.ssh-credentials-secret-name)
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
