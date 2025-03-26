# Sealights Test Recommendation Task

Version: 0.1

## Description

This Tekton task automates the process of retrieving test recommendations from Sealights for a specific test stage within a build session. It queries the Sealights API to determine whether tests should be executed and outputs the recommended test list. This enables optimized test execution based on Sealights' analytics.

## Features

- Fetches test recommendations from Sealights based on the provided Build Session ID (BSID) and test stage.
- Outputs a list of recommended tests.
- Determines whether the test stage should be executed or skipped.
- Securely retrieves authentication credentials from a Kubernetes secret.

## Results

This task produces the following results:

- **`tests-recomendation-list`**: A JSON array of test recommendations from Sealights.
- **`run-test-stage`**: A boolean (`true` or `false`), indicating whether the test stage should be executed based on Sealights' recommendation.

## Parameters

The following parameters configure the task:

- **`sealights-domain`** (string, default: `redhat.sealights.co`): The domain of the Sealights API server.
- **`sealights-bsid`** (string, required): The Sealights Build Session ID (BSID) associated with a specific build.
- **`test-stage`** (string, required): The name of the test stage (e.g., `integration`, `e2e`) used to fetch test recommendations.

## Volumes

- **`sealights-credentials`**: A Kubernetes secret containing the Sealights authentication token.

## Steps

### 1. **Retrieve Sealights Test Recommendations**

- Reads the Sealights authentication token from the mounted secret.
- Calls the Sealights API to fetch test recommendations for the given BSID and test stage.
- Checks if recommended tests exist:
  - If tests are recommended, logs the test details and sets `run-test-stage` to `true`.
  - Otherwise, logs a message indicating that tests can be skipped and sets `run-test-stage` to `false`.
- Saves the test recommendations to the `tests-recomendation-list` result.

## Example Usage

This task can be included in a Tekton pipeline as follows:

```yaml
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: sealights-test-recommendation-run
spec:
  pipelineSpec:
    tasks:
      - name: fetch-test-recommendations
        taskRef:
          name: sealights-tests-recommendation
        params:
          - name: sealights-domain
            value: "redhat.sealights.co"
          - name: sealights-bsid
            value: "your-build-session-id"
          - name: test-stage
            value: "integration"
```

### Notes

- Ensure that the `sealights-credentials` secret is properly configured in your Kubernetes cluster.
