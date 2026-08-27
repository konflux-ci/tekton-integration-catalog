# kind-aws-provisioner stepaction

Provisions a single-node Kind cluster on AWS using the [Mapt CLI](https://github.com/redhat-developer/mapt).
On success, connection details (`kubeconfig`, `host`, `username`, `id_rsa`) are written to the
directory mounted by `cluster-info-volume`.

If the `LOG_FILENAME` environment variable is set (e.g. injected via a Task `stepTemplate`),
command output is also tee'd to that file so it can be uploaded to OCI storage by a later step.

The parent Task must declare the following volumes:
- a Secret-backed volume for AWS credentials (referenced via `aws-credentials-volume`)
- an `emptyDir` volume for cluster connection details (referenced via `cluster-info-volume`)

## Parameters

|name|description|default value|required|
|---|---|---|---|
|aws-credentials-volume|Name of the volume that mounts the AWS credentials secret||true|
|cluster-info-volume|Name of the volume where mapt will write connection details||true|
|cluster-info-path|Mount path for the cluster-info volume|/opt/cluster-info|false|
|id|A unique identifier for this Kind environment||true|
|arch|Architecture of the instance (`x86_64` or `arm64`)|x86_64|false|
|cpus|Number of vCPUs to allocate|16|false|
|memory|Amount of memory in GiB to allocate|64|false|
|compute-sizes|Comma-separated list of compute sizes (takes precedence over `arch`, `cpus`, `memory`)|""|false|
|nested-virt|Enables nested virtualization|false|false|
|spot|Use spot instances|true|false|
|spot-increase-rate|Percentage added to the base spot price|20|false|
|spot-eviction-tolerance|Minimum eviction tolerance (`lowest`, `low`, `medium`, `high`, `highest`)|lowest|false|
|version|Kubernetes version for the Kind cluster|v1.32|false|
|tags|Additional AWS resource tags. `iac=mapt` and `k8s-type=kind` are added automatically|"''"|false|
|debug|Enables verbose logging. May expose credentials — use only in secure environments|false|false|
|timeout|Auto-destroy timeout (e.g. `2h`, `30m`)|"''"|false|
|extra-port-mappings|Additional port mappings as a JSON array of `{containerPort, hostPort, protocol}` objects|""|false|

## Example Usage

```yaml
volumes:
  - name: aws-credentials
    secret:
      secretName: $(params.secret-aws-credentials)
  - name: cluster-info
    emptyDir: {}

steps:
  - name: provisioner
    onError: continue
    ref:
      resolver: git
      params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: stepactions/kind-aws-provisioner/0.1/kind-aws-provisioner.yaml
    params:
      - name: aws-credentials-volume
        value: aws-credentials
      - name: cluster-info-volume
        value: cluster-info
      - name: id
        value: $(params.id)
```

### Suitable for upstream communities
