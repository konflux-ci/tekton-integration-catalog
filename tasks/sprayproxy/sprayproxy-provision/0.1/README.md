# SprayProxy Register Server Tekton Task

## Overview

The `sprayproxy-register-server` Tekton Task is responsible for registering the Pipelines as Code (PAC) server with a SprayProxy server. This task ensures that the PAC controller's webhook URL is available to SprayProxy for handling events effectively.

## Features

- Logs into an ephemeral OpenShift cluster using a provided login command.
- Retrieves the PAC controller's webhook URL dynamically.
- Sends the webhook URL to the SprayProxy server for registration.
- Retries registration multiple times to ensure reliability.
- Verifies successful registration by listing registered PAC servers.

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

### 3. Register PAC Server with SprayProxy

The task attempts to register the PAC server with SprayProxy, retrying up to 5 times in case of failures:

```sh
curl -k -X POST -H "Authorization: Bearer ${SPRAYPROXY_SERVER_TOKEN}" "${SPRAYPROXY_SERVER_URL}"/backends --data '{"url": "'"$WEBHOOK_URL"'"}'
```

### 4. Verify Registration

It then verifies that the PAC server has been successfully registered:

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
    - name: register-pac-server
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/sprayproxy/sprayproxy-provision/0.1/sprayproxy-provision.yaml
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