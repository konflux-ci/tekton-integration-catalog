# Tekton Integration Catalog

## 👋 Introduction

Welcome to the **Tekton Integration Catalog**! This repository contains a collection of Tekton resources and helpers designed to simplify integration testing in **Konflux CI**. The goal is to make tests **easier to run, manage, and automate**, ensuring efficiency across Konflux Integration Tests System.

With prebuilt Tekton Tasks and StepActions, this catalog provides reusable components that help integrate and validate application components. By leveraging these resources, teams can streamline their testing processes and focus on delivering high-quality software.

## Testing

This repository includes functional tests for Tekton tasks. Tests run automatically in CI for modified tasks.

See [docs/TESTING.md](docs/TESTING.md) for details on writing and running tests.

### Quick Start

Run tests for a specific task:

```bash
.github/scripts/test_tekton_tasks.sh tasks/linters/hadolint/0.1
```

Tests require a kind cluster with Konflux CI installed.

## 📁 Structure

This repository is organized into several key directories, each serving a specific purpose for Tekton-related resources.

### 🛠 Tasks

The **Tekton Tasks** directory contains reusable tasks that define individual steps in your pipeline.

- **Adding a New Task**:
   To add a new task, create a `.yaml` file inside the `tasks/<your-task-name>/0.1/` directory. Ensure it follows the Tekton [Task specification](https://tekton.dev/docs/pipelines/tasks/), is well-documented (add `README.md` file), [well-versioned](#-versioning) and includes example usage.

### 🔄 StepActions

The **StepActions** directory houses modular building blocks that allow you to fine-tune task execution within Tekton Pipelines. These reusable components can be used to:

- Add extra validation steps.
- Reuse logic across multiple tasks.
For further details on StepActions, refer to the [Tekton documentation](https://tekton.dev/docs/pipelines/stepactions/).

### 🧩 Pipelines

The **Pipelines** directory includes complete Tekton Pipelines composed of Tasks and StepActions. These Pipelines provide end-to-end examples of how to combine reusable components into robust CI/CD workflows. If you're looking to orchestrate multiple tasks into a cohesive flow, Pipelines are a great starting point.

- **Adding a New Pipeline**:
   To add a new pipeline, create a `.yaml` file inside the `pipelines/<your-pipeline-name>/0.1/` directory. Ensure it follows the Tekton [Pipeline specification](https://tekton.dev/docs/pipelines/pipelines/), is well-documented (add `README.md` file), and [well-versioned](#-versioning).

### 🧩 Pipeline Runs

The **PipelineRuns** directory includes complete Tekton PipelineRuns composed of Tasks and StepActions. These PipelineRuns provide end-to-end examples of how to combine reusable components into robust CI/CD workflows with added customization options provided by the [PipelineRun](https://tekton.dev/docs/pipelines/pipelineruns/) definition format. If you're looking to orchestrate multiple tasks into a cohesive flow, PipelineRuns are a great starting point.

- **Adding a New PipelineRun**:
  To add a new pipelineRun, create a `.yaml` file inside the `pipelineruns/<your-pipelinerun-name>/0.1/` directory. Ensure it follows the Tekton [PipelineRun specification](https://tekton.dev/docs/pipelines/pipelineruns/), is well-documented (add `README.md` file), and [well-versioned](#-versioning).

### 🧰 Konflux Integration Tools

The **Konflux Integration Tools** provide utilities specifically designed to facilitate the development and management of Tekton tasks.

- **Applications Folder**: Contains configurations and definitions for the application name within Konflux.
- **Components Folder**: Includes the Konflux component names and artifact tools, assisting with task development by automating repetitive tasks like configuration management, testing, and deployment.

You can find all these resources in the [`konflux`](./konflux) directory.

### 📜 Scripting

The [`scripts`](./scripts/) directory contains reusable scripts that assist with Tekton pipeline tasks or stepactions, including environment setup, notifications, logging, and deployment.

- **📌 Adding a New Script**:
  To add a new script, create a `.sh` file in the appropriate subdirectory (e.g., `pre-pipeline-scripts`, `post-pipeline-scripts`). Ensure the script is well-documented and easy to use, with a clear purpose and example usage.

## 🔢 Versioning

We follow a **versioning strategy** to ensure updates don’t break existing workflows.

### 📌 When to Create a New Version

A **new version** of a task/stepaction should be created **if**:

- ✅ The task’s **interface changes** (e.g., parameters, workspaces, or result names are modified).
- ✅ New functionality is introduced that **isn’t backward compatible**.
- ✅ A critical bug fix **requires an updated implementation**.

Each version should be **clearly labeled** to avoid breaking existing pipelines.

## 🤝 Contributing

We welcome contributions! If you’d like to **add a new task**, **improve existing ones**, or **enhance documentation**, check out our [Contributing Guide](./CONTRIBUTING.md).
