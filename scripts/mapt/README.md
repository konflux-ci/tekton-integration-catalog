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

#### IBM Cloud cleanup

- **`bash`:** Required to run the cleanup script.
- **IBM Cloud CLI:** Install Resource Manager support and the `vpc-infrastructure` plugin.
- **`jq` and GNU `date`:** Required for parsing IBM Cloud output and resource timestamps (`date -d`).
- **`IBMCLOUD_API_KEY`:** Required, with permission to search, list, and delete MAPT resources in the target region.

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

`delete-mapt-ibmcloud-resources.sh` identifies non-default per-instance
resource groups from MAPT-tagged resources, then inventories the supported VPC
resources in those groups, including resources without MAPT tags. The periodic
sweep uses a 24-hour minimum age, matching the AWS cleanup threshold. If any
inventoried VPC resource in a group is too new, the sweep defers that whole
group. A MAPT-owned instance with `failed` status bypasses the age check for its
group. Deletion proceeds in dependency order: instances, subnets, public
gateways, floating IPs, security groups and keys, address prefixes, VPCs, then
resource groups. In sweep mode, the script polls instance deletion every 30
seconds for up to two minutes, and waits for subnet and gateway deletion
requests to finish before removing dependent resources. It leaves each VPC's
default security group for VPC deletion. The initial plan summarizes eligible
resources before deletion; the execution summary reports accepted and failed
delete requests and groups protected during the run.

Use `--region REGION` to select the IBM Cloud region; it defaults to `us-south`.

Sweep mode requires `--age-hours HOURS`; the script exits if it is omitted.

```bash
./delete-mapt-ibmcloud-resources.sh --sweep --age-hours 24 --dry-run
```

Targeted cleanup takes the mapt project name (for example,
`--project-name kind-abc`). It derives the cluster ID (`abc`) from the
provisioner's `kind-<cluster-id>` project name for tag matching. It does not
apply the sweep age threshold and deletes the matching resource group last.
