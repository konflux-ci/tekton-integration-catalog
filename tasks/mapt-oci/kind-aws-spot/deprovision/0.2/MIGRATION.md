# Migration from 0.1 to 0.2

The `destroy` inline step has been extracted into a standalone StepAction,
making it independently reusable and composable. The task interface (params, volumes)
is unchanged.

## What changed

| Step | StepAction |
|---|---|
| `destroy` | `stepactions/kind-aws-destroy/0.1` |

## Action from users

Update the `pathInRepo` reference from `deprovision/0.1/kind-aws-deprovision.yaml` to
`deprovision/0.2/kind-aws-deprovision.yaml`. No parameter changes are required.
