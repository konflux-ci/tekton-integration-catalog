# Test Metadata Version 0.3

The `test-metadata` task is designed to extract and log metadata from a JSON snapshot or PipelineRun object during a Tekton pipeline execution. This task helps in identifying and documenting critical information such as the event type (push or pull request), Git URL, Git revision, container image, GitHub organization, repository, pull request number, and pull request author.

## Parameters

The task accepts the following parameters:

- **SNAPSHOT**: A JSON string representing the Snapshot under test. This JSON contains detailed information about the components and their sources.


### Example of SNAPSHOT

```json
{
  "components": [
    {
      "name": "component-1",
      "source": {
        "git": {
          "url": "https://github.com/example/repo",
          "revision": "commit-sha"
        }
      },
      "containerImage": "quay.io/example/component-1:latest"
    }
  ]
}
```

## Results

The task produces the following results, combining both individual outputs (from 0.1) and consolidated approach (from 0.2):

### Individual Results (0.1 approach)

1. **test-event-type**: Indicates if the job is triggered by a Pull Request or a Push event.
    - **Description**: This result helps to understand the context of the event that triggered the job. Knowing whether the job was triggered by a push (direct commit to the repository) or a pull request (a proposed change from a fork or a branch) can influence how the results are interpreted and acted upon.

2. **pull-request-number**: The pull request number if the job is triggered by a pull request event.
    - **Description**: This result provides the specific pull request number, which is crucial for tracking changes and associating test results with the correct pull request in a CI/CD system.

3. **git-url**: The Git URL from which the test pipeline is originating. This can be from a fork or the original repository.
    - **Description**: This result identifies the source repository URL, helping to trace back the origin of the code being tested. It is useful for verifying the source of the changes and ensuring they come from a trusted repository.

4. **git-revision**: The Git revision (commit SHA) from which the test pipeline is originating.
    - **Description**: This result specifies the exact commit SHA being tested, which is vital for reproducibility and debugging. It allows developers to know the precise state of the codebase at the time of testing.

5. **container-image**: The container image built from the specified Git revision.
    - **Description**: This result provides the reference to the container image that was built during the pipeline execution. It helps in verifying which image was produced from the specific code revision and is essential for deployment and further testing.

6. **git-org**: The GitHub organization from which the test is originating.
    - **Description**: This result indicates the organization or user namespace on GitHub where the repository resides. It helps in organizing and identifying the source of the code.

7. **git-repo**: The repository from which the test is originating.
    - **Description**: This result provides the name of the repository containing the code under test. It is useful for documentation, tracking, and context about the source of the changes.

8. **pull-request-author**: The GitHub author of the pull request event.
    - **Description**: This result identifies the author of the pull request, providing context about who made the changes.

9. **source-repo-url**: Will show the source from where a Pull Request was opened. Can be from a fork or upstream.
    - **Description**: This result identifies the source repository URL for pull requests, helping to trace back the origin of the changes.

10. **source-repo-branch**: Get the branch from the fork or upstream repo where the pipeline is executed.
    - **Description**: This result identifies the source repository branch for pull requests.

11. **target-repo-branch**: The target branch value from the Pull Request or the current branch value in case of push event.
    - **Description**: This result identifies the target repository branch.

12. **component-name**: The name of the component that is being executed from Konflux.
    - **Description**: This result provides the name of the Konflux component being tested.

### Consolidated Results (0.2 approach)

13. **job-spec**: The Konflux CI job spec metadata generated.
    - **Description**: This result contains a JSON object with comprehensive details about the job specification, including container image, component name, git information, and event type. It encapsulates all the relevant metadata for the CI job in a structured format, aiding in documentation and analysis.

    The job-spec contains the following structure:
    ```json
    {
        "container_image": "quay.io/example/component:latest",
        "konflux_component": "component-name",
        "snapshot": { /* full snapshot JSON */ },
        "git": {
            "pull_request_number": "123",
            "pull_request_author": "username",
            "org": "organization",
            "repo": "repository",
            "commit_sha": "abc123",
            "event_type": "pull_request",
            "source_repo_url": "https://github.com/fork/repo",
            "source_repo_org": "fork",
            "source_repo_branch": "feature-branch",
            "target_repo_branch": "main",
            "url": "https://github.com/org/repo",
            "revision": "abc123"
        }
    }
    ```

### Prefetch Results (0.2 approach)

14. **prefetch-artifact**: The OCI artifact that contains the prefetch dependencies generated during the build phase.
    - **Description**: This result contains the digest of the OCI artifact that was generated during the build phase's prefetch-dependencies task. The prefetch functionality is always enabled in this version. If no artifact is found, this will be an empty string.

15. **source-artifact**: The source artifact extracted from the container image attestation.
    - **Description**: This result contains the source artifact digest extracted from the container image attestation during the prefetch-dependencies task. If no artifact is found, this will be an empty string.

16. **container-repo**: The container repository extracted from the container image.
    - **Description**: This result contains the repository part of the container image (e.g., quay.io/org/repo). It is extracted by parsing the container image URL and removing the tag and SHA256 digest.

17. **container-tag**: The container tag extracted from the container image.
    - **Description**: This result contains the tag part of the container image. If no tag is present in the original image, it defaults based on the event type: "on-pr-{revision}" for pull requests or "{revision}" for push events.

## Key Features

### Combined Approach
- **Individual Results**: Easy access to specific metadata values without parsing JSON
- **Consolidated Job-Spec**: Complete metadata in a structured JSON format
- **Backward Compatibility**: Supports both 0.1 and 0.2 usage patterns
- **Enhanced Artifacts**: Both prefetch and source artifacts available

### Enhanced Git Information
- **Source Repository Details**: Full information about source repositories for pull requests
- **Organization Extraction**: Automatic extraction of source repository organization
- **Complete Git Context**: All git-related information in both individual and consolidated formats

### Prefetch Functionality
- **Always Enabled**: Prefetch functionality is always active
- **OCI Artifact Integration**: Downloads and processes cosign attestations
- **Cachi2 Integration**: Extracts Cachi2 artifacts from build phase
- **Dual Artifacts**: Both CACHI2_ARTIFACT and SOURCE_ARTIFACT are extracted
- **Graceful Handling**: Empty artifacts return empty strings with appropriate warnings
- **Status Logging**: Provides concise status output showing artifact availability and values

### Container Image Parsing
- **Repository Extraction**: Automatically extracts repository from container image URL
- **Tag Extraction**: Extracts tag from container image with smart defaults
- **Event-Based Defaults**: Uses git revision for missing tags with event-specific formatting

Example output:
```
[INFO] Cachi2 artifact: found (sha256:abc123...), Source artifact: not found
[INFO] No tag found, defaulting to: on-pr-abc123def
```

## Usage

To effectively utilize the `test-metadata` task in a Tekton Pipeline, you can follow the example provided below. This example demonstrates how to define a Tekton pipeline that includes the `test-metadata` task, ensuring that all necessary parameters are specified correctly.

### Basic Usage (0.1 style)

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: test-metadata-pipeline
spec:
  tasks:
    - name: extract-build-metadata
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/test-metadata/0.3/test-metadata.yaml
      params:
        - name: SNAPSHOT
          value: "<your-snapshot-json>"
```



## Migration from Previous Versions

### From 0.1 to 0.3
- All individual results are preserved
- Additional `job-spec` result provides consolidated access
- New `prefetch-artifact` result always available
- Enhanced git information with `source_repo_org`
- New container parsing results (`container-repo`, `container-tag`)
- Simplified parameters (only SNAPSHOT required)

### From 0.2 to 0.3
- All consolidated functionality preserved
- Individual results now available for easier access
- New container parsing results (`container-repo`, `container-tag`)
- Enhanced logging and debugging information
- Simplified parameters (only SNAPSHOT required)

## Version History

- **0.1**: Individual result outputs for specific metadata values
- **0.2**: Consolidated job-spec approach with prefetch functionality
- **0.3**: Combined approach with both individual and consolidated results, plus enhanced git information 

### Suitable for upstream communities