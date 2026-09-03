# AgentReady Improvement Plan

**Baseline score**: 37.5/100 (19 assessed, 14 N/A)
**Passes**: claude_md_file (100), readme_structure (100), separation_of_concerns (100), dependency_security (35)

Actions are ordered by effort-to-impact ratio per the scaffolding best practices guide.
Items marked **N/A for this repo** are false positives from a tool designed for Python/JS codebases applied to a Tekton YAML catalog.

---

## Tier 1 — Do This Week

### Single-File Verification (0/100, +5 pts potential)

**Action**: Add single-file lint commands to CLAUDE.md Build section.

```bash
# Lint a single YAML file
yamllint tasks/my-task/0.1/my-task.yaml

# Validate a single task against a cluster
kubectl apply -f tasks/my-task/0.1/my-task.yaml --dry-run=server

# ShellCheck an embedded script (extract first, then check)
```

These commands already work but aren't documented in the single-file format the tool expects.

### CI Quality Gates (73/100, +5 pts potential)

**Action**: The repo has 8 CI workflows (yamllint, checkton, shellcheck, hadolint, gitleaks, validate-yamls, run-task-tests, validate-agents-md). The tool failed to detect `run-task-tests` as a test gate — likely a naming/pattern recognition issue. Two options:

1. **Quick fix**: Add a comment or job name containing `test` more prominently in the workflow (may be enough for the tool to detect it)
2. **Proper fix**: Confirm the tool's detection heuristic and adjust workflow naming to match

### Standard Project Layouts (0/100, +5 pts potential)

**N/A for this repo.** The tool expects `src/` and `tests/` directories (Python/JS convention). This repo uses the Tekton catalog layout (`tasks/`, `stepactions/`, `pipelines/`) with tests nested inside task directories (`tasks/<name>/<version>/tests/`). This is the correct layout for this project type. Can be addressed with a `.agentready-config.yaml` exclusion if the tool supports it.

### Dependency Pinning (0/100, +5 pts potential)

**N/A for this repo.** No runtime dependencies to pin — this is a collection of YAML manifests. Container image pinning (by digest) is the equivalent practice here and is already documented in AGENTS.md. No lock file applies.

---

## Tier 2 — Do This Month

### Pattern References (0/100, +3 pts potential)

**Action**: Add a "Pattern References" section to CLAUDE.md pointing to real examples for common changes:

- New task: follow `tasks/linters/yamllint/0.1/` (task + README + tests + pre-apply hook)
- New stepaction: follow `stepactions/secure-push-oci/0.2/`
- New pipeline: follow `pipelines/deploy-fbc-operator/0.2/`
- New version of existing task: follow `tasks/test-metadata/` (0.1 through 0.4 progression)

### One-Command Setup (30/100, +3 pts potential)

**Action**: The test runner already exists but requires manual cluster setup. Add a Makefile with:

```makefile
.PHONY: lint test validate

lint:
	yamllint .

validate:
	# Requires kind cluster with Tekton
	.github/scripts/validate-all.sh

test:
	# Requires kind cluster with Konflux CI
	@echo "Usage: make test TASK=tasks/linters/yamllint/0.1"
	.github/scripts/test_tekton_tasks.sh $(TASK)
```

### Deterministic Enforcement (0/100, +3 pts potential)

**Action**: Add a pre-commit config with yamllint and checkton hooks:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
```

### Conventional Commits (0/100)

**Action**: Add conventional-pre-commit hook to `.pre-commit-config.yaml`. The CONTRIBUTING.md doesn't currently mandate a commit format. Decide if this is worth enforcing for this repo.

### Gitignore Completeness (40/100)

**Action**: Add missing patterns to `.gitignore`:

```
*.swp
*.swo
.DS_Store
```

### Concise Documentation (67/100)

**Action**: README has 15.6 headings per 100 lines (target: 3-5). The README uses many emoji-prefixed subsections. Consider consolidating headings or moving detailed content to `docs/`. Low priority -- the content is good, just over-structured.

---

## Tier 3 — Do This Quarter

### ADRs (0/100)

**Action**: Create `docs/adr/` with at least one decision. Good candidates for this repo:
- ADR-0001: Directory-based versioning strategy for tasks
- ADR-0002: Test framework using Tekton Pipelines (not pytest/go test)
- ADR-0003: Upstream-usable labeling convention

### Design Intent (30/100)

**Action**: The CLAUDE.md Design Choices section partially covers this but lacks preconditions/invariants format. Add a `docs/design/` directory with:
- `task-conventions.md` — invariants for task interfaces (SNAPSHOT format, PAC label contract, image pinning rules)
- `test-framework.md` — preconditions for the test runner (kind cluster, Konflux CI, appstudio-pipeline SA)

### Repomix Config (0/100)

**Action**: Low priority for this repo. Repomix generates AI-friendly context from code, but this repo is mostly YAML + shell. If desired: `agentready repomix-generate --init`.

---

## Tier 4 — Low Priority

### Code Smells / Linters (0/100)

**Action**: Add `actionlint` for GitHub Actions validation and `markdownlint` for docs. Both are useful but low-impact for agent workflows.

### Issue & PR Templates (0/100)

**Action**: Add `.github/PULL_REQUEST_TEMPLATE.md` and `.github/ISSUE_TEMPLATE/` with bug report and feature request templates. Standard GitHub hygiene, not agent-specific.

---

## Estimated Score After Tier 1+2 Actions

| Change | Points |
|--------|--------|
| Single-file verification (document commands) | +5 |
| CI quality gates (naming fix) | +2-5 |
| Pattern references | +3 |
| One-command setup (Makefile) | +2-3 |
| Deterministic enforcement (pre-commit) | +3 |
| Gitignore completeness | +1-2 |

**Estimated new score: ~55-60/100** (from 37.5) with Tier 1+2 actions alone.
Standard Layouts and Dependency Pinning would add +10 more but are false positives for this repo type.
