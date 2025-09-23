# analyze-test-results stepaction

This StepAction runs "analyze-test-results" command from qe-tools binary against supplied OCI artifact that contains logs and test results.
The command then tries to identify the cause of the failure and provides the result of the analysis in the specified file.
([Link to the code](https://github.com/konflux-ci/qe-tools/blob/main/cmd/root.go)).

## Parameters
|name|description|default value|required|
|---|---|---|---|
|workspace-path|Path to the workspace that is used for storing an output of analysis|/workspace|true|
|analysis-output-file|Analysis output file name|analysis.md|true|
|oci-ref|OCI artifact reference that contains logs and JUnit files to analyse||false|
|junit-report-name|JUnit file report name for analysis|junit.xml|true|
|e2e-log-name|The name of the log from running tests|e2e-tests.log|true|
|cluster-provision-log-name|The name of the log from provisioning a testing cluster|cluster-provision.log|true|

### Suitable for upstream communities