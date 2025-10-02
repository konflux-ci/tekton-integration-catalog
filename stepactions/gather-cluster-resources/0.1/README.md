# gather-cluster-resources stepaction

This StepAction runs a script to gather konflux pipeline related artifacts and includes the possibility to run a
second custom script to gather team related artifacts.
We need to either pass the credentials to be mounted on the container with the path to the kubeconfig or
pass directly the ocp login command.
If you choose to login via oc login command, please pass the credentials as a valid name of a volume that is of 
emptyDir type. In the example below, the empty-creds is a volume that would be valid for this case.
The gather-urls should be passed as a list of urls ["<url_1>", "<url_2>"]. Don't pass this if you just want to 
run the konflux related resources gathering job.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|credentials|A volume containing credentials to the remote cluster||true|
|kubeconfig|Relative path to the kubeconfig in the mounted cluster credentials volume||false|
|oc-login-command|Command to log in to the OpenShift cluster||false|
|gather-urls|A list of URLs for the custom resource gathering script||false|
|artifact-dir|Relative path to where you want the artifacts to be stored||false|

## Example Usage

Below is an example of how to use this stepAction. 
See this [example](https://github.com/konflux-ci/tekton-integration-catalog/blob/d533fcbaf34aca45eaf6176733af3b1446761fe9/tasks/rosa/hosted-cp/rosa-hcp-deprovision/0.2/rosa-hcp-deprovision.yaml#L47) on how you can share the working dir between steps
Please note that there needs to either be a step populating the credentials volume with the kubeconfig or
have the `oc login` command:
```yaml
- name: my-task-example
      taskSpec:
        volumes:
          - name: empty-creds
            emptyDir: {}
          - name: creds-volume
            secret: 
              secretName: creds
        steps:
            - name: gather-resources
              ref: 
                resolver: git
                params:
                  - name: url
                    value: https://github.com/konflux-ci/tekton-integration-catalog
                  - name: revision
                    value: main
                  - name: pathInRepo
                    value: stepactions/gather-cluster-resources/0.1/gather-cluster-resources.yaml
              params:
                - name: credentials
                  value: "creds-volume"
                - name: kubeconfig
                  value: "/path/to/kubeconfig" 
                - name: artifact-dir
                  value: /workspace/artifact-gathering
            - name: list-artifacts
              image: quay.io/konflux-qe-incubator/konflux-qe-tools:latest
              workingDir: "/workspace"
              script: |
                #!/bin/bash
                ls -la /workspace/artifact-gathering
```

### Suitable for upstream communities