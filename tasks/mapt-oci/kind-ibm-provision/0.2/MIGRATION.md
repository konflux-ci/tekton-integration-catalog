# Migration from 0.1 to 0.2

Version 0.2 adds the `compute-sizes` parameter and defaults it to the IBM Flex
profile `cxf-24x48` (24 vCPUs and 48 GiB). This profile takes precedence over
`cpus` and `memory`, so changing the Task reference from 0.1 to 0.2 changes the
effective default from 32 vCPUs and 64 GiB to 24 vCPUs and 48 GiB.

The `cpus` and `memory` parameter defaults remain `32` and `64` for the
fallback path. To preserve the 0.1 sizing, set `compute-sizes` to an empty
string and keep `cpus` at `32` and `memory` at `64`. To use another IBM profile,
set `compute-sizes` to that profile name.

Update the Task resolver path from
`tasks/mapt-oci/kind-ibm-provision/0.1/kind-ibm-provision.yaml` to
`tasks/mapt-oci/kind-ibm-provision/0.2/kind-ibm-provision.yaml` and pass
`compute-sizes` explicitly if you want to control the selected profile.
