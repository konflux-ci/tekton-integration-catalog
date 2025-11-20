# Coverport Coverage Task

**Version:** 0.1

The `coverport-coverage` task collects coverage from Konflux Integration tests and uploads to coverage services. It orchestrates a three-step workflow: collecting coverage from test pods, pushing raw coverage artifacts to an OCI registry, and batch processing all components for upload to Codecov.

This task is designed to integrate with Konflux Integration pipelines and uses `onError: continue` to ensure the pipeline doesn't fail on coverage issues.

## Parameters

| Name | Description | Default | Required |
|------|------------|---------|----------|
| instrumented-images | Comma-separated list of instrumented container image references (test images built with coverage instrumentation, NOT production images from SNAPSHOT). | quay.io/redhat-user-workloads-stage/psturc-tenant/go-coverage-http:ee282f9ede36db993d3b3d1e3da4bbd090f5f915 | ✅ |
| cluster-access-secret-name | Secret containing kubeconfig to access the testing cluster. Leave empty to use in-cluster config. | | ❌ |
| test-namespace | Kubernetes namespace where test pods are running. Leave empty to search all non-system namespaces. | "" | ❌ |
| test-name | Name for this test run (used in artifact naming). If empty, auto-generated based on timestamp. | e2e-tests | ❌ |
| oci-container | OCI container reference where artifacts will be stored. | | ✅ |
| upload-target | Coverage upload target: "codecov", "sonarcloud" (future). | codecov | ❌ |
| codecov-flags | Comma-separated list of Codecov flags for categorizing coverage. | e2e-tests | ❌ |
| credentials-secret-name | Secret containing OCI registry credentials for pushing artifacts. | coverport-secrets | ❌ |

## Results

| Name | Description |
|------|-------------|
| coverage-collected | Number of components with coverage collected |
| coverage-uploaded | Number of components successfully uploaded |
| total-coverage | Total coverage percentage across all components |

## Workflow

1. **Collect Coverage** - Collects coverage from test pods and creates metadata.json manifest (coverport-collect)
2. **Push to OCI** - Pushes raw coverage + manifest to OCI registry (secure-push-oci)
3. **Upload to Codecov** - Batch processes all components and uploads to Codecov (coverport-upload)

## Usage

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: integration-tests-with-coverage
spec:
  tasks:
    - name: collect-and-upload-coverage
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/coverport-coverage/0.1/coverport-coverage.yaml
      params:
        - name: instrumented-images
          value: "quay.io/org/app-instrumented@sha256:abc"
        - name: oci-container
          value: "quay.io/org/test-artifacts:tag"
        - name: cluster-access-secret-name
          value: "test-cluster-kubeconfig"
```

### Suitable for upstream communities

