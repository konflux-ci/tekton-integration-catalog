# secure-push-oci stepaction

This StepAction scans specified directory (workingDir) using [leaktk-scanner CLI](https://github.com/leaktk/scanner)
and deletes files containing sensitive information (credentials, certificates) that shouldn't be exposed to public.
Then it pushes the working directory contents to a specified OCI artifact repository tag.
If the tag exists, it will update the existing content with the content of the working directory.

## Changes from 0.1

The secret key used for registry credentials is now configurable via `credentials-volume-key` (default: `.dockerconfigjson`).
This allows standard Kubernetes image pull secrets to be used directly without requiring a custom key name.

## Parameters

|name|description|default value|required|
|---|---|---|---|
|workdir-path|Path to the workdir that is about to be uploaded to OCI artifact||true|
|credentials-volume-name|Name of the volume that mounts the Kubernetes secret containing registry credentials||true|
|credentials-volume-key|Key within the secret that holds the registry credentials in .dockerconfigjson format|`oci-storage-dockerconfigjson`|false|
|oci-ref|Full OCI artifact reference in a format "quay.io/org/repo:tag"||true|
|oci-tag-expiration|OCI artifact tag expiration|1y|false|
|always-pass|Even if execution of the stepaction's script fails, do not fail the step|"true"|false|

### Suitable for upstream communities
