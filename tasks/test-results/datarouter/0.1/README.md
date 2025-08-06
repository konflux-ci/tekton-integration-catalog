# Data Router Task

**Version:** 0.1

The Data Router task sends test results and metadata to configured target systems through the Data Router API. This task enables automated routing of test results to multiple destinations such as ReportPortal, Polarion, and ResultsDB based on the provided metadata configuration.

## Overview

This task uses the `droute` CLI tool to send test results and metadata to the Data Router service, which then routes the information to configured target systems. The task waits for the routing operation to complete before finishing, ensuring reliable delivery of test data.

## Parameters

| Name | Description | Default |
|------|-------------|---------|
| `datarouter-url` | Data Router API endpoint URL | |
| `datarouter-credentials` | Name of secret containing Data Router username and password | `datarouter-credentials` |
| `metadata-file` | Path to Data Router metadata JSON file in workspace | `metadata.json` |
| `results-pattern` | Glob pattern for xUnit test results files | |

## Workspaces

| Name | Description |
|------|-------------|
| `data` | Workspace containing metadata file and test results |

## Secrets

The task requires a secret containing Data Router authentication credentials. The secret should be structured as follows:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datarouter-credentials
type: Opaque
stringData:
  username: your-datarouter-username
  password: your-datarouter-password
```

## Metadata Format

The metadata file must follow the [Data Router metadata schema](https://gitlab.cee.redhat.com/ccit/data-router/droute-api/-/blob/main/drouteapi/json_schema/metadata_schema.json). 

Example metadata structure:

```json
{
    "targets": {
        "reportportal": {
            "config": {
                "hostname": "reportportal.example.com",
                "project": "MY_PROJECT"
            },
            "processing": {
                "apply_tfa": false,
                "property_filter": [
                    "^java.*", "sun.java.*"
                ],
                "launch": {
                    "name": "test-run-name",
                    "description": "Test run description",
                    "attributes": [
                        {
                            "value": "test_tag"
                        },
                        {   
                            "key": "environment",
                            "value": "production"
                        }
                    ]
                }
            }
        },
        "polarion": {
            "disabled": false,
            "config": {
                "project": "MyProject"
            },
            "processing": {
                "testsuite_properties": {
                    "polarion-lookup-method": "name",
                    "polarion-testrun-title": "test-run-name"
                },
                "testcase_properties": {
                }
            }
        },
        "resultsdb": {
        }
    }
}
```

## Usage

### Basic TaskRun Example

```yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  name: datarouter-send-results
spec:
  taskRef:
    name: datarouter
  params:
    - name: datarouter-url
      value: "https://datarouter.ccitredhat.com"
    - name: datarouter-credentials
      value: "datarouter-credentials"
    - name: metadata-file
      value: "metadata.json"
    - name: results-pattern
      value: "test-results/*.xml"
  workspaces:
    - name: data
      configMap:
        name: test-data
```

### Pipeline Integration Example

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-with-datarouter
spec:
  workspaces:
    - name: shared-data
  tasks:
    - name: run-tests
      taskRef:
        name: your-test-task
      workspaces:
        - name: output
          workspace: shared-data
    - name: send-results
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/test-results/datarouter/0.1/datarouter.yaml
      params:
        - name: datarouter-url
          value: "https://datarouter.ccitredhat.com"
        - name: results-pattern
          value: "*.xml"
      workspaces:
        - name: data
          workspace: shared-data
      runAfter:
        - run-tests
```

## Additional Info

- **Image:** [quay.io/dno/droute](https://quay.io/repository/dno/droute?tab=info)
- **Usage Docs**: [Data Router User's Guide](https://spaces.redhat.com/x/7VbhB)
