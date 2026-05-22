# Golangci-Lint Task

## Description

This Tekton task is designed to automate the setup and execution of GolangCI-Lint for Go code analysis in a specified directory. It streamlines the process of setting up a Go environment, installing a specific version of GolangCI-Lint, and running a linting process with custom arguments, ensuring that your code adheres to Go standards and best practices.

## Usage

To integrate the Golangci-Lint task into your Tekton pipeline, follow these steps:

1. **Define Parameters**: Specify the folder where your project is stored and the versions of Go and GolangCI-Lint to use.

2. **Task Integration**: Integrate the golangci-lint task into your Tekton pipeline definition.

3. **Execution**: During pipeline execution, the golangci-lint task downloads the specified versions of Go and GolangCI-Lint and performs the analysis with the arguments provided.

4. **Results**: Any issues detected during the analysis will be reported as pipeline output, allowing you to identify and address potential problems in your source code

## Task Configuration

The golangci-lint task utilizes the `GolangCI-Lint` tool, which can be configured using either argument parameters or a configuration file. If you choose to set it up via a configuration file, create a .golangci.yaml in the same directory where you run the `golangci-lint` task. If you prefer to use command-line arguments, simply pass the required parameters through the task's `args` parameter. Both the configuration file and command-line options should follow the specifications outlined here: https://golangci-lint.run/usage/configuration/

## Example

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: linter-pipeline-example
spec:
   - name: clone-repository
      params:
      - name: url
        value: $(params.git-url)
      - name: revision
        value: $(params.revision)
      taskRef:
        params:
        - name: name
          value: git-clone
        - name: bundle
          value: quay.io/konflux-ci/tekton-catalog/task-git-clone:0.1@sha256:92cf275b60f7bd23472acc4bc6e9a4bc9a9cbd78a680a23087fa4df668b85a34
        - name: kind
          value: task
        resolver: bundles
      workspaces:
      - name: output
        workspace: workspace
    - name: golangci-lint
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
            value: tasks/linters/golangci-lint/0.1/golangci-lint.yaml
      params:
        - name: context
          value: /workspace/source
        - name: args
          value: "-v ./pkg/..."
      workspaces:
      - name: source
        workspace: workspace
    workspaces:
    - name: workspace
  workspaces:
  - name: workspace
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```