# Pull Request Commenter Task

**Version:** 0.1

Pull Request Commenter Task posts a comment on a GitHub pull request summarizing the status of a pipeline execution. It deletes any previous comments made by the pipeline and posts a new one unless the pipeline was successful, in which case it skips commenting. The comment includes a summary of the pipeline run status, links to build logs, and instructions for re-running tests or retrieving artifacts using ORAS.

## Parameters

| Name | Description | Default | Required |
|------|------------|---------|----------|
| test-name | The name of the pipeline run being executed. | | ✅ |
| oci-container | The ORAS container registry URI where test artifacts are stored. | | ✅ |
| pull-request-author | The GitHub username of the pull request author. | | ✅ |
| pull-request-number | The GitHub pull request number to comment on. | | ✅ |
| git-repo | The GitHub repository name where the pull request is opened. | | ✅ |
| git-org | The GitHub organization or user owning the repository. | | ✅ |
| pipeline-aggregate-status | The overall status of the pipeline run (`Succeeded`, `Failed`, `Completed`, `None`). | None | ✅ |
| git-revision | The Git commit revision associated with the pull request. | | ✅ |
| junit-report-name | The name of the JUnit file for test result analysis. | junit.xml | ✅ |
| e2e-log-name | The name of the log file from end-to-end tests. | e2e-tests.log | ✅ |
| cluster-provision-log-name | The name of the log file from cluster provisioning. | cluster-provision.log | ✅ |
| enable-test-results-analysis | Set to `true` to enable experimental test results analysis. | false | ❌ |
| artifact-browser-url | Provides the URL to the artifact browser deployment. | "" | ❌ |

## Behavior

- **Deletes previous comments** made by the pipeline.
- **Skips commenting if the pipeline succeeded**.
- **Posts a new comment** with:
  - Pipeline run status.
  - Links to build logs and test logs.
  - Instructions to rerun tests.
  - Steps to retrieve artifacts using ORAS.
  - Optional test results analysis if enabled.
  - Optional OCI artifact browser link to related OCI artifact.

## Usage

This task is useful in Konflux CI workflows where feedback on pull request testing is essential. It helps developers quickly understand test outcomes and rerun failing tests if necessary.

## Results

This task does not produce any output results.
