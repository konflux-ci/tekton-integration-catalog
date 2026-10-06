#!/usr/bin/env bash
# delete-mapt-ibmcloud-resources.sh — Discover and destroy mapt-created IBM Cloud VPC
# resources by tag.
#
# The periodic orphan sweep uses the same 24-hour age limit as the AWS cleanup.
#
# Modes:
#   Targeted:  --project-name kind-ID
#   Bulk:      --sweep --age-hours N
#
# Options:
#   --dry-run          List resources without deleting.
#   --region REGION    IBM Cloud region (default: us-south).
#
# Environment:
#   IBMCLOUD_API_KEY  (required)
#
# Exit codes:
#   0  success (or dry-run completed)
#   1  missing dependency / bad args
#   2  cleanup failure

set -euo pipefail

# --- defaults ---
REGION="us-south"
PROJECT_NAME=""
SWEEP=false
AGE_HOURS=""
DRY_RUN=false

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --region)       REGION="$2";       shift 2 ;;
    --sweep)        SWEEP=true;        shift   ;;
    --age-hours)    AGE_HOURS="$2";    shift 2 ;;
    --dry-run)      DRY_RUN=true;      shift   ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate mutually exclusive modes
if [[ -n "$PROJECT_NAME" && "$SWEEP" == "true" ]]; then
  echo "ERROR: --project-name and --sweep are mutually exclusive" >&2
  exit 1
fi

CLUSTER_ID=""
if [[ -n "$PROJECT_NAME" ]]; then
  if [[ "$PROJECT_NAME" != kind-* || "$PROJECT_NAME" == kind- ]]; then
    echo "ERROR: targeted project name must be kind-<cluster-id>" >&2
    exit 1
  fi
  # The provisioner names the project kind-${PARAM_ID} and tags resources
  # with cluster-name=${PARAM_ID}.
  CLUSTER_ID="${PROJECT_NAME#kind-}"
fi

if [[ -z "$PROJECT_NAME" && "$SWEEP" == "false" ]]; then
  echo "ERROR: either --project-name NAME or --sweep --age-hours N is required" >&2
  exit 1
fi

if [[ "$SWEEP" == "true" && -z "$AGE_HOURS" ]]; then
  echo "ERROR: --sweep requires --age-hours" >&2
  exit 1
fi

if [[ "$SWEEP" == "true" && ! "$AGE_HOURS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --age-hours must be a positive integer" >&2
  exit 1
fi

# --- preflight checks ---
if [[ -z "${IBMCLOUD_API_KEY:-}" ]]; then
  echo "ERROR: IBMCLOUD_API_KEY environment variable is not set" >&2
  exit 1
fi

for cmd in ibmcloud jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is required but not found in PATH" >&2
    exit 1
  fi
done

# --- authenticate ---
echo "Authenticating with IBM Cloud..."
ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$REGION" -q 2>&1

if ! ibmcloud resource groups --output json >/dev/null 2>&1; then
  echo "ERROR: IBM Cloud Resource Manager commands are unavailable" >&2
  echo "       Install the IBM Cloud CLI with Resource Manager support." >&2
  exit 1
fi

# Ensure VPC infrastructure plugin is available
ibmcloud is --help >/dev/null 2>&1 || {
  echo "ERROR: ibmcloud VPC infrastructure plugin (is) not available" >&2
  exit 1
}

# --- helper: age check ---
is_older_than_hours() {
  local created_at="$1"
  local max_hours="$2"
  local created_epoch max_age_epoch now_epoch

  # Parse ISO 8601 timestamp to epoch
  created_epoch=$(date -d "$created_at" +%s 2>/dev/null) || return 1
  now_epoch=$(date +%s)
  max_age_epoch=$(( now_epoch - (max_hours * 3600) ))

  [[ $created_epoch -lt $max_age_epoch ]]
}

# --- helper: delete with dry-run guard ---
guarded_delete() {
  local resource_type="$1"
  local resource_id="$2"
  local resource_name="${3:-$resource_id}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY-RUN] would delete $resource_type: $resource_name ($resource_id)"
    return 0
  fi

  echo "  Deleting $resource_type: $resource_name ($resource_id)..."
  case "$resource_type" in
    instance)
      ibmcloud is instance-delete "$resource_id" --force -q 2>&1
      ;;
    floating-ip)
      ibmcloud is floating-ip-release "$resource_id" --force -q 2>&1
      ;;
    subnet)
      ibmcloud is subnet-delete "$resource_id" --force -q 2>&1
      ;;
    security-group)
      ibmcloud is security-group-delete "$resource_id" --force -q 2>&1
      ;;
    key)
      ibmcloud is key-delete "$resource_id" --force -q 2>&1
      ;;
    vpc)
      ibmcloud is vpc-delete "$resource_id" --force -q 2>&1
      ;;
    public-gateway)
      ibmcloud is public-gateway-delete "$resource_id" --force -q 2>&1
      ;;
    vpc-address-prefix)
      local vpc_id="${resource_id%%|*}" prefix_id="${resource_id#*|}"
      ibmcloud is vpc-address-prefix-delete "$vpc_id" "$prefix_id" --force -q 2>&1
      ;;
    *)
      echo "  WARNING: unknown resource type: $resource_type" >&2
      return 1
      ;;
  esac
}

# The pinned mapt image may omit tags. For targeted cleanup only, resources in
# the exact mapt-created resource group are eligible for the legacy name-based
# fallback. Resource-group membership alone is never sufficient: unrelated
# resources in the same group must remain untouched.
normalize_target_resources() {
  local resource_type="$1"
  jq --arg target_rg_id "$TARGET_RESOURCE_GROUP_ID" \
     --arg project_name "$PROJECT_NAME" \
     --arg cluster_id "$CLUSTER_ID" \
     --arg resource_type "$resource_type" '
    if $target_rg_id == "" then . else
      map(if ((.resource_group.id // .resource_group_id) == $target_rg_id)
             and (
               (($resource_type == "instance" or $resource_type == "key") and .name == $project_name)
               or
               (($resource_type != "instance" and $resource_type != "key") and .name == ("main-" + $project_name))
             )
          then .tags = ((.tags // []) + ["iac:mapt", "k8s-type:kind", ("cluster-name:" + $cluster_id)])
          else . end)
    end
  '
}

# --- discover resources ---
# Build tag filter based on mode
TAG_FILTER="iac:mapt,k8s-type:kind"
if [[ -n "$PROJECT_NAME" ]]; then
  TAG_FILTER="iac:mapt,k8s-type:kind,cluster-name:${CLUSTER_ID}"
  echo "=== Targeted cleanup for project: $PROJECT_NAME ==="
else
  echo "=== Sweep mode: resources older than ${AGE_HOURS}h ==="
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  (dry-run mode — no resources will be deleted)"
fi

TARGET_RESOURCE_GROUP_ID=""
if [[ "$SWEEP" == "false" ]]; then
  RESOURCE_GROUPS=$(ibmcloud resource groups --output json)
  TARGET_RESOURCE_GROUP_ID=$(echo "$RESOURCE_GROUPS" | jq -r --arg name "$PROJECT_NAME" '
    .[] | select(.name == $name and (.default // false | not)) | .id
  ' | head -n 1)
fi

ERRORS=0

# --- 1. Instances ---
echo "--- Instances ---"
INSTANCES=$(ibmcloud is instances --output json | normalize_target_resources instance)
MATCHING_INSTANCES=$(echo "$INSTANCES" | jq -r --arg tag_filter "$TAG_FILTER" '
  [.[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  )]
')

INSTANCE_DELETE_COUNT=0
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping instance $name (not old enough)"
      continue
    fi
  fi
  if guarded_delete "instance" "$id" "$name"; then
    if [[ "$DRY_RUN" == "false" ]]; then
      INSTANCE_DELETE_COUNT=$((INSTANCE_DELETE_COUNT + 1))
    fi
  else
    ERRORS=$((ERRORS + 1))
  fi
done < <(echo "$MATCHING_INSTANCES" | jq -r '.[] | [.id, .name, .created_at] | @tsv')

# Wait for instance deletion to propagate before cleaning dependent resources
if [[ "$INSTANCE_DELETE_COUNT" -gt 0 ]]; then
  echo "  Waiting 30s for instance deletion to propagate..."
  sleep 30
fi

# --- 2. Floating IPs ---
echo ""
echo "--- Floating IPs ---"
FIPS=$(ibmcloud is floating-ips --output json | normalize_target_resources floating-ip)
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping floating IP $name (not old enough)"
      continue
    fi
  fi
  guarded_delete "floating-ip" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$FIPS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 3. Public gateways ---
echo ""
echo "--- Public Gateways ---"
PUBLIC_GATEWAYS=$(ibmcloud is public-gateways --output json | normalize_target_resources public-gateway)
while IFS=$'\t' read -r id name created_at; do
  [[ -z "$id" ]] && continue
  if [[ "$SWEEP" == "true" ]] && ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
    echo "  Skipping public gateway $name (not old enough)"
    continue
  fi
  guarded_delete "public-gateway" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$PUBLIC_GATEWAYS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 4. Subnets ---
echo ""
echo "--- Subnets ---"
SUBNETS=$(ibmcloud is subnets --output json | normalize_target_resources subnet)
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping subnet $name (not old enough)"
      continue
    fi
  fi
  guarded_delete "subnet" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$SUBNETS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 5. Security Groups ---
echo ""
echo "--- Security Groups ---"
SGS=$(ibmcloud is security-groups --output json | normalize_target_resources security-group)
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping security group $name (not old enough)"
      continue
    fi
  fi
  guarded_delete "security-group" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$SGS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select((.is_default // false) | not) | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 6. SSH Keys ---
echo ""
echo "--- SSH Keys ---"
KEYS=$(ibmcloud is keys --output json | normalize_target_resources key)
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping SSH key $name (not old enough)"
      continue
    fi
  fi
  guarded_delete "key" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$KEYS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 7. VPCs ---
echo ""
echo "--- VPCs ---"
VPCS=$(ibmcloud is vpcs --output json | normalize_target_resources vpc)
OWNED_RESOURCE_GROUP_IDS=$(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | (.resource_group.id // .resource_group_id // empty)
' | sort -u)

# Address prefixes must be removed before their VPC.
echo ""
echo "--- VPC Address Prefixes ---"
while read -r vpc_id vpc_created_at; do
  [[ -z "$vpc_id" ]] && continue
  if [[ "$SWEEP" == "true" ]] && ! is_older_than_hours "$vpc_created_at" "$AGE_HOURS"; then
    continue
  fi
  if ! PREFIXES=$(ibmcloud is vpc-address-prefixes "$vpc_id" --output json); then
    echo "  ERROR: failed to list address prefixes for VPC $vpc_id" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi
  if ! PREFIX_RECORDS=$(jq -r '
    if type != "array" then error("expected an array of address prefixes")
    elif any(.[]; ((.id | type) != "string") or ((.id | length) == 0) or
                    ((.name | type) != "string") or ((.name | length) == 0))
      then error("address prefix is missing a non-empty id or name")
    else .[] | [.id, .name] | @tsv
    end
  ' <<< "$PREFIXES"); then
    echo "  ERROR: failed to parse address prefixes for VPC $vpc_id" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi
  while IFS=$'\t' read -r prefix_id prefix_name; do
    [[ -z "$prefix_id" ]] && continue
    if [[ "$SWEEP" == "true" || "$prefix_name" == "main-${PROJECT_NAME}" ]]; then
      guarded_delete "vpc-address-prefix" "${vpc_id}|${prefix_id}" "$prefix_name" || ERRORS=$((ERRORS + 1))
    fi
  done <<< "$PREFIX_RECORDS"
done < <(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | "\(.id) \(.created_at)"
')
while IFS=$'\t' read -r id name created_at; do
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      echo "  Skipping VPC $name (not old enough)"
      continue
    fi
  fi
  guarded_delete "vpc" "$id" "$name" || ERRORS=$((ERRORS + 1))
done < <(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at] | @tsv
')

# --- 8. Resource group (targeted cleanup only) ---
# Resource groups are deleted last, after all tagged VPC resources. Sweep mode
# deliberately does not infer ownership from a group name; targeted cleanup has
# the exact project name and can safely identify the group mapt created.
if [[ "$SWEEP" == "false" ]]; then
  echo ""
  echo "--- Resource Group ---"
  RESOURCE_GROUP_ID="$TARGET_RESOURCE_GROUP_ID"

  if [[ -z "$RESOURCE_GROUP_ID" || "$RESOURCE_GROUP_ID" == "null" ]]; then
    echo "  Resource group $PROJECT_NAME not found (already removed)"
  elif ! grep -Fxq "$RESOURCE_GROUP_ID" <<< "$OWNED_RESOURCE_GROUP_IDS"; then
    echo "  ERROR: refusing to delete resource group $PROJECT_NAME; no tagged mapt VPC proves ownership" >&2
    ERRORS=$((ERRORS + 1))
  elif [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY-RUN] would delete resource group: $PROJECT_NAME ($RESOURCE_GROUP_ID)"
  else
    echo "  Deleting resource group: $PROJECT_NAME ($RESOURCE_GROUP_ID)..."
    if ! ibmcloud resource group-delete "$PROJECT_NAME" --force -q 2>&1; then
      echo "  ERROR: resource group $PROJECT_NAME could not be deleted; it may not be empty" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi
fi

# --- summary ---
echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "=== Cleanup completed with $ERRORS error(s) ==="
  exit 2
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "=== Dry-run complete (no resources were deleted) ==="
else
  echo "=== Cleanup completed successfully ==="
fi
