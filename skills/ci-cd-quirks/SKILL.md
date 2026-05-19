---
name: ci-cd-quirks
description: Use when confused by CI behavior, investigating why tests did or did not run, or troubleshooting GitHub Actions workflows
---

# CI/CD Quirks and Non-Obvious Behaviors

## Overview

This repo's CI has several non-obvious behaviors that can cause confusion when tasks aren't tested or PRs are blocked unexpectedly.

## Quirk 1: Tests Only Run for Changed Tasks with a `tests/` Directory

The `run-task-tests` workflow:
1. Detects files changed under `tasks/**/*.{yaml,sh}` at **depth 3**
2. Checks if each changed task directory has a `tests/` subdirectory
3. **Silently skips** tasks without `tests/`

**Consequence**: You can merge a task with no tests and CI won't complain. The test gate only activates when `tests/` exists.

## Quirk 2: Templated Files Must Not Be Edited Directly

Files marked with `<TEMPLATED FILE!>` at the top (e.g., `run-task-tests.yaml`, `test_tekton_tasks.sh`) are managed by [konflux-ci/task-repo-shared-ci](https://github.com/konflux-ci/task-repo-shared-ci). Edits here will be overwritten on the next sync. Fix upstream.

## Quirk 3: Changed-Files Detection Uses Depth 3

The `tj-actions/changed-files` step uses `dir_names_max_depth: "3"`. This means:
- `tasks/linters/yamllint/0.1/yaml-lint.yaml` -> detected as `tasks/linters/yamllint`
- Changes to `tests/` files also trigger detection of the parent task

If you add files outside the `tasks/` tree (e.g., `stepactions/`, `pipelines/`), the test workflow **does not detect them** — it only watches `tasks/**`.

## Quirk 4: Merge Queue Re-runs Tests

Both `pull_request` and `merge_group` triggers are active. Tests run on PR and again on merge queue entry. This is expected but means a slow test suite blocks the merge queue.

## Quirk 5: AGENTS.md Line Limit is CI-Enforced

`validate-agents-md.yaml` fails the PR if `AGENTS.md` exceeds 60 lines. This is a hard gate on PRs that touch `AGENTS.md`.

## Environment Variables

| Variable | Used By | Purpose |
|----------|---------|---------|
| `KUBECTL_CMD` | `test_tekton_tasks.sh` | Override kubectl binary path (default: `kubectl`) |
| `TEST_ITEMS` | `test_tekton_tasks.sh` | Space-separated task dirs (alternative to CLI args) |
| `GITHUB_WORKSPACE` | CI workflows | Root checkout path in Actions runners |

## Workflow Summary

| Workflow | Watches | Blocks Merge |
|----------|---------|--------------|
| `yaml-lint.yaml` | All YAML | Yes |
| `checkton.yaml` | Embedded bash in YAML | Yes |
| `validate-task-and-pipeline-yamls.yaml` | All tasks/stepactions/pipelines | Yes |
| `run-task-tests.yaml` | `tasks/**/*.{yaml,sh}` with `tests/` dir | Yes |
| `validate-agents-md.yaml` | `AGENTS.md` | Yes |
