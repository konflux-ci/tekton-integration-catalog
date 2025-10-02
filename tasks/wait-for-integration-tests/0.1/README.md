# Wait for integration tests Task

**Version:** 0.1

The `wait-for-integration-tests` Task waits for all integration test pipelineRuns related to the given Snapshot to complete
before finishing and allowing the tasks that depend on it to proceed. The Snapshot name is obtained from the
`appstudio.openshift.io/snapshot` label associated with the pipelineRun that's executing the current task.
The space-separated list of integration test scenarios that it takes into account can be set via the `scenarios-to-check` parameter,
otherwise it waits for all integration test pipelineRuns to complete.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|scenarios_to_check|A space-separated list of integrationTestScenarios that will be considered for the check, others will be ignored.If this parameter is not set, the task will wait for any of the integrationTestScenarios that haven't completed.||true|

## Usage

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: my-pipeline
spec:
  tasks:
    - name: wait-for-integration-tests
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/wait-for-integration-tests/0.1/wait-for-integration-tests.yaml
      params:
        - name: scenarios-to-check
          value: "my-other-test my-other-test-2"
    - name: testing-task1
      # ... (your testing Task) ...
    - name: testing-task2
      # ... (your testing Task) ...
```

## Results

This task does not produce any output results.
