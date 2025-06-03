# secure-push-oci stepaction

This StepAction scans specified directory (workingDir) using [leaktk-scanner CLI](https://github.com/leaktk/scanner)
and deletes files containing sensitive information (credentials, certificates) that shouldn't be exposed to public.
Then it pushes the working directory contents to a specified OCI artifact repository tag.
If the tag exists, it will update the existing content with the content of the working directory.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|workdir-path|Path to the workdir that is about to be uploaded to OCI artifact||true|
|credentials-volume-name|Name of the volume that mounts the secret with "oci-storage-dockerconfigjson" key containing registry credentials in .dockerconfigjson format, i.e. the secret should contain `data.oci-storage-dockerconfigjson: <dockerconfigjson-content>`||true|
|oci-ref|Full OCI artifact reference in a format "quay.io/org/repo:tag"||true|
|oci-tag-expiration|OCI artifact tag expiration|1y|false|
|always-pass|Even if execution of the stepaction's script fails, do not fail the step|"true"|false|
