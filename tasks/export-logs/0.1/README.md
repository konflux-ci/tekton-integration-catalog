# EXPORT PIPELINE LOGS TO QUAY TASK

**Version:** 0.1

The **`export-pipeline-logs`** Task is responsible for gathering **all execution logs** from a completed Tekton PipelineRun and packaging them into a compressed **`tar.gz`** artifact. The task **waits** for all other TaskRuns in the PipelineRun to complete, excluding itself. It then **iterates** through each underlying Pod to retrieve and collect the complete log stream.

It **pushes** the archived log data as a secure **OCI Artifact** to the same registry location as the build image, SBOM, and source code artifacts. Users can **download** and **extract** this log data artifact by using the **`oras`** command-line tool.

This Task is intended to be **called** in the **`finally`** section of the PipelineRun.

## Parameters


| name                              | description                                                                                                                    | default value                      | required |
| :---------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------- | :--------- |
| **`quay-repo`**                   | The base OCI repository path (e.g.,`quay.io/org/repo`). The final timestamped tag is appended automatically.                   |                                    | true     |
| **`pipeline-run-name`**           | The name of the PipelineRun whose logs should be collected (use`$(context.pipelineRun.name)`).                                 |                                    | true     |
| **`namespace`**                   | The namespace where the PipelineRun was executed (use`$(context.pipelineRun.namespace)`).                                      | `$(context.pipelineRun.namespace)` | false    |
| **`artifact-credentials-secret`** | Name of the Kubernetes Secret containing the registry credentials (`.dockerconfigjson` key) needed for the OCI push operation. |                                    | true     |

## Usage

```yaml
spec:
  # ... (main pipeline configuration) ...
  finally:
    - name: export-logs-for-retention
      taskRef:
        name: export-pipeline-logs
      params:
        - name: pipeline-run-name
          value: $(context.pipelineRun.name)
        - name: namespace
          value: $(context.pipelineRun.namespace)
        - name: quay-repo
          value: $(params.output-image)
        - name: artifact-credentials-secret
          value: <YOUR_QUAY_PUSH_SECRET_NAME>
      workspaces:
        - name: shared-data
          workspace: log-export-workspace

  taskRunTemplate:
    serviceAccountName: <YOUR_BUILD_SERVICE_ACCOUNT>
  workspaces:
  - name: git-auth
    secret:
      secretName: '{{ git_auth_secret }}'
  - name: netrc
    emptyDir: {}
  - name: log-export-workspace
    emptyDir: {}
  - name: credentials-volume
    secret:
      secretName: <YOUR_QUAY_PUSH_SECRET_NAME>
```

## Results

The `export-pipeline-logs` Task produces one key output that identifies the location of the log archive.

### Suitable for upstream communities
