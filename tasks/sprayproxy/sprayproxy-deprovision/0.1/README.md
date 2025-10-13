# SprayProxy Unregister Server Tekton Task

## Overview

The `sprayproxy-unregister-server` Tekton Task is designed to unregister Pipelines as Code (PAC) servers from the SprayProxy server. This task ensures that any unreachable PAC servers are removed cleanly from the SprayProxy backend.

## Features

- Logs into an ephemeral OpenShift cluster using a provided login command.
- Retrieves the list of currently registered PAC servers.
- Attempts to unregister the PAC server from the SprayProxy server.
- Retries the unregistration multiple times to ensure reliability.
- Verifies successful unregistration by listing registered PAC servers.

## Parameters

| Name               | Type   | Description                                             |
|--------------------|--------|---------------------------------------------------------|
| `ocp-login-command` | string | The OpenShift login command used for cluster authentication. |

## Secrets

This task requires the following secrets to be available in the cluster:

| Secret Name         | Key             | Description |
|--------------------|----------------|-------------|
| `sprayproxy-auth` | `server-token`  | Authentication token for SprayProxy API. |
| `sprayproxy-auth` | `server-url`    | URL of the SprayProxy server. |

## Steps

### 1. Login to OpenShift Cluster

The task first authenticates to the OpenShift cluster using the provided login command:

```sh
$(params.ocp-login-command)
```

### 2. Retrieve the PAC Controller Webhook URL

It then extracts the PAC controller’s webhook URL dynamically:

```sh
export WEBHOOK_URL=https://"$(oc get route pipelines-as-code-controller -n openshift-pipelines -o jsonpath='{.spec.host}')"
```

### 3. Unregister PAC Server from SprayProxy

The task attempts to unregister the PAC server from SprayProxy, retrying up to 5 times in case of failures:

```sh
curl -k -X DELETE -H "Authorization: Bearer ${SPRAYPROXY_SERVER_TOKEN}" "${SPRAYPROXY_SERVER_URL}"/backends --data '{"url": "'"$WEBHOOK_URL"'"}'
```

### 4. Verify Unregistration

It then verifies that the PAC server has been successfully unregistered:

```sh
curl -k -X GET -H "Authorization: Bearer ${SPRAYPROXY_SERVER_TOKEN}" "${SPRAYPROXY_SERVER_URL}"/backends
```

## Usage

To use this task in a Tekton Pipeline, define it in your pipeline YAML as follows:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: unregister-pac-server-pipeline
spec:
  tasks:
    - name: unregister-pac-server
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/sprayproxy/sprayproxy-deprovision/0.1/sprayproxy-deprovision.yaml
      params:
        - name: ocp-login-command
          value: "oc login --token=<your-token> --server=<your-server>"
```

## Requirements

- Tekton Pipelines (v0.12.1 or later)
- OpenShift CLI (`oc`) installed
- Valid OpenShift cluster credentials
- A running SprayProxy server in one of your clusters

### Not suitable for upstream communities