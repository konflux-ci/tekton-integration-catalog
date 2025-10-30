# Fetch data to trusted artifact

Version: 0.1

The `fetch-data-to-trusted-artifact` task is designed to fetch file by running the specified script in a specific image and build the fetched file as oci trusted artifact.

## Parameters

The task accepts the following parameters:
|name|description|default value|required|
|---|---|---|---|
|SOURCE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the application source code.||true|
|ociStorage|The OCI repository where the Trusted Artifacts are stored.||true|
|ociArtifactExpiresAfter|Expiration date for the trusted artifacts created in the OCI repository. An empty string means the artifacts do not expire.|""|false|
|runtimeImage|The image the script will be run to fetch data in||true|
|executionScript|The script to run to fetch db on runtimeImage parameter||true|

## ### Example of calling it
The task helps in fetching db file and build the fetched as oci trusted artifact so the clair-in-ci-db build pipelinerun can be run hermetically.
```
- name: fetch-data-to-trusted-artifact
params:
- name: SOURCE_ARTIFACT
  value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
- name: ociStorage
  value: $(params.output-image).prefetch
- name: ociArtifactExpiresAfter
  value: $(params.image-expires-after)
- name: runtimeImage
  value: "quay.io/projectquay/clair-action:v0.0.11"
- name: executionScript
  value: |
    #!/usr/bin/env bash
    set -o errexit
    set -o nounset
    set -o pipefail
    set -x

    DB_PATH=/var/workdir/source/matcher.db /bin/clair-action --level info update
runAfter:
- clone-repository
taskRef:
  params:
  - name: url
    value: https://github.com/konflux-ci/tekton-integration-catalog.git
  - name: revision
    value: main
  - name: pathInRepo
    value: tasks/fetch-data-to-trusted-artifact/0.1/fetch-data-to-trusted-artifact.yaml
  resolver: git
- name: prefetch-dependencies
params:
- name: input
  value: $(params.prefetch-input)
- name: SOURCE_ARTIFACT
  value: $(tasks.fetch-data-to-trusted-artifact.results.SOURCE_ARTIFACT)
- name: ociStorage
  value: $(params.output-image).prefetch
- name: ociArtifactExpiresAfter
  value: $(params.image-expires-after)
- name: dev-package-managers
  value: "true"
runAfter:
- fetch-data-to-trusted-artifact
taskRef:
  params:
  - name: name
    value: prefetch-dependencies-oci-ta
  - name: bundle
    value: quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.2@sha256:098322d6b789824f716f2d9caca1862d4afdc083ebaaee61aadd22a8c179480a
  - name: kind
    value: task
  resolver: bundles
workspaces:
- name: git-basic-auth
  workspace: git-auth
- name: netrc
  workspace: netrc
```

## Results

| Name | Description |
|------|-------------|
| `SOURCE_ARTIFACT` | A string representing the ORAS container used to store all artifacts. A new container will be generated with the fetched data from this task. |
