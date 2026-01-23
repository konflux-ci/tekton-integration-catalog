# Functional Testing Framework Design

**Date:** 2026-01-23
**Status:** Approved

## Overview

Add functional testing capability and GitHub Actions workflow to tekton-integration-catalog, following the patterns established in konflux-ci/build-definitions and konflux-ci/release-service-catalog. The framework will enable automated testing of Tekton tasks in a kind cluster with Konflux installed.

## Scope

**Testing Coverage:** Tasks only (33 tasks)
- Tasks are the primary reusable units in the catalog
- Pipelines compose tasks, so task tests provide good coverage
- StepActions are tested implicitly through task tests
- Faster CI feedback loop

**Initial Implementation:** Hadolint task with dual tests
- One positive test (valid Dockerfile passes)
- One negative test (invalid Dockerfile fails as expected)
- Serves as template for future test development

## Architecture

The functional testing framework consists of three main components:

### 1. GitHub Actions Workflow

**Location:** `.github/workflows/run-task-tests.yaml`

**Triggers:**
- Pull requests (opened, synchronize, reopened)
- Merge queue checks

**Responsibilities:**
- Set up kind cluster using build-definitions approach
- Deploy Konflux CI components using scripts from konflux-ci/build-definitions
- Discover modified tasks by scanning `tasks/**/*.{yaml,sh}`
- Execute tests only for tasks with `tests/` directory
- Run test execution script with discovered task paths

**Job Steps:**
1. Checkout tekton-integration-catalog (this repo)
2. Checkout konflux-ci/build-definitions for deployment scripts
3. Setup kind cluster using `helm/kind-action@v1.13.0`
4. Install Tekton CLI (`tkn`)
5. Deploy Konflux dependencies (`deploy-deps.sh`)
6. Deploy Konflux CI (`deploy-konflux.sh`)
7. Deploy test resources (`deploy-test-resources.sh`)
8. Wait for all components (`wait-for-all.sh`)
9. Discover changed tasks (git diff on `tasks/**/*.{yaml,sh}`)
10. Filter tasks with `tests/` subdirectory
11. Execute `.github/scripts/test_tekton_tasks.sh`

**Runner:** `ubuntu-24.04`

### 2. Test Execution Script

**Location:** `.github/scripts/test_tekton_tasks.sh`

**Adapted from:** konflux-ci/build-definitions

**Features:**
- Test discovery from `tests/test-*.yaml` pattern
- Pre-apply hook support (`pre-apply-task-hook.sh`)
- Command mocking infrastructure
- Pipeline execution and monitoring
- Expected failure assertions via annotations
- Log capture and reporting

**Execution Flow:**
1. Accept task directory paths as arguments
2. Find all `tests/test-*.yaml` files in each task directory
3. Extract task name and version from directory structure
4. Execute pre-apply hook if present
5. Apply task definition to cluster
6. Apply test pipeline to cluster
7. Create test namespace and service account
8. Start pipeline using `tkn`
9. Monitor pipeline status by polling conditions
10. Check for `test/assert-task-failure` annotation
11. Capture and display logs on failure
12. Return exit code (0=success, 1=failure)

**Dependencies:**
- `kubectl` - cluster operations
- `tkn` - Tekton CLI
- `yq` - YAML parsing
- `jq` - JSON processing

### 3. Test Pipelines

**Location:** `tasks/<category>/<name>/<version>/tests/test-*.yaml`

**Pattern:**
- Tekton Pipeline resources that exercise the task under test
- Setup tasks create test data (git repos, files, etc.)
- Task under test runs against test data
- Validation via pipeline success/failure
- Optional result validation in final task

## Hadolint Test Implementation

### Positive Test: test-hadolint-pass.yaml

**Purpose:** Verify hadolint task succeeds with valid Dockerfile

**Strategy:**
1. Setup task creates temporary directory
2. Writes valid Dockerfile following best practices
3. Initializes git repository and commits
4. Hadolint task runs against local git repo
5. Pipeline succeeds if hadolint passes

**Valid Dockerfile:**
```dockerfile
FROM registry.access.redhat.com/ubi9/ubi:9.3
RUN dnf install -y python3 && dnf clean all
USER 1001
CMD ["/usr/bin/python3"]
```

**Characteristics:**
- Specific version tag (not `latest`)
- Clean package manager cache
- Non-root user
- Valid CMD format

### Negative Test: test-hadolint-fail.yaml

**Purpose:** Verify hadolint task fails with invalid Dockerfile

**Strategy:**
1. Setup task creates temporary directory
2. Writes problematic Dockerfile violating hadolint rules
3. Initializes git repository and commits
4. Hadolint task runs and fails
5. Pipeline uses `test/assert-task-failure: "run-hadolint"` annotation
6. Test passes if hadolint task fails as expected

**Invalid Dockerfile:**
```dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y python3
```

**Violations:**
- Uses `latest` tag (DL3007)
- No `apt-get clean` (DL3009)
- Runs as root user
- Missing layer optimization

## Konflux Deployment Approach

**Method:** Use build-definitions scripts

**Rationale:**
- Tasks designed for Konflux environment
- Reuse proven, working scripts
- Less maintenance burden
- Realistic test environment
- Many tasks reference Konflux-specific resources

**Scripts from konflux-ci/build-definitions:**
- `deploy-deps.sh` - Install cluster dependencies
- `deploy-konflux.sh` - Install Konflux CI components
- `deploy-test-resources.sh` - Set up test infrastructure
- `wait-for-all.sh` - Wait for components to be ready
- `kind-config.yaml` - Kind cluster configuration

## Hook and Mock Support

**Included Features:**
- Pre-apply task hooks for cluster setup
- Command mocking infrastructure
- Future-proofing for complex tests

**Rationale:**
- Already adapting build-definitions script
- Minimal additional complexity
- More useful framework for future tests
- Hadolint test won't use these (no harm)

**Hook Usage:**
- Optional `pre-apply-task-hook.sh` in test directory
- Executes before applying task/pipeline
- Can set up cluster state, mocks, ConfigMaps
- Script continues if hook doesn't exist

## Documentation

### Testing Guide

**Location:** Addition to main README or separate `TESTING.md`

**Contents:**
- Framework overview
- Local testing instructions
- Test file naming convention (`tests/test-*.yaml`)
- Writing test pipelines
- Expected failure annotations
- Pre-apply hook usage
- Command mocking examples

**Local Testing:**
```bash
# Run tests for specific task
.github/scripts/test_tekton_tasks.sh tasks/linters/hadolint/0.1

# Run tests for multiple tasks
.github/scripts/test_tekton_tasks.sh tasks/linters/hadolint/0.1 tasks/linters/yamllint/0.1
```

**CI Behavior:**
- Tests run automatically for modified tasks in PRs
- Only tasks with `tests/` directories are tested
- Test failures block PR merges
- Merge queue branches trigger tests

### Test Pattern Template

**Standard Pattern:**
1. Setup task creates test data/repository
2. Task under test runs against test data
3. Validation happens via pipeline success/failure
4. Optional: result validation in final task

**Positive Test:**
- Verify task succeeds with valid inputs
- Standard pipeline success

**Negative Test:**
- Verify task fails with invalid inputs
- Use `test/assert-task-failure: "<task-name>"` annotation
- Test succeeds when specified task fails

## Implementation Phases

### Phase 1: Framework Setup
- Create GitHub Actions workflow
- Adapt test execution script from build-definitions
- Add testing documentation

### Phase 2: Hadolint Tests
- Create positive test pipeline
- Create negative test pipeline
- Verify tests run in CI

### Phase 3: Validation
- Test PR workflow with task modifications
- Verify merge queue integration
- Document any issues or adjustments

## Success Criteria

- [ ] GitHub Actions workflow runs on PRs and merge queue
- [ ] Kind cluster provisions with Konflux installed
- [ ] Test script discovers and executes tests
- [ ] Hadolint positive test passes
- [ ] Hadolint negative test passes (task fails as expected)
- [ ] Documentation explains how to write tests
- [ ] CI blocks PRs when tests fail
- [ ] Framework supports hooks and mocks for future use

## Future Enhancements

- Add tests for other simple tasks (yaml-lint, shellcheck)
- Create comprehensive tests for complex tasks (deploy-fbc-operator, ROSA)
- Add integration tests that compose multiple tasks
- Generate test coverage reports
- Add performance benchmarks for tasks
