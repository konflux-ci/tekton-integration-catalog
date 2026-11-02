# Deploy FBC operator 0.4

This version retains [0.3's operator deployment behavior and parameters](../0.3/README.md),
adds an explicit OpenShift release choice, and uses the provisioning task with terminal
failure-phase and namespace handling from openshift/konflux-tasks #43.
The 0.2 wrapper and 0.3 pipeline keep their existing interface.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `CLUSTER_RELEASE_CHANNEL` | `stable` | OpenShift update channel: `stable`, `fast` or `candidate`. This is separate from OLM's `CHANNEL_NAME`. |
| `CLUSTER_RELEASE_VERSION` | empty | Exact OpenShift release version, for example `5.0.0`. Empty retains selection of the detected catalog series. |

An explicit version must belong to the detected catalog major/minor series. The task
rejects a `4.22.x` or `5.1.x` override for a `5.0` catalog before cloud provisioning.
It constructs release JSON using `jq` arguments rather than interpolating parameter
values into JSON or shell source.

For the verified November 2 GA payload available in `candidate-5.0`, configure:

```yaml
params:
  - name: CLUSTER_RELEASE_CHANNEL
    value: candidate
  - name: CLUSTER_RELEASE_VERSION
    value: 5.0.0
```

Use `pipelineruns/deploy-fbc-operator/0.3/deploy-fbc-operator-run.yaml` for the
PipelineRun wrapper. Publish/review this version before switching a scenario to it.
Record the resolved pipeline/task identities, selected payload digest, actual cluster
version and installed CSV. Channel availability and test success do not establish
product support or authorize a release. Restore ordinary stable selection when that
channel supplies the intended release.

Run the functional release-selection checks without cloud provisioning:

```sh
python3 pipelines/deploy-fbc-operator/0.4/tests/test-release-selection.py
```

These checks execute the inline task's actual shell script with positive and negative
inputs, assert its release JSON, and verify the provisioning dependency. Server admission
and an actual intended-bundle install remain separate runtime checks.
