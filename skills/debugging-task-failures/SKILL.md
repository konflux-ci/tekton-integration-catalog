---
name: debugging-task-failures
description: Use when a Tekton task test fails in CI or locally and you need to find the root cause
---

# Debugging Task Failures

## Overview

Task tests run as Tekton PipelineRuns in isolated namespaces. Debugging requires inspecting the PipelineRun, TaskRun, and pod logs in the test namespace.

## Namespace Convention

The test runner creates namespace `{task-name}-{version-with-hyphens}`. Example: task `yaml-lint` version `0.1` runs in namespace `yaml-lint-0-1`.

## Debugging Steps

### 1. Find the failed run

```bash
NS="<task-name>-<version-hyphens>"
kubectl get pipelinerun -n "$NS"
kubectl get taskrun -n "$NS"
```

### 2. Read the logs

```bash
# All logs for a pipelinerun
tkn pr logs <pipelinerun-name> -n "$NS"

# Specific taskrun
tkn tr logs <taskrun-name> -n "$NS"

# Raw pod logs (if tkn output is truncated)
kubectl logs -n "$NS" -l tekton.dev/pipelineRun=<pipelinerun-name> --all-containers
```

### 3. Check events

```bash
kubectl get events -n "$NS" --sort-by=.lastTimestamp
```

### 4. Inspect task YAML as applied

```bash
kubectl get task <task-name> -n "$NS" -o yaml
```

### 5. Check pre-apply hook output

If a `pre-apply-task-hook.sh` exists, verify its resources were created:

```bash
kubectl get all -n "$NS"
kubectl get pvc,configmap,secret -n "$NS"
```

## Common Failure Patterns

| Symptom | Likely Cause |
|---------|--------------|
| `ImagePullBackOff` | Image digest wrong or registry auth missing |
| Task passes but negative test reports success | `test/assert-task-failure` annotation value doesn't match pipeline task name |
| `No such file or directory` in script | PVC data path mismatch between setup and task steps |
| Pipeline stuck in `Unknown` | Cluster resource limits or Tekton controller not ready |
| `Permission denied` | Missing RBAC — add RoleBinding in pre-apply hook |

## CI vs Local Differences

- CI uses a **fresh kind cluster** per run; local clusters may have leftover state
- CI filters by changed files — only tasks with modified `tasks/**/*.{yaml,sh}` are tested
- Namespace from a previous local run may still exist; delete it or the runner reuses it
