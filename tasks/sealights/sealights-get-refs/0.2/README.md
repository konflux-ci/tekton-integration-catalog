# Sealights Get Refs Tekton Task

## Overview

The `sealights-get-refs` Tekton Task (**v0.2**) is designed to retrieve the Sealights-instrumented container image references from a CI pipeline. This Task iterates through **all component images** defined in the provided Konflux `Snapshot` and extracts the relevant instrumented image reference by analyzing the build's attestation data. It is intended for use in Konflux CI integration tests, particularly when dealing with **multi-component applications**.

***

## Task Description

The Task performs the following steps:

1.  Retrieves all component container image references from the provided `SNAPSHOT` JSON string (from `.components[*].containerImage`).
2.  **Loops** through each component image.
3.  For each component image, downloads the associated **attestation metadata** using `cosign`.
4.  Parses the attestation metadata, specifically looking for the `IMAGE_REF` result from tasks matching the pattern **`buildah(-remote)?-oci-ta$`** (the tasks that build the instrumented image).
5.  Consolidates all found instrumented image references into a single **JSON array**.
6.  Writes the array to the **`sealights-instrumented-images`** Tekton Task result.

***

## Parameters

| Name | Type | Description |
| :--- | :--- | :--- |
| `SNAPSHOT` | string | The **JSON string** representing the Konflux Snapshot under test, which may contain multiple components. |

***

## Results

| Name | Description |
| :--- | :--- |
| `sealights-instrumented-images` | A **JSON array** of all Sealights-instrumented container image references found across all components in the snapshot. |

***

## Usage Example

Here's an example of how to use the `sealights-get-images` Task in a Tekton Pipeline and how to access its array result:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: example-sealights-multi-component-pipeline
spec:
  params:
    - name: snapshot
      description: "The Snapshot JSON string"
  tasks:
    - name: get-instrumented-images
      taskRef:
        name: sealights-get-refs # Task name updated for v0.2
      params:
        - name: SNAPSHOT
          value: "$(params.snapshot)"
    
    # Example of a subsequent task consuming the array result
    - name: run-tests-on-images
      runAfter:
        - get-instrumented-images
      taskRef:
        name: your-test-runner-task
      params:
        - name: IMAGES_ARRAY # Pass the array as a parameter
          value: "$(tasks.get-instrumented-images.results.sealights-instrumented-images)"
```

## Dependencies

To fully integrate instrumentation in your Konflux-CI build pipelines, you'll need to update the build YAML files located in the `.tekton` folder. This involves adding instrumentation tasks for specific languages and, for Go projects, triggering a second build to generate trusted artifacts a second container.

## Adding Instrumentation Task

### General Template for Instrumentation

Insert the following snippet **after** the `clone-repository` task to add the instrumentation step:

```yaml
# This example is for a push event
- name: sealights-instrumentation
  runAfter:
    - clone-repository
  taskRef:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: tasks/sealights/sealights-go-instrumentation/0.1/sealights-go-instrumentation.yaml
  params:
    - name: source-artifact
      value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
    - name: go-version
      value: "1.22"
    - name: sealights-secret
      value: "sealights-credentials"
    - name: component
      value: '{{ repo_name }}'
    - name: branch
      value: '{{ source_branch }}'
    - name: revision
      value: '{{ revision }}'
    - name: oci-storage
      value: $(params.output-image).sealights.git
```

## Adding a Second Build Task for Go Projects

For Go projects, you need a second build task after the `prefetch-dependencies` task to generate a trusted artifact containing the instrumented code.

### Example: Second Build for Go (not applied to NodeJs or Python)

Add the following snippet after `prefetch-dependencies`:

```yaml
- name: build-sealights-container
  params:
    - name: IMAGE
      value: $(params.output-image).sealights
    - name: DOCKERFILE
      value: $(params.dockerfile)
    - name: CONTEXT
      value: $(params.path-context)
    - name: HERMETIC
      value: $(params.hermetic)
    - name: PREFETCH_INPUT
      value: $(params.prefetch-input)
    - name: IMAGE_EXPIRES_AFTER
      value: $(params.image-expires-after)
    - name: COMMIT_SHA
      value: $(tasks.clone-repository.results.commit)
    - name: BUILD_ARGS
      value:
        - $(params.build-args[*])
    - name: BUILD_ARGS_FILE
      value: $(params.build-args-file)
    - name: SOURCE_ARTIFACT
      value: $(tasks.sealights-instrumentation.results.source-artifact) <---- This is super important to update
    - name: CACHI2_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
  runAfter:
    - prefetch-dependencies
  taskRef:
    params:
      - name: name
        value: buildah-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-buildah-oci-ta:0.2@sha256:937f465189482f3279b9491161fff7720d4c443f27e6d9febbf2344268383011
      - name: kind
        value: task
    resolver: bundles
  when:
    - input: $(tasks.init.results.build)
      operator: in
      values:
        - "true"
```
