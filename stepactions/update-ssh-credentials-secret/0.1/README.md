# update-ssh-credentials-secret stepaction

Patches an existing Kubernetes Secret with SSH credentials (`host`, `username`, `id_rsa`) read
from the cluster-info directory. Each file is base64-encoded before patching. Typically used after
`kind-aws-provisioner` to populate the secret pre-created by `create-ssh-credentials-secret`.

If `secret-name` is empty, the step exits immediately without making any changes.

The parent Task must declare the `emptyDir` volume referenced by `cluster-info-volume` and
share it with the provisioner step that writes the SSH credential files.

## Parameters

|name|description|default value|required|
|---|---|---|---|
|secret-name|The name of the Kubernetes Secret to update. If empty, the step is skipped.|""|false|
|namespace|The namespace of the Secret||true|
|cluster-info-volume|Name of the volume containing the SSH credentials files (`host`, `username`, `id_rsa`)||true|
|cluster-info-path|Mount path for the cluster-info volume|/opt/cluster-info|false|

## Example Usage

```yaml
steps:
  - name: update-ssh-credentials-secret
    onError: continue
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/update-ssh-credentials-secret/0.1/update-ssh-credentials-secret.yaml
    params:
      - name: secret-name
        value: $(params.ssh-credentials-secret-name)
      - name: namespace
        value: $(context.taskRun.namespace)
      - name: cluster-info-volume
        value: cluster-info
```

### Suitable for upstream communities
