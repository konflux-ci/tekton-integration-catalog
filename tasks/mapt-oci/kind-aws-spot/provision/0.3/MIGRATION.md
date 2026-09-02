# Migration from 0.2 to 0.3

The implementation of every inline step has been extracted into a standalone StepAction,
making each step independently reusable and composable. The task interface (params, results,
volumes) is unchanged.

## What changed

All five previously inline steps now delegate to StepActions via `resolver: git`:

| Step | StepAction |
|---|---|
| `create-kubeconfig-secret` | `stepactions/create-kubeconfig-secret/0.1` |
| `create-ssh-credentials-secret` | `stepactions/create-ssh-credentials-secret/0.1` |
| `provisioner` | `stepactions/kind-aws-provisioner/0.1` |
| `update-kubeconfig-secret` | `stepactions/update-kubeconfig-secret/0.1` |
| `update-ssh-credentials-secret` | `stepactions/update-ssh-credentials-secret/0.1` |

> **Note:** `protect-control-plane` was already a StepAction reference in 0.2 and is unchanged.

Task results are now populated via `value: $(steps.<step-name>.results.secret-name)`
instead of each step writing directly to `$(results.<name>.path)`.

## Action from users

Update the `pathInRepo` reference from `provision/0.2/kind-aws-provision.yaml` to
`provision/0.3/kind-aws-provision.yaml`. No parameter or result changes are required.
