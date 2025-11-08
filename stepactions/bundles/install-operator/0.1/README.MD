# install-operator stepaction

This StepAction installs an operator from a provided FBC fragment.

    1. Determine the Installation Namespace:
      * Sets the install namespace to the operatorframework.io/suggested-namespace metadata annotation if it exists.
      * Otherwise, creates a randomly named namespace.
    2. Determine Target Namespaces for the Operator:
      * Extracts the supported install modes from the bundle metadata.
      * Assigns target namespaces based on the install mode in the following priority order:
          AllNamespaces → Uses an empty namespace (cluster-wide install)
          SingleNamespace → Uses "default"
          OwnNamespace → Uses the installation namespace
          MultiNamespace → Uses "openshift-marketplace,default"
      * If the install mode is unsupported, the script exits with an error.
    3. Create the OperatorGroup
    4. Create the CatalogSource
    5. Create the Subscription
    6. Approve the InstallPlan
    7. Wait for the ClusterServiceVersion to become Ready

## Parameters
|name|description|default value|required|
|---|---|---|---|
|fbcFragment|A FBC fragment image.||true|
|bundleImage|Operator bundle to install on a cluster.||true|
|packageName|The name of the operator package to be installed.||true|
|channelName|The name of the operator channel to track.||true|

## Example Usage

Here’s an example Tekton YAML configuration using this StepAction:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: install-operator-task
spec:
  steps:
    - name: install-operator
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/bundles/install-operator/0.1/install-operator.yaml
      params:
        - name: fbcFragment
          value: $(params.fbcFragment)
        - name: bundleImage
          value: $(params.bundleImage)
        - name: packageName
          value: $(params.packageName)
        - name: channelName
          value: $(params.channelName)
```

### Suitable for upstream communities