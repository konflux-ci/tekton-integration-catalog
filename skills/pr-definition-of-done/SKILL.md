---
name: pr-definition-of-done
description: Use when preparing, reviewing, or finalizing a pull request to this Tekton catalog repository
---

# PR Definition of Done

## Overview

Checklist for pull requests to the tekton-integration-catalog. Every item must pass before merge.

## Checklist

### Task/StepAction Changes

- [ ] YAML passes `yamllint .` locally
- [ ] `kubectl apply -f <file> --dry-run=server` succeeds (if cluster available)
- [ ] `README.md` exists in the task/stepaction version directory
- [ ] Labels set: `app.kubernetes.io/version`, `upstream-usable`, `tekton.dev/tags: konflux`
- [ ] Production images pinned by digest (not `:latest`)
- [ ] Bash scripts use `set -o errexit -o nounset -o pipefail`
- [ ] No secrets or credentials embedded in YAML
- [ ] Tasks producing outputs declare `results`

### Tests

- [ ] `tests/` directory exists with at least one `test-*-pass.yaml`
- [ ] Negative test (`test-*-fail.yaml`) included where applicable
- [ ] Each test uses unique data paths on shared PVC
- [ ] `pre-apply-task-hook.sh` included if cluster state setup is needed
- [ ] Tests pass locally: `.github/scripts/test_tekton_tasks.sh <task-dir>`

### Versioning

- [ ] Interface changes (params, workspaces, results) go in a **new version** directory
- [ ] Existing version interfaces are **never modified**

### General

- [ ] No changes to files marked `<TEMPLATED FILE!>` (fix upstream in `konflux-ci/task-repo-shared-ci`)
- [ ] `AGENTS.md` stays under 60 lines if modified
- [ ] `runAsUser: 0` usage is justified in PR description
