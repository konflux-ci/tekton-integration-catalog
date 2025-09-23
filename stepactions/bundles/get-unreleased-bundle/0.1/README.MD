# get-unreleased-bundle stepaction

This StepAction retrieves the highest bundle version from a specified package, channel, and unreleased bundles list in the provided FBC fragment.
If package name and/or channel name are not specified, the step will determine the default package and/or channel name.

Default package name determination:
* If there is only one 'olm.package', it's name is returned
* If multiple 'olm.package' entries contain unreleased bundles, user input is required; the PACKAGE_NAME parameter must be set by the user

Default Channel Name Determination:
* The default channel name corresponds to the 'defaultChannel' entry of the selected package

The StepAction checks whether the highest bundle version is unreleased, specifically, not present in the Red Hat production Index Image (registry.redhat.io/redhat/redhat-operator-index).
If the bundle is unreleased, the StepAction returns it, along with the package name and channel name.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|fbcFragment|A FBC fragment image.||true|
|packageName|An OLM package name present in the fragment or leave it empty so the step will determine the default package name as described above.|""|false|
|channelName|An OLM channel name or leave it empty so the step will determine the default channel name as described above.|""|false|

## Results
|name|description|
|---|---|
|unreleasedBundle|The name of the bundle that is not in registry.redhat.io/redhat/redhat-operator-index.|
|packageName|An OLM package name associated with the unreleased bundle.|
|channelName|An OLM channel name associated with the unreleased bundle.|

## Example Usage

Here’s an example Tekton YAML configuration using this StepAction:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: get-unreleased-bundle-task
spec:
  steps:
    - name: get-unreleased-bundle
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/bundles/get-unreleased-bundle/0.1/get-unreleased-bundle.yaml
      params:
        - name: fbcFragment
          value: $(params.fbcFragment)
        - name: packageName
          value: $(params.packageName)
        - name: channelName
          value: $(params.channelName)
```

### Not suitable for upstream communities