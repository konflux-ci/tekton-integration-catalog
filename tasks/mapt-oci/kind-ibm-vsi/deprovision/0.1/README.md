# kind-ibm-deprovision

Destroys a cluster created by `kind-ibm-provision` using the same IBM COS
Pulumi backend and project ID. The IBM credential Secret must contain the API
key and COS HMAC credentials used during provisioning.

The Task retains the AWS task's cleanup flow: failed pipeline runs gather
cluster resources and upload them to OCI before the IBM mapt destroy action is
called.
