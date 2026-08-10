# Slack Webhook Notification Task

Version: 0.1

Send a message to Slack using an incoming webhook

---

## Parameters

| Name | Description | Default | Required |
| --- | --- | --- | --- |
| `message` | Message to be sent | | Yes |
| `secret-name` | Secret with at least one key whose value is a Slack incoming webhook URL | `slack-webhook-notification-secret` | No |
| `key-name` | Key in the secret which contains the webhook URL for Slack | | Yes |
| `user-ids` | List of Slack user IDs to mention (e.g. `U024BE7LH`) | `[]` | No |
| `group-ids` | List of Slack group IDs to mention (e.g. `S0614TZR7`) | `[]` | No |
| `submodules` | List of submodule names to dump into the message. Requires the source workspace | `[]` | No |
| `files` | List of files to dump into the message. Requires the source workspace | `[]` | No |

## Workspaces

| Name | Description | Optional |
| --- | --- | --- |
| `source` | Workspace containing the cloned repository. Required when files or submodules are set | Yes |

## Usage

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: notify-on-failure
spec:
  finally:
    - name: slack-notification
      when:
        - input: $(tasks.status)
          operator: in
          values: ["Failed"]
      taskRef:
        resolver: git
        params:
          - name: url
            value: https://github.com/konflux-ci/tekton-integration-catalog.git
          - name: revision
            value: main
          - name: pathInRepo
            value: tasks/slack-webhook-notification/0.1/slack-webhook-notification.yaml
      params:
        - name: message
          value: "Pipeline $(context.pipelineRun.name) failed"
        - name: key-name
          value: team1
```

### Suitable for upstream communities
