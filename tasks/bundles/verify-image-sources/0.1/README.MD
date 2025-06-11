# verify-image-sources Task

This task verifies that all images pulled during operator deployment testing originate from Red Hat–approved registries — specifically, `registry.redhat.io` and `registry.access.redhat.com`.
It ensures that each image is pinned by digest, comes from an approved source, and is not referenced by tag.

## What it does

- Validates that each pulled image comes from an approved registry:
  * `registry.redhat.io`
  * `registry.access.redhat.com`
- Ensures images are referenced by digest.
- Ignores images that are in an allow list.
- Fails if any image does not meet the criteria.


## Parameters

| name                             | description                                                                                              | default value | required |
|----------------------------------|----------------------------------------------------------------------------------------------------------|----------------|----------|
| imagesPulledAfterDeploymentStart | A newline-separated list of images pulled after the operator was installed.                              |                | true     |
| bundleImage                      | The operator bundle image under test.                                                                    |                | true     |
| scorecardConfigImages            | Additional images used in custom scorecard configurations (newline-separated).                           |            []            | false    |


## Example Usage

Here’s an example Tekton YAML configuration using this Task:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: verify-image-sources-task
spec:
  steps:
    - name: verify-image-sources
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/security/verify-image-sources/0.1/verify-image-sources.yaml
      params:
        - name: imagesPulledAfterDeploymentStart
          value: $(params.imagesPulledAfterDeploymentStart)
        - name: bundleImage
          value: $(params.bundleImage)
        - name: scorecardConfigImages
          value: $(params.scorecardConfigImages)
