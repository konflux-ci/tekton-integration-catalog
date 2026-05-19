# Tekton Integration Catalog - Agent Quick Reference

Reusable Tekton Tasks, StepActions, and Pipelines for Konflux CI integration testing.

## Data Flow

Konflux PipelineRun (PAC trigger) -> `test-metadata` (extracts SNAPSHOT, git info, PAC labels) -> downstream tasks (provision infra, run tests, report results) -> task results consumed by later pipeline stages

## Key Paths

`tasks/<category>/<name>/<version>/` task definitions | `stepactions/<name>/<version>/` reusable step units | `pipelines/<name>/<version>/` pipeline definitions
`scripts/` helper scripts | `konflux/` Dockerfiles for utils + Sealights images | `docs/TESTING.md` testing guide
`.github/workflows/` CI gates | `.github/scripts/test_tekton_tasks.sh` functional test runner

## Adding a Task

1. Create `tasks/<category>/<name>/<version>/<name>.yaml` (Tekton `v1` Task spec)
2. Add `README.md` in the same directory
3. Set labels: `upstream-usable: "true"|"false"`, `app.kubernetes.io/version`, `tekton.dev/tags: konflux`
4. Add `tests/test-<name>-pass.yaml` (optionally `test-<name>-fail.yaml` with `test/assert-task-failure` annotation)
5. Verify: `yamllint .` and `kubectl apply -f <task>.yaml --dry-run=server`

## Versioning

Directory-based: `0.1/`, `0.2/`, etc. New version when interface changes (params, workspaces, results) or behavior is not backward-compatible. Never modify an existing version's interface.

## Test Framework

Tests are Tekton Pipelines in `tasks/<...>/<version>/tests/test-*.yaml`. Positive tests pass on pipeline success. Negative tests use annotation `test/assert-task-failure: "<task-name>"` — pass if the named task fails. Runner: `.github/scripts/test_tekton_tasks.sh <task-dir>...` — requires kind + Konflux CI, `tkn`, `kubectl`, `yq`, `jq`.

## CI Gates

| Gate | Check |
|------|-------|
| yamllint | All YAML syntax |
| checkton | ShellCheck on embedded bash |
| validate YAMLs | `kubectl apply --dry-run=server` on all tasks/stepactions/pipelines |
| run-task-tests | Functional tests for changed tasks with `tests/` dir |
| validate-agents-md | Ensures this file stays under 60 lines |

## Konflux Patterns

- **SNAPSHOT param**: JSON string from Konflux; parse with `jq` to extract component info
- **PAC labels**: `pac.test.appstudio.openshift.io/*` on PipelineRun metadata — read via `fieldRef`
- **appstudio-pipeline SA**: Required in test namespaces (Konflux convention)
- **upstream-usable label**: `"true"` = safe for external use, `"false"` = internal only

## Testing & Security Expectations

- Every new or modified task **must** include functional tests in `tests/` — no exceptions
- If you encounter a task without tests, add them before making other changes
- Include both positive (valid input succeeds) and negative (invalid input fails correctly) test cases
- Tests share a namespace and PVC per task — each test pipeline must use a unique data path (e.g. `test-repo-pass`, `test-repo-fail`)
- Never embed secrets, tokens, or credentials in task YAML or test fixtures — use Kubernetes Secrets
- Pin production images by digest (`latest` ok for dev/utils); bash must use `set -o errexit -o nounset -o pipefail`
- Tasks producing outputs for downstream consumers (artifact tags, status, URLs) must declare `results`
- Tasks using `runAsUser: 0` require explicit justification in the PR
- Templated CI files (`<TEMPLATED FILE!>`) come from `konflux-ci/task-repo-shared-ci` — fix upstream
