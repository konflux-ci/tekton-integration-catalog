# Store Pipeline Status Task

**Version:** 0.1

The `store-pipeline-status` Task is responsible for gathering metadata about the current PipelineRun and storing it as a JSON artifact. It waits for all other TaskRuns in the PipelineRun to complete, excluding itself, and then collects information such as the PipelineRun name, duration, overall status, and details about each completed TaskRun (name, status, and duration). This information is then outputted as a JSON object and stored in OCI artifact.
It is meant to be used in the `finally` section of the PipelineRun.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|oci-ref|Full OCI artifact reference in the format `quay.io/org/repo:tag`. This parameter is used by the `secure-push-oci` step (imported Task) to specify where the pipeline status artifact should be pushed.||true|
|credentials-secret-name|Name of the secret containing registry credentials. The Secret should have a key named `oci-storage-dockerconfigjson` with the registry credentials in `.dockerconfigjson` format. This is used by the `secure-push-oci` StepAction for authenticating with the OCI registry.||true|
|pipeline-aggregate-status|The aggregate status of the pipeline. See the example in the **Usage** section||true|
|pipelinerun-name|The name of the PipelineRun this Task is currently running within. See the example in the **Usage** section||true|

## Usage

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: my-pipeline
spec:
  tasks:
    - name: testing-task1
      # ... (your testing Task) ...
    - name: testing-task2
      # ... (your testing Task) ...
  finally:
    - name: store-pipeline-status
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/store-pipeline-status/0.1/store-pipeline-status.yaml
      params:
        - name: oci-ref
          value: quay.io/org/repo:artifact-tag
        - name: credentials-secret-name
          value: secret-name
        - name: pipeline-aggregate-status
          value: $(tasks.status)
        - name: pipelinerun-name
          value: $(context.pipelineRun.name)
```

## Results

This task does not produce any output results.
