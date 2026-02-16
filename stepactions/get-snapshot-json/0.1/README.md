# get-snapshot-json stepaction

This StepAction takes the name of the Snapshot custom resource that's present in the namespace on the cluster that the pipeline is running in and stores its JSON representation in the workspace to be used by other steps in the task.

## Parameters

| name            | description                                                                              | default value | required |
|-----------------|------------------------------------------------------------------------------------------|---------------|----------|
| snapshot        | Name of the Snapshot custom resource that's present in the namespace of this pipelineRun |               | true     |
| output_filename | Output filename where the JSON representation of the Snapshot will be stored             | "workspace/snapshot.json"          | false    |

## Example usage

It can be used when the given Snapshot's size is too large to be passed as a Tekton parameter.
In that case, we need to utilize the `test.appstudio.openshift.io/snapshot-param-as-name` annotation as described in the user guide for [passing snapshot parameters by name](https://konflux-ci.dev/docs/testing/integration/creating/#passing-snapshot-parameters-by-name).

```yaml
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: test-snapshot
spec:
  params:
    - name: SNAPSHOT
      description: The JSON string of the Snapshot under test
  steps:
    # Fetch the Snapshot custom resource by name and store its .spec in a JSON file
    - name: get-snapshot-json
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/get-snapshot-json/0.1/get-snapshot-json.yaml
      params:
        - name: snapshot
          value: $(params.SNAPSHOT)
    # Get the stored Snapshot JSON and execute test on its contents (images, git sources etc.)
    - name: test-snapshot
      image: quay.io/konflux-ci/konflux-test:latest
      workingDir: /workspace
      env:
        - name: SNAPSHOT
          value: $(params.SNAPSHOT)
      script: |
        #!/bin/bash
        set -e

        # Display the stored Snapshot
        cat snapshot.json

        # Run custom tests on the snapshot in question
        # ...
```

### Suitable for upstream communities