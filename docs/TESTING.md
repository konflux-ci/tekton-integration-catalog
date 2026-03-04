# Testing Guide

This document explains how to write and run functional tests for Tekton tasks in the catalog.

## Overview

The functional testing framework runs tests in a kind cluster with Konflux CI installed. Tests are written as Tekton Pipelines that exercise tasks with various inputs and verify expected behavior.

## Running Tests Locally

### Prerequisites

- kind cluster with Konflux CI installed
- kubectl configured to access the cluster
- tkn (Tekton CLI) installed

### Run Tests for a Specific Task

```bash
.github/scripts/test_tekton_tasks.sh tasks/linters/yamllint/0.1
```

### Run Tests for Multiple Tasks

```bash
.github/scripts/test_tekton_tasks.sh tasks/linters/yamllint/0.1 tasks/other/task/0.1
```

## Writing Tests

### Test Location and Naming

Tests are located in `tasks/<category>/<name>/<version>/tests/` directory.

Test files must follow the naming pattern: `test-*.yaml`

Example: `tasks/linters/yamllint/0.1/tests/test-yamllint-pass.yaml`

### Test Pattern

Tests are Tekton Pipelines that:
1. Set up test data (create files, git repos, etc.)
2. Run the task under test
3. Validate results via pipeline success/failure

### Positive Tests

Positive tests verify tasks succeed with valid inputs:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-<task-name>-pass
spec:
  tasks:
    - name: setup
      # Create test data
    - name: run-<task-name>
      taskRef:
        name: <task-name>
      params:
        - name: param1
          value: "valid-value"
```

### Negative Tests

Negative tests verify tasks fail appropriately with invalid inputs.

Use the `test/assert-task-failure` annotation to specify which task should fail:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-<task-name>-fail
  annotations:
    test/assert-task-failure: "run-<task-name>"
spec:
  tasks:
    - name: setup
      # Create invalid test data
    - name: run-<task-name>
      taskRef:
        name: <task-name>
      params:
        - name: param1
          value: "invalid-value"
```

The test passes if the specified task fails.

### Using Pre-Apply Hooks

For advanced setup, create `pre-apply-task-hook.sh` in the tests directory:

```bash
#!/bin/bash
# tasks/<category>/<name>/<version>/tests/pre-apply-task-hook.sh

TASK_FILE=$1
NAMESPACE=$2

# Set up cluster state as needed for tests
kubectl create configmap mock-data -n $NAMESPACE --from-literal=key=value
```

The script receives:
- `$1`: Path to task YAML file
- `$2`: Test namespace

## CI Behavior

### Pull Requests

When you open a PR:
1. GitHub Actions detects modified files in `tasks/**/*.{yaml,sh}`
2. Extracts task directories (depth 3: e.g., `tasks/linters/yamllint/0.1`)
3. Filters to tasks with `tests/` subdirectory
4. Provisions kind cluster with Konflux
5. Runs test pipelines for modified tasks
6. Blocks merge if any tests fail

### Merge Queue

Tests run on merge queue branches to ensure main branch stays green.

## Examples

See the yamllint tests for reference:
- Positive test: `tasks/linters/yamllint/0.1/tests/test-yamllint-pass.yaml`
- Negative test: `tasks/linters/yamllint/0.1/tests/test-yamllint-fail.yaml`
- Pre-apply hook: `tasks/linters/yamllint/0.1/tests/pre-apply-task-hook.sh`

## Troubleshooting

### Test Pipeline Not Found

Ensure your test file:
- Is in `tests/` subdirectory
- Follows `test-*.yaml` naming
- Contains a valid Pipeline resource

### Task Not Available in Namespace

The test script applies tasks to test-specific namespaces.

If you reference other tasks, apply them in your pre-apply hook.
