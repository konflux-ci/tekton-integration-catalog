---
name: running-task-tests
description: Use when running, writing, or troubleshooting functional tests for Tekton tasks in this catalog
---

# Running Task Tests

## Overview

Tests are Tekton Pipelines that exercise a task on a kind cluster with Konflux CI. The test runner creates a namespace, applies the task, and runs each test pipeline via `tkn p start`.

## When to Use

- Running tests for a new or modified task
- Writing positive or negative test cases
- Understanding why a test pipeline failed in CI
- **Not for**: YAML lint or validation (use `yamllint .` directly)

## Quick Reference

| Action | Command |
|--------|---------|
| Run tests for one task | `.github/scripts/test_tekton_tasks.sh tasks/<cat>/<name>/<ver>` |
| Run a single test file | `.github/scripts/test_tekton_tasks.sh tasks/<cat>/<name>/<ver>/tests/test-<name>-pass.yaml` |
| Run multiple tasks | `.github/scripts/test_tekton_tasks.sh <dir1> <dir2> ...` |

**Prerequisites**: kind cluster with Konflux CI, plus `tkn`, `kubectl`, `yq`, `jq` on PATH.

## Writing Tests

### File placement

```
tasks/<category>/<name>/<version>/tests/
  test-<name>-pass.yaml            # Positive test (required)
  test-<name>-fail.yaml            # Negative test (recommended)
  pre-apply-task-hook.sh           # Optional cluster setup
```

### Positive test

Pipeline succeeds with valid inputs:

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

### Negative test

Annotate which task should fail:

```yaml
metadata:
  name: test-<task-name>-fail
  annotations:
    test/assert-task-failure: "run-<task-name>"
```

The runner verifies the pipeline failed **at the annotated task**, not earlier.

### Pre-apply hook

`pre-apply-task-hook.sh` receives `$1` (task YAML path) and `$2` (test namespace). Use it for ConfigMaps, Secrets, PVCs, Deployments, or RBAC the task needs.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Tests share PVC data path | Each test must use a unique path (e.g. `test-repo-pass`, `test-repo-fail`) |
| No `tests/` directory | CI silently skips the task — no gate, no coverage |
| Wrong `test/assert-task-failure` value | Must match the pipeline task **name**, not the taskRef |
| Missing `appstudio-pipeline` SA | Runner creates it, but hooks adding RoleBindings must reference it correctly |

## Exemplar

Reference implementation: `tasks/linters/yamllint/0.1/` — has positive test, negative test, pre-apply hook with git-daemon service, and PVC-based data sharing.
