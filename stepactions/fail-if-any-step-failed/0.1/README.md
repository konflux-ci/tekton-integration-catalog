# fail-if-any-step-failed stepaction

This StepAction searches for exit codes (`/tekton/steps/<step-name>/exitCode`) in each step within the Task and fails if it detects that any `exitCode != "0"`

It can be used in a scenario, when we don't want to fail the Task immediately in case of an error. In that case the error can be ignored using `onError: continue`
field and then the Task failure is deferred to the end of the Task (using `fail-if-any-step-failed` stepaction).

Such an example can be a Task used for running tests:


```yaml
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: test
spec:
  volumes:
    - name: my-secrets-volume
      secret:
        secretName: my-secrets
  steps:
    - name: e2e-test
      image: myimage
      workingDir: /workspace/e2e-tests
      # In case the test fails, we don't want to fail the TaskRun immediately,
      # because we want to proceed with archiving the artifacts in a following step.
      onError: continue
      env:
        - name: ARTIFACT_DIR
          value: /workspace/artifact-dir

      script: |
        #!/bin/bash

        ./run-tests | tee ${ARTIFACT_DIR}/e2e-tests.log
    # Archive artifacts using this stepaction.
    - name: secure-push-oci
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/secure-push-oci/0.1/secure-push-oci.yaml
      params:
        - name: workdir-path
          value: /workspace/artifact-dir
        - name: oci-ref
          value: quay.io/myorg/myrepo:container-tag
        - name: credentials-volume-name
          value: my-secrets-volume
    # Now's the time to check whether some of the steps in this Task didn't fail.
    # If it did, this stepaction will detect it and exit the step with the same non-zero exit code.
    - name: fail-if-any-step-failed
      ref:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: stepactions/fail-if-any-step-failed/0.1/fail-if-any-step-failed.yaml
```

### Suitable for upstream communities