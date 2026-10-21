# Migration from protect-control-plane 0.2 to 0.3

Update the StepAction resolver path to
`stepactions/protect-control-plane/0.3/protect-control-plane.yaml` to opt into
the updated startup ordering and failure handling. The parameters and their
defaults are unchanged from version 0.2.

## Failure behavior

Version 0.3 returns a non-zero exit code when a required hardening or
readiness operation fails. With Tekton's normal step behavior, this fails the
invoking step and stops the Task or PipelineRun according to its configured
failure handling. Version 0.2 remains available for callers that need its
previous best-effort behavior, where some failures were recorded in the
summary while execution continued.

Before switching, verify that callers are prepared for the StepAction failure
to fail the containing step. If they require best-effort execution, continue
using version 0.2 and handle its reported failures explicitly.

## Startup and node-operation reliability

Version 0.3 waits for API and node readiness before running fatal
connectivity/node checks. Each privileged node-operation pod receives a
collision-resistant name and invocation label that remain fixed across create
retries. The StepAction accepts an existing pod only when its label matches
the current invocation, and reconciles uncertain creates for a bounded period
to clean up a matching late-created pod before reporting failure.
