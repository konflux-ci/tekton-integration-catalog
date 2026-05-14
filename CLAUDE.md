# Tekton Integration Catalog - Claude AI Context

## Purpose

Reusable Tekton Tasks, StepActions, Pipelines, and PipelineRuns for **Konflux CI** integration testing.
Tasks are consumed by Konflux test pipelines to provision infrastructure, run linters, manage test metadata, and report results.

### Repository Layout

```
tasks/<category>/<name>/<version>/         # Tekton Task definitions + README
  tests/                                   # Functional tests (Tekton Pipelines)
stepactions/<name>/<version>/              # Tekton StepAction definitions
pipelines/<name>/<version>/                # Tekton Pipeline definitions
pipelineruns/<name>/<version>/             # Example PipelineRun YAMLs
scripts/                                   # Helper shell scripts
konflux/                                   # Konflux component Dockerfiles (utils image, Sealights agents)
.github/workflows/                         # CI: yamllint, checkton, YAML validation, task tests
.github/scripts/test_tekton_tasks.sh       # Functional test runner
.github/actions/install-tkn/               # Custom action to install tkn CLI
.tekton/                                   # Konflux Pipelines-as-Code PipelineRun templates
docs/TESTING.md                            # Testing guide
```

### Data Flow

Konflux PipelineRun (PAC trigger) -> `test-metadata` task (extracts SNAPSHOT, git info, PAC labels) -> downstream tasks (provision infra, run tests, report results) -> task results consumed by later pipeline stages.

### Key Images

| Image | Used By |
|-------|---------|
| `quay.io/konflux-qe-incubator/konflux-qe-tools:latest` | test-metadata, PR comment, ROSA deprovision, linters |
| `quay.io/konflux-ci/tekton-integration-catalog/utils:latest` | ROSA provision, export-logs, Sealights stepactions |
| `quay.io/konflux-ci/konflux-test:latest` | Bundle stepactions |
| `registry.redhat.io/openshift4/ose-cli:4.13` | mapt flows, protect-control-plane |
| `quay.io/redhat-developer/mapt:*` | mapt provision/deprovision |
| `ghcr.io/hadolint/hadolint:v2.14.0-debian` | Dockerfile linting |

## Build

This repo has no compiled artifacts — the "build" is YAML validation and image builds.

### Validate Locally

```bash
# Lint all YAML
yamllint .

# Dry-run validate a task against a cluster with Tekton installed
kubectl apply -f tasks/my-task/0.1/my-task.yaml --dry-run=server
```

### Adding a New Task

1. Create `tasks/<category>/<name>/<version>/<name>.yaml` following the [Tekton Task spec](https://tekton.dev/docs/pipelines/tasks/)
2. Add a `README.md` in the same directory with usage examples
3. Add the `upstream-usable` label (`"true"` if generally reusable, `"false"` if internal-only)
4. Add functional tests under `tests/` (see Test section)
5. Ensure YAML passes `yamllint` and `kubectl apply --dry-run=server`

### Adding a StepAction

1. Create `stepactions/<name>/<version>/<name>.yaml` following the [Tekton StepAction spec](https://tekton.dev/docs/pipelines/stepactions/)
2. Add a `README.md` with usage examples

### Adding a Pipeline / PipelineRun

1. Create under `pipelines/<name>/<version>/` or `pipelineruns/<name>/<version>/`
2. Add a `README.md` documenting the flow and required parameters

### CI Gates (GitHub Actions)

| Workflow | Trigger | What It Does |
|----------|---------|--------------|
| `yaml-lint.yaml` | PR | `yamllint .` on all YAML |
| `checkton.yaml` | PR | ShellCheck-style lint on embedded scripts |
| `validate-task-and-pipeline-yamls.yaml` | PR, merge queue | `kubectl apply --dry-run=server` on all tasks, stepactions, pipelines (Kind + Tekton) |
| `run-task-tests.yaml` | PR, merge queue | Detects changed `tasks/**/*.{yaml,sh}`, runs functional tests for tasks with a `tests/` directory (Kind + Konflux CI) |
| `validate-agents-md.yaml` | PR | Ensures `AGENTS.md` stays under 60 lines |

CI only runs functional tests for **changed** tasks that have tests — adding `tests/` to a task directory opts it into the test gate.

## Test

Tests are **Tekton Pipelines** that exercise a task and verify behavior through pipeline success/failure.

### Prerequisites

- kind cluster with [Konflux CI](https://github.com/konflux-ci/konflux-ci) installed
- `kubectl`, `tkn` (Tekton CLI), `yq`, `jq` on PATH

### Test Structure

```
tasks/<category>/<name>/<version>/tests/
  test-<name>-pass.yaml          # Positive test (pipeline should succeed)
  test-<name>-fail.yaml          # Negative test (annotated task should fail)
  pre-apply-task-hook.sh         # Optional: cluster setup before test run
```

### Writing Tests

**Positive test** — pipeline succeeds with valid inputs:
```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-<task-name>-pass
spec:
  tasks:
    - name: run-<task-name>
      taskRef:
        name: <task-name>
      params:
        - name: param1
          value: "valid-value"
```

**Negative test** — annotate which task should fail:
```yaml
metadata:
  name: test-<task-name>-fail
  annotations:
    test/assert-task-failure: "run-<task-name>"
```

### Pre-Apply Hooks

`pre-apply-task-hook.sh` receives `$1` (task YAML path) and `$2` (test namespace).
Use it to create ConfigMaps, Secrets, or other cluster state the task needs.

### Running Tests

```bash
# Single task
.github/scripts/test_tekton_tasks.sh tasks/linters/yamllint/0.1

# Multiple tasks
.github/scripts/test_tekton_tasks.sh tasks/linters/yamllint/0.1 tasks/linters/hadolint/0.1

# Single test file
.github/scripts/test_tekton_tasks.sh tasks/linters/yamllint/0.1/tests/test-yamllint-pass.yaml
```

The test runner creates a namespace `{task-name}-{version-with-hyphens}`, applies the task, creates the `appstudio-pipeline` ServiceAccount, and runs each test pipeline via `tkn p start`.

## Design Choices

### Versioning

Versions are **directory-based**: `tasks/<name>/0.1/`, `tasks/<name>/0.2/`, etc. Multiple versions coexist. Create a new version when the interface changes (params, workspaces, results), behavior is not backward-compatible, or a critical fix requires a different implementation. Never modify an existing version's interface.

### Task YAML Conventions

- **API version**: Prefer `tekton.dev/v1`; legacy tasks may use `v1beta1`
- **Labels**: `app.kubernetes.io/version`, `upstream-usable`, `tekton.dev/tags: konflux`
- **Annotations**: `tekton.dev/pipelines.minVersion`
- **Images**: Use pinned digests for production images; `latest` acceptable for dev/utils images

### Konflux Integration Patterns

- **`SNAPSHOT` param**: Standard Konflux JSON snapshot input — parse with `jq` to extract component info
- **PAC metadata**: Tasks needing pipeline context read labels/annotations via `fieldRef` (e.g. `pac.test.appstudio.openshift.io/*`, `appstudio.openshift.io/component`)
- **`appstudio-pipeline` SA**: Required in test namespaces (Konflux convention)
- **`upstream-usable` label**: `"true"` = safe for external use, `"false"` = internal only

### Security

- Never embed secrets in task YAML; use Kubernetes Secrets mounted as volumes or environment variables
- Pin production images by digest (e.g. `image@sha256:...`)
- Tasks running as `runAsUser: 0` should be flagged in review
- Validate inputs in bash scripts (`set -o errexit -o nounset -o pipefail`)

## Pitfalls

- Modifying an existing version's interface breaks downstream consumers — create a new version instead
- Tests only run in CI if `tests/` directory exists for the task — no directory means no gate
- `upstream-usable: "false"` tasks are internal; don't reference them from external pipelines
- YAML files must pass `yamllint` — check locally before pushing
- The test runner needs the `appstudio-pipeline` ServiceAccount — it creates it automatically, but pre-apply hooks may need to add RoleBindings
- Templated CI files (marked `<TEMPLATED FILE!>`) come from [konflux-ci/task-repo-shared-ci](https://github.com/konflux-ci/task-repo-shared-ci) — send fixes upstream, not here
- `AGENTS.md` must stay under 60 lines — CI enforces this; see `validate-agents-md.yaml`
