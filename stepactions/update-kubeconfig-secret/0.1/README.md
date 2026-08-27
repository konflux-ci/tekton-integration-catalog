# update-kubeconfig-secret stepaction

Patches an existing Kubernetes Secret with the `kubeconfig` file found in the cluster-info
directory. The file is base64-encoded before patching. Typically used after `kind-aws-provisioner`
to populate the secret that was pre-created by `create-kubeconfig-secret`.

The parent Task must declare the `emptyDir` volume referenced by `cluster-info-volume` and
share it with the provisioner step that writes the kubeconfig.

## Parameters

|name|description|default value|required|
|---|---|---|---|
|secret-name|The name of the Kubernetes Secret to update||true|
|namespace|The namespace of the Secret||true|
|cluster-info-volume|Name of the volume containing the kubeconfig file||true|
|cluster-info-path|Mount path for the cluster-info volume|/opt/cluster-info|false|

## Example Usage

```yaml
steps:
  - name: update-kubeconfig-secret
    onError: continue
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/update-kubeconfig-secret/0.1/update-kubeconfig-secret.yaml
    params:
      - name: secret-name
        value: $(params.cluster-access-secret-name)
      - name: namespace
        value: $(context.taskRun.namespace)
      - name: cluster-info-volume
        value: cluster-info
```

### Suitable for upstream communities
