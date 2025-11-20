# coverport-upload stepaction

This StepAction processes collected coverage data and uploads to coverage services (Codecov, SonarQube). It reads the metadata.json manifest created by coverport-collect, automatically processes all collected components in batch mode, extracts git metadata (including PR number), clones repositories, processes coverage, and uploads to Codecov.

This should run after coverport-collect and secure-push-oci steps.

More information: https://github.com/konflux-ci/coverport

## Parameters

|name|description|default value|required|
|---|---|---|---|
|coverage-path|Path to directory containing collected coverage data and metadata.json manifest|/workspace/coverage|false|
|coverage-format|Coverage format: go, python, nyc, or auto (auto-detect). Currently only 'go' is fully implemented|auto|false|
|coverage-filters|Comma-separated list of file patterns to exclude from coverage|coverage_server.go,*_test.go|false|
|generate-html|Generate HTML coverage reports (requires source code)|false|false|
|upload-codecov|Upload coverage to Codecov|true|false|
|codecov-flags|Comma-separated list of Codecov flags|e2e-tests|false|
|codecov-name|Name for Codecov upload (optional)||false|
|clone-depth|Git clone depth for shallow cloning. Set to 0 for full clone|1|false|
|skip-clone|Skip cloning repositories (for testing or if repos already cloned)|false|false|
|workspace-path|Working directory for coverage processing|/workspace/coverport-process|false|
|keep-workspace|Keep workspace directory after processing (for debugging)|false|false|
|verbose|Enable verbose logging|false|false|

## Results

|name|description|
|---|---|
|components-processed|Number of components successfully processed and uploaded|
|total-coverage|Total coverage percentage (if calculable)|
|codecov-urls|Newline-separated list of Codecov URLs for uploaded coverage|

## Environment Variables

Requires `CODECOV_TOKEN` to be set via a secret:

```yaml
env:
  - name: CODECOV_TOKEN
    valueFrom:
      secretKeyRef:
        name: coverport-secrets
        key: codecov-token
```

## Example Usage

```yaml
- name: upload-coverage
  ref:
    resolver: git
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog
      - name: revision
        value: main
      - name: pathInRepo
        value: stepactions/coverport-upload/0.1/coverport-upload.yaml
  params:
    - name: coverage-path
      value: $(steps.collect-coverage.results.coverage-path)
    - name: upload-codecov
      value: "true"
    - name: codecov-flags
      value: "e2e-tests,integration"
```

### Suitable for upstream communities

