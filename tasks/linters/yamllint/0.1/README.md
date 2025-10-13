# YAML Linting Task

## Description

The YAML linting task is designed to help ensure consistent and error-free YAML formatting within your projects. It utilizes the `yamllint` tool to check YAML files for syntax errors, adherence to formatting standards, and potential pitfalls.

## Usage

To use the YAML linting task in your pipeline, follow these steps:

1. **Define Parameters**: Specify the Git URL and revision (commit SHA) of the repository you want to lint.

2. **Task Integration**: Integrate the `yaml-lint` task into your Tekton pipeline definition.

3. **Execution**: When the pipeline runs, the `yaml-lint` task will clone the specified Git repository and apply linting rules to YAML files found within it.

4. **Results**: Any issues discovered during linting will be reported as pipeline output, allowing you to identify and rectify potential problems in your YAML files.

## Task Configuration

The `yaml-lint` task employs a set of linting rules defined in the `linter-config.yaml` file. These rules include checks for proper indentation, consistent spacing, and other formatting conventions commonly associated with YAML files. You can customize these rules according to your project's specific requirements by modifying the `linter-config.yaml` file.

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
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
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
    - name: yaml-lint
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
            value: tasks/linters/yamllint/0.1/yaml-lint.yaml
      params:
        - name: git-url
          value: "$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
```

### Suitable for upstream communities