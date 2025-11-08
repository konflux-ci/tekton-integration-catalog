# 🤝 Contributing to Konflux Tekton Integration Catalog

Thank you for your interest in contributing! This project benefits from a collaborative effort, whether you're fixing bugs, adding new Tekton Tasks, or improving documentation. Every contribution helps improve the system and makes testing in Konflux CI more efficient. 🚀

## 🛠 How to Contribute

1. **Fork This Repo**
   - Click the **Fork** button in the top right.
   - Clone your forked repo to your machine:

     ```bash
     git clone https://github.com/your-username/tekton-integration-catalog.git
     ```

2. **Create a Branch**
   - Use a clear and descriptive branch name:

     ```bash
     git checkout -b feature/add-new-task
     ```

3. **Make Your Changes**
   - Add new Tekton Tasks, StepActions, or Pipelines.
   - If updating an existing task, **ensure backward compatibility** or create a new version.
   - Update documentation if needed.
   - Ensure appropriate upstream labels are added.

4. **Test Your Changes**
   - Validate YAML files to check for syntax errors.
   - Run necessary tests to confirm that everything functions as expected.

5. **Commit & Push**
   - Write clear and concise commit messages:

     ```bash
     git add .
     git commit -m "Add a new task for database migration"
     git push origin feature/add-new-task
     ```

6. **Open a Pull Request (PR)**

## 📌 Contribution Guidelines

- Maintain the existing directory structure and naming conventions.
- Ensure YAML files are **properly formatted and validated**.
- Keep commit messages clear and descriptive.
- If adding a new task, **include an example** of its usage.
- Be constructive and open to feedback during the review process.
