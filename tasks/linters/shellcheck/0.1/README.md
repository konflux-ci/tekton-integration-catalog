# ShellCheck Task

## Description

The ShellCheck task is designed to analyze shell scripts within your projects for potential issues and errors. It utilizes the `ShellCheck` tool to identify common pitfalls, syntax errors, and opportunities for improvement in your shell scripts.

## Usage

To integrate the ShellCheck task into your Tekton pipeline, follow these steps:

1. **Define Parameters**: Specify the Git URL and revision (commit SHA) of the repository containing your shell scripts.

2. **Task Integration**: Integrate the `shellcheck` task into your Tekton pipeline definition.

3. **Execution**: During pipeline execution, the `shellcheck` task will clone the specified Git repository and analyze the shell scripts found within it using ShellCheck.

4. **Results**: Any issues detected during analysis will be reported as pipeline output, enabling you to identify and address potential problems in your shell scripts.

## Task Configuration

The `shellcheck` task utilizes the ShellCheck tool to analyze shell scripts according to best practices and common conventions. You can customize the task further by adjusting parameters or providing additional configuration as needed.

## Example

Example usage of the `yaml-lint` task in a Tekton Pipeline:

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
    - name: shellcheck
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
            value: tasks/linters/shellcheck/0.1/shellcheck.yaml
      params:
        - name: git-url
          value: "$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
```

### Suitable for upstream communities