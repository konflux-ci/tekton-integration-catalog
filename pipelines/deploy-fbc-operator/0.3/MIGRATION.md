# Migration from 0.2 to 0.3

Version `0.3` replaces the deprecated **Environment-as-a-Service (EaaS)** cluster
provisioning with **OpenShift CI**-based ephemeral HyperShift cluster provisioning.

Konflux is [deprecating EaaS cluster provisioning](https://issues.redhat.com/browse/KONFLUX-15294)
in favor of OpenShift CI ephemeral clusters. Version `0.2` (and `0.1`) remain available and
unchanged so existing EaaS-based consumers are not broken, but they will stop working once EaaS
reaches end of life. New and migrating users should move to `0.3`.

## What changed

* **Provisioning** — The multi-step EaaS flow (`eaas-provision-space`,
  `eaas-get-supported-ephemeral-cluster-versions`,
  `eaas-get-latest-openshift-version-by-prefix`,
  `eaas-create-ephemeral-cluster-hypershift-aws`,
  `eaas-get-ephemeral-cluster-credentials`) is replaced by the single
  [`provision-ephemeral-cluster`](https://github.com/openshift/konflux-tasks/blob/9751a2028f2b3b88e4204d5c42de8eda4ebb466f/tasks/provision-ephemeral-cluster/0.1/provision-ephemeral-cluster.yaml)
  task from `openshift/konflux-tasks`, using the `hypershift-hostedcluster-workflow`.
* **OpenShift version selection** — The target OCP version is now read directly from the FBC
  fragment and requested from OpenShift CI. The pipeline no longer validates it against an EaaS
  supported-versions list.
* **Image mirroring** — The image digest mirror set is now injected through the provisioning
  task's `env-files` workspace as an `IMAGE_CONTENT_SOURCES` file, instead of the EaaS
  `imageContentSourcesFile` parameter.
* **Cluster credentials** — Downstream steps consume the kubeconfig `Secret` returned by
  `provision-ephemeral-cluster` (`secretRef` result), mounted as a volume, instead of the EaaS
  credentials StepAction.
* **New parameters** — `CLUSTER_PROFILE` selects the OpenShift CI cluster profile and defaults to
  `aws-konflux-prod`. `CREDENTIALS_SECRET_KEY` selects the key holding registry credentials and
  defaults to `oci-storage-dockerconfigjson`. The `provision-ephemeral-cluster` task is resolved
  from a pinned `openshift/konflux-tasks` commit.

## Prerequisites

Using the OpenShift CI shared cluster profiles requires access. See
[requesting access to shared cluster profiles](https://konflux.pages.redhat.com/docs/users/testing/integration/third-parties/openshift-ci.html).

## Action from users

In your `IntegrationTestScenario` YAML in your
[tenants-config](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/tenants-config?ref_type=heads):

1. Update the `pathInRepo` to point to the new pipeline run file:
    ```yaml
    - name: pathInRepo
      value: pipelineruns/deploy-fbc-operator/0.2/deploy-fbc-operator-run.yaml
    ```
2. If your registry credentials are stored under a key other than
   `oci-storage-dockerconfigjson`, set `CREDENTIALS_SECRET_KEY` to that key name.

Existing parameters retain their `0.2` defaults. The new `CLUSTER_PROFILE` parameter defaults to
`aws-konflux-prod`.
