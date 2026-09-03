# Stranded IPI Cluster Cleanup (`delete-ipi-clusters.sh`)

Sweeper for stranded AWS IPI clusters leaked by the `konflux-ci-ipi` Prow workflow. OpenShift CI names each job's work namespace `ci-op-<id>`, and `openshift-install` (IPI) reuses that namespace as the cluster infra-id, tagging every AWS resource it creates with `kubernetes.io/cluster/<infra-id>`.

This script discovers all `kubernetes.io/cluster/ci-op-*` tag keys across every AWS region, checks each cluster's age, and tears down the full dependent resource tree (EC2, load balancers, NAT gateways, ENIs, EIPs, EBS volumes, VPC endpoints, peering, gateways, route tables, NACLs, subnets, security groups, and finally the VPC) for anything older than the age threshold.

EBS volumes are cleaned up independently of the VPC/EC2 tree: dynamically-provisioned PVC volumes (tagged by the in-cluster EBS CSI driver) and node root volumes that outlived their instance's termination can persist even after the rest of a cluster's infrastructure is fully gone.

It does **not** depend on the originating Prow build/GCS artifacts still being available — build logs and namespaces are pruned well before a cluster has been leaking for weeks, so AWS tags are the only reliable signal left for older leaks.

---

## ⚠️ WARNING: Execution is Destructive ⚠️

This script performs **irreversible delete operations** on AWS infrastructure. **ALWAYS** run in `--dry-run` mode first to verify its targets.

### Prerequisites

1. **AWS CLI**: configured with credentials that can describe/delete EC2, ELB/ELBv2, and VPC resources across all regions, plus `cloudtrail:LookupEvents` for age fallback on VPCs with no surviving instances.
2. **`bash`**
3. **`jq`**
4. **`date`**: GNU `date` (or a `date` capable of parsing ISO 8601 timestamps via `-d`). **macOS's built-in `date` does not support this** — age parsing silently fails and every cluster is treated as 0 seconds old (i.e. always skipped, never cleaned up). Run this on Linux, or with `gdate` (`brew install coreutils`) aliased to `date` on macOS.

---

## Usage

### 1. Dry-Run Mode (Recommended)

```bash
./delete-ipi-clusters.sh --dry-run
# OR
./delete-ipi-clusters.sh -d
```

Lists every stranded `ci-op-*` cluster and its dependent resources without deleting anything.

### 2. Destructive Mode

```bash
./delete-ipi-clusters.sh
```

### Configuration

| Env var | Default | Purpose |
|---------|---------|---------|
| `AGE_LIMIT_SECONDS` | `86400` (24h) | Minimum cluster age before it's eligible for cleanup. Keep this comfortably above the longest-running `konflux-ci-ipi` periodic so in-flight nightlies are never targeted. |

## How age is determined

1. Newest `LaunchTime` among the cluster's EC2 instances (bootstrap/master/worker), if any are still present.
2. Otherwise, the VPC's `CreateVpc` CloudTrail event.
3. Otherwise (no instances, no CloudTrail event within the 90-day retention window), the cluster is treated as older than the threshold and cleaned up.

## Relationship to other cleanup periodics

Mirrors the existing pattern used for other Konflux fleets in `pco-aws-konflux-test-ci`:

| Fleet | Script | Periodic |
|-------|--------|----------|
| MAPT / kind | `scripts/mapt/delete-mapt-clusters.sh` | `periodic-ci-konflux-ci-e2e-tests-main-mapt-clusters-resources-cleanup` |
| ROSA HCP (`kx-*`) | `scripts/rosa/delete-rosa-clusters.sh` | `periodic-ci-konflux-ci-e2e-tests-main-rosa-old-clusters-cleanup` |
| IPI (`ci-op-*`) | `scripts/ipi/delete-ipi-clusters.sh` | `periodic-ci-konflux-ci-e2e-tests-main-ipi-clusters-cleanup` |
