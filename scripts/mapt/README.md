# MAPT Cluster Resource Cleanup

These scripts clean up AWS and IBM Cloud resources associated with clusters provisioned by `github.com/redhat-developer/mapt`.

The AWS script, `delete-mapt-clusters.sh`, identifies resources tagged
**`origin=mapt`** that are older than one day, then tears down their associated
VPC infrastructure. It uses CloudTrail to determine the age of VPCs without
EC2 instance history.

---

## ⚠️ WARNING: Execution is Destructive ⚠️

These scripts perform **irreversible delete operations**. Run them in `--dry-run` mode first to verify targets.

### Prerequisites

1.  **AWS CLI:** Installed and configured with credentials that have sufficient permissions for deletion of all target resource types across all regions, plus `cloudtrail:LookupEvents` for VPC age verification.
2.  **`bash`:** The script is written in Bash.
3.  **`jq`:** The command-line JSON processor is required for parsing complex AWS CLI output.
4.  **`date`:** A version of the `date` utility capable of parsing ISO 8601 timestamps (e.g., GNU `date`, common on Linux/macOS).

---

## Usage

The script supports two modes: **Dry-Run (Safety)** and **Execution (Live)**.

### 1. Dry-Run Mode (Recommended)

Run the script with the `--dry-run` or `-d` flag. This will list all resources it **would** delete without making any actual changes.

```bash
./delete-mapt-clusters.sh --dry-run
# OR
./delete-mapt-clusters.sh -d
```

### IBM Cloud VPC cleanup

`delete-mapt-ibmcloud-resources.sh` removes IBM Cloud VPC resources carrying
the `iac:mapt` and `k8s-type:kind` tags. The periodic sweep uses a 24-hour
minimum age, matching the AWS cleanup threshold. It deletes VPC address prefixes
only through matching old, mapt-tagged VPCs, then deletes eligible resource
groups last. Sweep mode skips a group if its tagged VPC is too new or a tagged
instance in the group is too new or still exists after deletion is requested.
If an instance lacks MAPT tags, sweep includes it only when a tagged MAPT
resource identifies its non-default resource group and the instance name
matches that group.

Use `--region REGION` to select the IBM Cloud region; it defaults to `us-south`.

Prerequisites are the IBM Cloud CLI with the `vpc-infrastructure` plugin,
`jq`, and `IBMCLOUD_API_KEY` with permission to list and delete the tagged
resources in the target region.

```bash
./delete-mapt-ibmcloud-resources.sh --sweep --age-hours 24 --dry-run
```

Targeted cleanup takes the mapt project name (for example,
`--project-name kind-abc`). It derives the cluster ID (`abc`) from the
provisioner's `kind-<cluster-id>` project name for tag matching. It does not
apply the sweep age threshold and deletes the matching resource group last.
