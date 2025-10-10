# Data Router Task

**Version:** 0.1

The Data Router task sends test results and metadata to configured target systems through the Data Router API.

## Parameters

| Name | Description | Default |
|------|-------------|---------|
| `datarouter-url` | Data Router API endpoint URL | `https://datarouter.ccitredhat.com` |
| `datarouter-credentials` | Name of secret containing Data Router username and password | `datarouter-credentials` |
| `oci-artifact-uri` | URI of the OCI artifact containing test results and metadata (e.g., quay.io/org/repo:tag) | |
| `oci-credentials` | Name of secret containing OCI registry credentials in dockerconfigjson format | `oci-registry-credentials` |
| `metadata-path` | Path to metadata JSON file within the OCI artifact | `metadata.json` |
| `results-pattern` | Glob pattern for test results files within the OCI artifact | `*.xml` |
| `attachments-dir` | Optional directory path for test attachments within the OCI artifact | |

## Results

| Name | Description |
|------|-------------|
| `status` | Status of the Data Router send operation (success/failure) |
| `routing-id` | Data Router routing request ID for tracking |

## Secrets

### Data Router Credentials

The task requires a secret containing Data Router authentication credentials:

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

### OCI Registry Credentials

For accessing private OCI registries, provide credentials in Docker config format. **Note: OCI credentials are optional for public registries.**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: oci-registry-credentials
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

Or create using kubectl:

```bash
kubectl create secret docker-registry oci-registry-credentials \
  --docker-server=quay.io \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

## OCI Artifact Structure

The OCI artifact should contain:
- **Metadata file**: JSON file following the Data Router metadata schema
- **Test results**: jUnit XML format test results
- **Attachments** (optional): Additional files to be uploaded with results

Example artifact structure:
```
/
├── metadata.json
├── test-results.xml
├── junit-results.xml
└── attachments/
    ├── screenshots/
    └── logs/
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
    - name: oci-artifact-uri
      value: "quay.io/myorg/test-results:pr-123"
    - name: oci-credentials
      value: "oci-registry-credentials"
    - name: metadata-path
      value: "metadata.json"
    - name: results-pattern
      value: "*.xml"
```

### Integration Pipeline Example

This example shows a complete pipeline that:
1. Runs integration tests
2. Pushes results to an OCI registry
3. Sends results to Data Router

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: integration-test-with-datarouter
spec:
  params:
    - name: SNAPSHOT
      description: The JSON string of the Snapshot under test
    - name: oci-registry
      description: OCI registry for storing artifacts
      default: "quay.io/myorg"
  tasks:
    - name: test-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/test-metadata/0.3/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: $(params.SNAPSHOT)
    
    - name: run-integration-tests
      runAfter:
        - test-metadata
      taskRef:
        name: your-integration-test-task
      params:
        - name: git-url
          value: "$(tasks.test-metadata.results.git-url)"
        - name: git-revision
          value: "$(tasks.test-metadata.results.git-revision)"
    
    - name: push-test-artifacts
      runAfter:
        - run-integration-tests
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/secure-push-oci/0.1/secure-push-oci.yaml
      params:
        - name: workdir-path
          value: "/workspace/test-results"
        - name: oci-ref
          value: "$(params.oci-registry)/test-results:$(tasks.test-metadata.results.pr-number)"
        - name: credentials-volume-name
          value: "oci-credentials"
    
    - name: send-to-datarouter
      runAfter:
        - push-test-artifacts
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
        - name: oci-artifact-uri
          value: "$(params.oci-registry)/test-results:$(tasks.test-metadata.results.pr-number)"
        - name: oci-credentials
          value: "oci-registry-credentials"
        - name: metadata-path
          value: "datarouter-metadata.json"
        - name: results-pattern
          value: "junit-*.xml"
        - name: attachments-dir
          value: "test-attachments"
```

## Additional Info

- **Image:** [quay.io/dno/droute](https://quay.io/repository/dno/droute?tab=info)
- **Data Router User's Guide:** [Data Router User's Guide](https://spaces.redhat.com/x/7VbhB)

### Suitable for upstream communities