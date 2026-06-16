# AWS Cluster Resource Cleanup Script (`delete-mapt-clusters.sh`)

This script is designed for periodic execution in a CI/CD pipeline to automatically clean up orphaned AWS resources associated with clusters provisioned by the `github.com/redhat-developer/mapt` tool.

It identifies resources that are tagged with **`origin=mapt`** and have been running for **longer than 1 day (86,400 seconds)**, then attempts a comprehensive teardown of the associated VPC infrastructure based on the shared **`projectName`** tag. For orphaned VPCs with no EC2 instance history, the script uses **CloudTrail** `CreateVpc` events to determine VPC age; VPCs with no CloudTrail event are assumed older than the 90-day retention period and deleted.

---

## ⚠️ WARNING: Execution is Destructive ⚠️

This script performs **irreversible delete operations** on AWS infrastructure. **ALWAYS** run in `--dry-run` mode first to verify its targets.

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