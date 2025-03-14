# gather-cluster-resources stepaction

This StepAction runs a script to gather konflux pipeline related artifacts and includes the possibility to run a
second custom script to gather team related artifacts.
We need to either pass the credentials to be mounted on the container with the path to the kubeconfig or
pass directly the ocp login command.
If you choose to login via oc login command, please pass the credentials as a valid name of a valume that is of 
emptyDir type.
The gather-url should be passed as a list of urls ["<url_1>", "<url_2>"]. Don't pass this if you just want to 
run the konflux related resources gathering job.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|credentials|A volume containing credentials to the remote cluster||true|
|kubeconfig|Relative path to the kubeconfig in the mounted cluster credentials volume||false|
|ocp-login-command|Command to log in to the OpenShift cluster||false|
|gather-url|URL for the custom resource gathering script. Should be a list of strings||false|
|artifact-dir|Relative path to where you want the artifacts to be stored||false|

