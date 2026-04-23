# "report-periodic-tests pipeline"
The report-periodic-tests pipeline is run periodically to gather the results of periodic test runs and email them to stakeholders. It queries PipelineRuns from Konflux's KubeArchive, processes the results, and generates an HTML email report summarizing test statuses.

## Pipeline Flow
The pipeline consists of the following task:

1. **Extract Tests Info and Send Email (`extract-tests-info-and-send-email`)**
   - Queries KubeArchive for PipelineRuns matching the specified test names and scheduled times
   - Filters PipelineRuns to find those that ran at approximately the scheduled time (±2 minutes)
   - Gathers status information (SUCCEEDED, FAILED, RUNNING, UNKNOWN) for each test run
   - Generates an HTML email report with:
     * A table for each test showing pipeline runs, their status, creation time, and log links
     * Color-coded status indicators
     * Links to Konflux UI for detailed logs
   - Sends the report via SMTP to the configured stakeholder email addresses

## Parameters
|name|description|default value|required|
|---|---|---|---|
|namespace| Namespace where the pipelineRuns are run| ""| false|
|application| Name of application where the tests run| ""| false|
|tests-names| List of test names to check (e.g., e2e-periodic-tests)| []| false|
|tests-times| List of scheduled run times for the tests (corresponding to tests-names)| []| false|
|stakeholder-emails| Comma-separated list of email addresses to send the report to| ""| false|
|subject| Subject of the email| "Weekly konflux test reporting"| false|
|SMTP_SERVER| SMTP server to be used for sending the email| "smtp.gmail.com:587"| false|
|KONFLUX_CLUSTER| Konflux cluster API server URL| "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"| false|

## Pipeline Usage Guide

### Create an IntegrationTestScenario

Create an `IntegrationTestScenario` YAML file using the template below.

Update the following fields with the appropriate details for your Konflux tenant:

- `metadata.namespace`
- `metadata.name`
- `spec.application` (if applicable)
- `spec.params[0].value`  -> namespace
- `spec.params[1].value`  -> application
- `spec.params[2].value`  -> tests-names
- `spec.params[3].value`  -> tests-times
- `spec.params[4].value`  -> stakeholder-emails
- `spec.params[5].value`  -> subject (Optional)
- `spec.params[6].value`  -> SMTP_SERVER (Optional)
- `spec.params[7].value`  -> KONFLUX_CLUSTER

```yaml
apiVersion: appstudio.redhat.com/v1beta2
kind: IntegrationTestScenario
metadata:
  name: weekly-test-reporting
  namespace: konflux-samples-tenant
spec:
  params:
    - name: namespace
      value: "konflux-samples-tenant"
    - name: application
      value: "cnv-fbc-v4-17"
    - name: tests-names
      value:
        - "e2e-tests-periodic"
        - "e2e-tests-periodic-later"
    - name: tests-times
      value:
        - "0:00 AM"
        - "3:00 AM"
    - name: stakeholder-emails
      value: "team@example"
    - name: subject
      value: "Weekly konflux test reporting"
    - name: SMTP_SERVER
      value: "smtp.gmail.com:587"
    - name: KONFLUX_CLUSTER
      value: "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"
  resolverRef:
    resourceKind: pipelinerun
    params:
      - name: url
        value: https://github.com/konflux-ci/tekton-integration-catalog.git
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelineruns/report-periodic-tests/report-periodic-tests-run.yaml
    resolver: git
```

### Create a CronJob in your cluster

In order to periodically trigger this pipeline (for example weekly), we need to create a CronJob. You can use the one at the bottom of the [periodic integration tests](https://konflux-ci.dev/docs/testing/integration/periodic-integration-tests/) pointing to the integration test associated with this pipeline.

### Parameters Descriptions

#### namespace

Namespace where the PipelineRuns are executed. The pipeline will query this namespace in KubeArchive to find test runs.

#### application

Name of the application where the tests run. This is used to construct links to the Konflux UI.

#### tests-names

List of test name prefixes to check. The pipeline will search for PipelineRuns whose names start with these prefixes.

Example:
```yaml
tests-names:
  - "e2e-tests-periodic"
  - "e2e-tests-periodic-later"
```

#### tests-times

List of scheduled run times corresponding to each test in `tests-names`. The pipeline uses these times to filter PipelineRuns that ran at approximately the scheduled time (±2 minutes).

Times should be in 12-hour format (e.g., "3:00 AM", "11:30 PM").

Example:
```yaml
tests-times:
  - "0:00 AM"
  - "3:00 AM"
```

**NOTE**: The arrays `tests-names` and `tests-times` must have the same length, with each index corresponding to a specific test.

#### stakeholder-emails

Comma-separated list of email addresses to send the report to.

Example:
```yaml
stakeholder-emails: "team@example.com,manager@example.com"
```

#### subject (Optional)

Subject line for the email. The current date will be appended automatically (e.g., "Weekly konflux test reporting - 2026-04-07").

Defaults to "Weekly konflux test reporting".

#### SMTP_SERVER (Optional)

SMTP server to use for sending the email, in the format `host:port`.

Defaults to "smtp.gmail.com:587".

**NOTE**: The pipeline requires a Kubernetes Secret named `gwsa-email-account` with the following keys:
- `username`: SMTP authentication username
- `password`: SMTP authentication password

Example:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gwsa-email-account
  namespace: your-namespace
type: Opaque
data:
  username: <BASE64_ENCODED_USERNAME>
  password: <BASE64_ENCODED_PASSWORD>
```

#### KONFLUX_CLUSTER

Konflux cluster API server URL. You can copy this server url from the oc login command. This parameter is used to authenticate to the cluster and also to derive the following URLs automatically:
- **Konflux UI URL**: Used to construct links to PipelineRun logs in the email report
- **KubeArchive Host**: Used to query archived PipelineRuns

The cluster domain is extracted from this URL and used to build the derived URLs following these patterns:
- Konflux UI: `https://konflux-ui.apps.<CLUSTER_DOMAIN>`
- KubeArchive: `https://kubearchive-api-server-product-kubearchive.apps.<CLUSTER_DOMAIN>`

Example:
```yaml
KONFLUX_CLUSTER: "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443"
```

This will automatically derive:
- Konflux UI: `https://konflux-ui.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com`
- KubeArchive: `https://kubearchive-api-server-product-kubearchive.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com`

Defaults to "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443".

### Required Secrets

This pipeline requires the following secrets to be present in the namespace:

1. **report-token**: Contains the Konflux API token for a service account with the following permissions:
   - PipelineRuns: `get`, `list`, `watch`, `create`
   - TaskRuns: `get`, `list`, `watch`

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: report-token
   type: Opaque
   data:
     report-token: <BASE64_ENCODED_TOKEN>
   ```

2. **gwsa-email-account**: Contains SMTP credentials
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: gwsa-email-account
   type: Opaque
   data:
     username: <BASE64_ENCODED_USERNAME>
     password: <BASE64_ENCODED_PASSWORD>
   ```

### What Happens Next

When the pipeline runs (typically on a scheduled basis):

1. It connects to the Konflux cluster using the provided token
2. Queries KubeArchive for PipelineRuns matching the configured test names
3. Filters runs based on the scheduled times (looking for runs within ±2 minutes of the scheduled time)
4. Gathers status information for the last 7 days of test runs
5. Generates an HTML email report with a table for each test
6. Sends the report to all stakeholder email addresses

**NOTE**: The pipeline queries the last 7 days of test runs, checking each day at 6:00 AM UTC.

### Email Report Format

The email report includes:

- **Subject**: Configured subject with appended date (e.g., "Weekly konflux test reporting - 2026-04-07")
- **From**: noreply@redhat.com
- **Content**: HTML-formatted report with:
  - A section for each configured test
  - Tables showing PipelineRun name, status (color-coded), creation time, and log links
  - Status indicators: green (SUCCEEDED), red (FAILED), blue (RUNNING), gray (UNKNOWN)
  - Clickable links to view detailed logs in the Konflux UI
