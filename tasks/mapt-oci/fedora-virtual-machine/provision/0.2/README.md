# fedora-vm-provision (0.2)

Creates a Fedora virtual machine on AWS using the [Mapt](https://github.com/redhat-developer/mapt) CLI.

Intended for CI/CD workflows that need a throwaway Fedora host (spot instances, custom
CPU/memory/arch, GPU, nested virtualization, auto-destroy timeout).

## What's new in 0.2

- The generated host access Secret gains a `host-public-key` entry: the SSH host public key(s)
  of the provisioned machine in `known_hosts` format, so consuming tasks can verify the host
  instead of running ssh with `StrictHostKeyChecking=no`.
- New param `host-key-scan-timeout` controlling how long the task waits for that key.
- The `mapt` invocation is built as a bash array and executed directly instead of being
  concatenated into a string and run through `eval`. Param values now reach the step through
  the environment, so a value containing shell metacharacters is passed to `mapt` as a literal
  argument rather than executed. As part of this the `timeout` default changed from `''` to
  `""`; both are still treated as "no auto-destroy".
- The host access Secret is created through `oc create secret generic` instead of a YAML
  heredoc, and the secret name and owner reference fields are validated before use, so no
  param value can inject YAML into the generated object. An unset `ownerName` / `ownerUid`
  now fails with a clear error instead of being rejected by the API server.

Everything else is identical to 0.1.

## Parameters

| Name | Default | Description |
|------|---------|-------------|
| `secret-aws-credentials` | — | K8s secret with `access-key`, `secret-key`, `region`, `bucket` |
| `id` | — | Identifier for the provisioned environment |
| `host-access-secret-name` | `""` | If set, a Secret with `host`, `username`, `id_rsa`, `host-public-key` is created with this name. Must be a DNS-1123 subdomain |
| `ownerKind` / `ownerName` / `ownerUid` | `PipelineRun` / `""` / `""` | Owner reference for the generated Secret. Required when `host-access-secret-name` is set; `ownerKind` must be `PipelineRun` or `TaskRun` |
| `arch` | `x86_64` | `x86_64` or `arm64` |
| `cpus` | `4` | Number of CPUs |
| `memory` | `16` | RAM in GiB |
| `compute-families` | `""` | Comma-separated allowlist of compute family prefixes |
| `compute-sizes` | `""` | Explicit instance sizes; takes precedence over cpus/memory/gpus |
| `gpu-manufacturer` | `""` | e.g. `NVIDIA` |
| `gpus` | `0` | Number of GPUs |
| `nested-virt` | `false` | Require nested virtualization support |
| `spot` | `true` | Use spot instances |
| `spot-eviction-tolerance` | `lowest` | `lowest`, `low`, `medium`, `high`, `highest` |
| `spot-excluded-regions` | `""` | Zone IDs to exclude |
| `spot-increase-rate` | `20` | Percentage added on top of the calculated spot price |
| `version` | `42` | Fedora version |
| `tags` | `""` | Tags for the created cloud resources |
| `debug` | `false` | Verbose output plus partially masked credentials |
| `host-key-scan-timeout` | `120` | Seconds to wait for the SSH host key; `0` skips the scan. Must be a nonnegative decimal integer of at most 9 digits, otherwise the task fails |
| `timeout` | `""` | Auto-destroy timeout; empty means no auto-destroy |

## Results

| Name | Description |
|------|-------------|
| `host-access-secret` | Name of the created Secret, empty when `host-access-secret-name` is not set |

## Host access Secret

Created only when `host-access-secret-name` is set, and owned by the resource given via
`ownerKind` / `ownerName` / `ownerUid` so it is garbage collected with it.

The Secret is built with `oc create secret generic` rather than from a YAML template, so
the provisioner output is never parsed as YAML. The owner reference is merged client-side
and the whole object is created in one call, so the Secret never exists unowned. The task
fails up front if the secret name or any of the owner fields is not a well-formed
Kubernetes value.

| Key | Content |
|-----|---------|
| `host` | Address of the machine |
| `username` | SSH user |
| `id_rsa` | SSH private key |
| `host-public-key` | SSH host public key(s) in `known_hosts` format |

## Usage

```yaml
tasks:
  - name: provision-vm
    taskRef:
      name: fedora-vm-provision
    params:
      - name: secret-aws-credentials
        value: aws-credentials
      - name: id
        value: "$(context.pipelineRun.uid)"
      - name: host-access-secret-name
        value: "vm-access-$(context.pipelineRun.uid)"
      - name: ownerKind
        value: PipelineRun
      - name: ownerName
        value: "$(context.pipelineRun.name)"
      - name: ownerUid
        value: "$(context.pipelineRun.uid)"

  - name: run-tests
    runAfter: [provision-vm]
    params:
      - name: host-access-secret
        value: "$(tasks.provision-vm.results.host-access-secret)"
    taskSpec: ...
```

Mount the Secret in the consuming task and use the host key:

```yaml
volumes:
  - name: host-access
    secret:
      secretName: $(params.host-access-secret)
steps:
  - name: run-on-vm
    image: quay.io/konflux-qe-incubator/konflux-qe-tools:latest
    volumeMounts:
      - name: host-access
        mountPath: /opt/host-access
    script: |
      #!/bin/bash
      set -euo pipefail

      mkdir -p ~/.ssh
      if [[ -s /opt/host-access/host-public-key ]]; then
        cat /opt/host-access/host-public-key >> ~/.ssh/known_hosts
        SSH_OPTS="-o StrictHostKeyChecking=yes"
      else
        echo "[WARNING] No host key published by the provision task"
        SSH_OPTS="-o StrictHostKeyChecking=accept-new"
      fi

      install -m 0600 /opt/host-access/id_rsa ~/.ssh/id_rsa
      # shellcheck disable=SC2086
      ssh ${SSH_OPTS} -i ~/.ssh/id_rsa \
        "$(cat /opt/host-access/username)@$(cat /opt/host-access/host)" uname -a
```

## Notes

- The host key scan runs after provisioning in a separate step using
  `quay.io/konflux-qe-incubator/konflux-qe-tools:latest` (the mapt image has no ssh client).
  It retries every 10s until `host-key-scan-timeout` elapses, and exits immediately without
  scanning when `host-access-secret-name` is empty or `host-key-scan-timeout` is `0`.
  The per-attempt `ssh-keyscan` timeout and the retry interval are both clamped to the time
  left, so the step gives up at `host-key-scan-timeout` rather than overshooting it.
- A failed scan does **not** fail the task — the VM is already provisioned, so the task logs a
  warning and the Secret's `host-public-key` entry is empty. Consumers must handle that.
- Pair this task with `tasks/mapt-oci/fedora-virtual-machine/deprovision` in a `finally` block
  to release the machine.
