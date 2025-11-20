# coverport-collect stepaction

This StepAction collects raw coverage data from instrumented applications running in Kubernetes pods. It discovers pods by image list or label selector, collects binary coverage data via port-forward, and saves raw coverage files along with a metadata.json manifest. The manifest enables simplified batch processing by the coverport-upload StepAction.

More information: https://github.com/konflux-ci/coverport

## Parameters

|name|description|default value|required|
|---|---|---|---|
|images|Comma-separated list of instrumented container image references (test images built with coverage instrumentation, NOT production images)||true|
|label-selector|Label selector to filter pods (alternative to instrumented images)||false|
|namespace|Kubernetes namespace to search for pods. Leave empty to search all non-system namespaces||false|
|test-name|Name for this coverage collection run. If empty, auto-generated based on timestamp||false|
|coverage-port|Port where coverage server is listening in pods|9095|false|
|output-path|Output directory path for collected coverage data|/workspace/coverage|false|
|coverage-filters|Comma-separated list of file patterns to exclude from coverage reports|coverage_server.go|false|
|generate-reports|Generate text and filtered coverage reports during collection|true|false|
|remap-paths|Enable automatic path remapping for coverage reports|false|false|
|timeout|Timeout in seconds for coverage collection operations|120|false|
|verbose|Enable verbose logging|false|false|

## Results

|name|description|
|---|---|
|coverage-path|Path to the collected coverage data directory|
|components-collected|Number of components for which coverage was collected|
|test-name|The test name used for this collection run|

## Example Usage

```yaml
- name: collect-coverage
  ref:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog
      - name: revision
        value: main
      - name: pathInRepo
        value: stepactions/coverport-collect/0.1/coverport-collect.yaml
  params:
    - name: images
      value: "quay.io/org/app-instrumented@sha256:abc"
    - name: namespace
      value: "test-namespace"
    - name: output-path
      value: /workspace/coverage
```

### Suitable for upstream communities

