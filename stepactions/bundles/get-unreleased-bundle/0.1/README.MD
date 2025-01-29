# get-unreleased-bundle stepaction

This StepAction retrieves the highest bundle version from a specified package and channel in the provided FBC fragment.
If package name and/or channel name are not specified, the step will determine the default package and/or channel name.

Default package name determination:
* If there is only one 'olm.package', it's name is returned
* If multiple 'olm.package' entries contain unreleased bundles, user input is required; the PACKAGE_NAME parameter must be set by the user

Default Channel Name Determination:
* The default channel name corresponds to the 'defaultChannel' entry of the selected package

The StepAction checks whether the highest bundle version is unreleased, specifically, not present in the Red Hat production Index Image (registry.redhat.io/redhat/redhat-operator-index).
If the bundle is unreleased, the StepAction returns it.

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
