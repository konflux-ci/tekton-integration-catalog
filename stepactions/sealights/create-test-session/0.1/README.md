# Initialize Sealights Test Session

Version: 0.1

## Overview

The `initialize-sealights-session` initializes a new Sealights test session by creating a session ID using the Sealights API and storing it for later use in the pipeline.

## Features

- Automatically generates a **Sealights Test Session ID**.
- Stores the session ID as a result for use in later steps.
- Retrieves the **Sealights Agent Token** securely from a Kubernetes secret.

## Parameters

| Parameter         | Type   | Description |
|------------------|--------|-------------|
| `sealights-bsid` | string | The **Build Session ID (BSID)** assigned to the current Sealights build. |
| `test-stage`     | string | The stage of testing (e.g., `integration`, `e2e`). This helps categorize results in Sealights. |

## Results

| Result           | Description |
|-----------------|-------------|
| `test-session-id` | The generated **Sealights Test Session ID** that can be used in subsequent steps. |

## Workflow

1. **Check if Sealights is enabled**: The step runs only if `enable-sealights` is set to `"true"`.
2. **Retrieve credentials**: The Sealights Agent Token is loaded from the `sealights-credentials` secret.
3. **Create a test session**: A request is sent to the Sealights API to generate a test session ID.
4. **Store the session ID**: The generated session ID is stored in the step results for future use.

## Example Usage in a Tekton Pipeline

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: initialize-sealights-session-task
spec:
  steps:
    - name: initialize-sealights-session
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/sealights/initialize-session/0.1/initialize-sealights-session.yaml
      params:
        - name: sealights-bsid
          value: $(params.sealights-bsid)
        - name: test-stage
          value: $(params.test-stage)
```
