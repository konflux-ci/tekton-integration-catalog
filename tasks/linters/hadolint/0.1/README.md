# Hadolint Task

## Description

The Hadolint task runs the Hadolint (Haskell Dockerfile Linter) Docker linting tool on Dockerfiles/Containerfiles contained in the repository.  For more information see https://github.com/hadolint/hadolint/

## Usage

To integrate the `hadolint` task into your Tekton pipeline, follow these steps:

1. **Define Parameters**: Specify the Git URL and revision (commit SHA) of the repository containing your Dockerfile.

2. **Task Integration**: Integrate the `hadolint` task into your Tekton pipeline definition.

3. **Execution**: During pipeline execution, the `hadolint` task will clone the specified Git repository and analyze the Dockerfile supplied in the `dockerfile-path` parameter using the `hadolint` tool

4. **Results**: Any issues detected during analysis will be reported as pipeline output, enabling you to identify and address potential problems in your Dockerfile.

## Parameters

| Name | Description                                                                                                  | Default Value           | Required |
|------|--------------------------------------------------------------------------------------------------------------|-------------------------|----------|
| `git-url` | The Git URL from which the test pipeline is originating. This can be from a fork or the original repository. | N/A                     | ✅ Yes |
| `git-revision` | The Git revision (commit SHA) from which the test pipeline is originating.                                   | N/A                     | ✅ Yes |
| `dockerfile-path` | Dockerfile path.                                                                                             | `./Dockerfile`          | ❌ No |
| `ignore-rules` | Hadolint rules which will be ignored during linting. Separated by commas.                                    | None                    | ❌ No |
| `failure-threshold` | Rule severity threshold for pipeline failure. One of (error, warning info style ignore).                     | `info`                  | ❌ No |
| `output-format` | The output format for the results (tty, json, checkstyle, codeclimate, gitlab_codeclimate, codacy).          | `tty`             | ❌ No |

## Example

Example usage of the `hadolint` task in a Tekton Pipeline:

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
    - name: hadolint
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
            value: tasks/linters/hadolint/0.1/hadolint.yaml
      params:
        - name: git-url
          value: "$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
        - name: dockerfile-path
          value: "./Dockerfile"
```

### Suitable for upstream communities
