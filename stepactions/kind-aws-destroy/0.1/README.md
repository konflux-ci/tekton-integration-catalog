# kind-aws-destroy stepaction

Destroys a Kind cluster previously provisioned on AWS using the [Mapt CLI](https://github.com/redhat-developer/mapt).
The `id` must match the one used during provisioning so the operation is scoped to the correct environment.

The parent Task must declare a Secret-backed volume for AWS credentials (referenced via `aws-credentials-volume`).

## Parameters

|name|description|default value|required|
|---|---|---|---|
|aws-credentials-volume|Name of the volume that mounts the AWS credentials secret||true|
|id|The unique identifier of the Kind environment to destroy. Must match the ID used during provisioning||true|
|debug|Enables verbose logging. May expose credentials — use only in secure environments|false|false|
|force-destroy|Destroy even if there is a provisioning lock on the stack|true|false|

## Example Usage

```yaml
volumes:
  - name: aws-credentials
    secret:
      secretName: $(params.secret-aws-credentials)

steps:
  - name: destroy
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/kind-aws-destroy/0.1/kind-aws-destroy.yaml
    params:
      - name: aws-credentials-volume
        value: aws-credentials
      - name: id
        value: $(params.id)
      - name: force-destroy
        value: $(params.force-destroy)
```

### Suitable for upstream communities
