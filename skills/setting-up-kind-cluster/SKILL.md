---
name: setting-up-kind-cluster
description: Use when setting up or tearing down a local kind cluster for running Tekton task tests
---

# Setting Up a Kind Cluster

## Overview

Task tests require a kind cluster with Konflux CI installed. This skill covers setup, teardown, and common issues.

## Setup

### 1. Create the cluster

```bash
git clone https://github.com/konflux-ci/konflux-ci.git /tmp/konflux-ci
kind create cluster --config /tmp/konflux-ci/kind-config.yaml
```

### 2. Deploy Konflux dependencies and platform

```bash
cd /tmp/konflux-ci
./deploy-deps.sh
./wait-for-all.sh
./deploy-konflux.sh
./deploy-test-resources.sh
```

### 3. Verify readiness

```bash
kubectl get pods -A | grep -v Running | grep -v Completed
```

All pods should be `Running` or `Completed`. If not, wait and re-check.

### 4. Install CLI tools

Ensure these are on PATH: `tkn`, `kubectl`, `yq`, `jq`

```bash
# tkn (Tekton CLI)
# See https://tekton.dev/docs/cli/ or use the repo's custom action logic:
# .github/actions/install-tkn/
```

## Teardown

```bash
kind delete cluster
```

To clean up a specific test namespace without destroying the cluster:

```bash
kubectl delete namespace <task-name>-<version-hyphens>
```

## Tips

- **Reuse the cluster** across test runs — only the namespace is test-specific
- **Stale namespaces** from previous runs are reused by the test runner (no conflict)
- The CI workflow pins a specific `konflux-ci` commit (`ab849590`); for local dev, using `main` is fine but results may differ
- If `deploy-deps.sh` hangs, check `kubectl get events -A` for image pull or resource issues
- Kind config from `konflux-ci/kind-config.yaml` sets up port mappings and extra mounts — don't use a bare `kind create cluster`

## Quick Smoke Test

After setup, verify Tekton is working:

```bash
kubectl get pods -n tekton-pipelines
tkn version
```
