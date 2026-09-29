# Trigger Jenkins Job

The following task can be used to trigger a Jenkins job using CURL request from a Tekton Task.

More details on Remote Access API can be found [here](https://www.jenkins.io/doc/book/using/remote-access-api/)

## Parameters

- **JENKINS_HOST_URL**: The URL on which Jenkins is running (**Required**)
- **JOB_NAME**: The Job name which needs to be triggered (**Required**)
- **JENKINS_SECRETS**: The name of the secret containing the username and API token for authenticating the Jenkins (_Default_: jenkins-credentials) (**Required**)
- **JOB_PARAMS**: Extra parameters which needs to be appended in the `CURL` request. (_Default_: ""). `JOB_PARAMS` is of type `array` so multiple arguments can be appended. `JOB_PARAMS` can be provided as follows:-

  ```yaml
  params:
    - name: JOB_PARAMS
      value: |
        - FILE_LOCATION_AS_SET_IN_JENKINS=@PATH_TO_FILE
  ```

- **CA_BUNDLE**: Path to a CA bundle file for TLS verification when Jenkins uses a private CA. Leave empty to use the system default trust store. (_Default_: "")

## Secrets

Secrets containing `username`,`API token` are used in the task for making the CURL request.
Your **JENKINS_SECRETS** secret should look like something similar to this:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-credentials
type: Opaque
stringData:
  username: username
  apitoken: api-token
```

## Usage

```
kind: Pipeline
apiVersion: tekton.dev/v1
metadata:
  name: ricky-its-pipeline
spec:
  tasks:
    - name: trigger-jenkins-job
      taskRef:
        resolver: "git"
        params:
        - name: url
          value: https://github.com/konflux-ci/tekton-integration-catalog.git
        - name: revision
          value: main
        - name: pathInRepo
          value: tasks/triggers/jenkins/0.2/trigger-jenkins-job.yaml
      params:
        - name: JENKINS_HOST_URL
          value: <your Jenkins URL>
        - name: JOB_NAME
          value: <your Jenkins job full project name>
```

### Using a Private CA

If your Jenkins server uses a certificate signed by a private CA, declare a
workspace in your Pipeline, map it to the task's `ca-bundle` workspace, and
bind the ConfigMap at PipelineRun time.

**Pipeline:**

```yaml
kind: Pipeline
apiVersion: tekton.dev/v1
metadata:
  name: my-jenkins-pipeline
spec:
  workspaces:
    - name: jenkins-ca
  tasks:
    - name: trigger-jenkins-job
      taskRef:
        name: trigger-jenkins-job
      workspaces:
        - name: ca-bundle
          workspace: jenkins-ca
      params:
        - name: JENKINS_HOST_URL
          value: https://jenkins.example.com
        - name: JOB_NAME
          value: my-job
        - name: CA_BUNDLE
          value: /workspace/ca-bundle/ca.crt
```

**PipelineRun:**

```yaml
kind: PipelineRun
apiVersion: tekton.dev/v1
metadata:
  name: my-jenkins-pipeline-run
spec:
  pipelineRef:
    name: my-jenkins-pipeline
  workspaces:
    - name: jenkins-ca
      configMap:
        name: my-corporate-ca
```

The `ca-bundle` workspace is optional. When omitted, the system default trust
store is used for TLS verification.

## Workspaces

| Name | Description | Optional |
|------|-------------|----------|
| **ca-bundle** | Workspace containing a CA certificate bundle for TLS verification against a private CA | Yes |

### Suitable for upstream communities