# Trigger Konflux Integration tests via CronJob

The [`periodic-integration-test-yaml`](./periodic-integration-tests.yaml) is a sample Cronjob that can be executed in Konflux to Trigger an Integration test periodically.
It runs every 2 days, fetching the latest snapshot related to push events and labeling it to initiate the test scenario

## Required Roles & Permissions

The script will require to have in your cluster an service account with some specific RBAC rules:

### `role.yaml`

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: periodic-jobs-role
  namespace: rhtap-build-tenant
rules:
  - verbs:
      - get
      - watch
      - list
      - update
      - patch
    apiGroups:
      - appstudio.redhat.com
    resources:
      - snapshots
```

### `roleBinding.yaml`

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: periodic-jobs-role-rb
  namespace: rhtap-build-tenant
subjects:
  - kind: ServiceAccount
    name: appstudio-pipeline # Replace the SA name in case you want to use another name
    namespace: rhtap-build-tenant
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: periodic-jobs-role
```

## Workflow

1. The job fetches the latest snapshot related to push events from the `tenant` namespace you define.
2. If a valid snapshot is found, it is labeled to trigger test scenario desired.
3. If no valid snapshot is found, the job exits with an error message.
