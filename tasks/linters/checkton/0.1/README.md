# Checkton Task

## Description

The Checkton task runs Shellcheck on scripts embedded in YAML files.  For more information see https://github.com/chmeliik/checkton/

## Usage

To integration Checkton into your Tekton pipeline, follow these  steps:

1. **Define Parameters**: Specify the Git URL and revision (commit SHA) of the repository containing your shell scripts.

2. **Task Integration**: Integrate the `checkton` task into your Tekton pipeline definition.

3. **Execution**: During pipeline execution, the `checkton` task will clone the specified Git repository, search for yaml files in it, and analyze the shell scripts
found within those yaml files using it using ShellCheck.

4. **Results**: Any issues detected during analysis will be reported as pipeline output, enabling you to identify and address potential problems in your shell scripts.

## Example

Example usage of the `checkton` task in a Tekton Pipeline:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: linter-pipeline-example
spec:
    - name: test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/test-metadata/0.1/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: $(params.SNAPSHOT)
        - name: oras-container
          value: $(params.oras-container)
        - name: test-name
          value: $(context.pipelineRun.name)
    - name: checkton
      runAfter:
        - test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/linters/checkton/0.1/checkton.yaml
      params:
        - name: git-url
          value: "$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
```
