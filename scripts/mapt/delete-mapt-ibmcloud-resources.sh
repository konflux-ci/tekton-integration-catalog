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
MAPT_RESOURCE_GROUP_IDS='[]'
# floor(INT64_MAX / 3600), keeping seconds conversion and cutoff subtraction safe.
MAX_SAFE_AGE_HOURS=2562047788015215

is_safe_age_hours() {
  local value="$1"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || return 1

  if (( ${#value} < ${#MAX_SAFE_AGE_HOURS} )); then
    return 0
  fi
  if (( ${#value} > ${#MAX_SAFE_AGE_HOURS} )) || [[ "$value" > "$MAX_SAFE_AGE_HOURS" ]]; then
    return 1
  fi
  return 0
}

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

if [[ "$SWEEP" == "true" ]] && ! is_safe_age_hours "$AGE_HOURS"; then
  echo "ERROR: --age-hours must be a positive integer no greater than $MAX_SAFE_AGE_HOURS" >&2
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

if ! RESOURCE_GROUPS=$(ibmcloud resource groups --output json); then
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

  is_safe_age_hours "$max_hours" || return 1

  # Parse ISO 8601 timestamp to epoch
  created_epoch=$(date -d "$created_at" +%s 2>/dev/null) || return 1
  now_epoch=$(date +%s) || return 1
  [[ "$now_epoch" =~ ^[0-9]+$ ]] || return 1
  max_age_epoch=$(( now_epoch - (max_hours * 3600) ))

  [[ $created_epoch -lt $max_age_epoch ]]
}

is_old_enough_or_failed_instance_group() {
  local created_at="$1"
  local resource_group_id="$2"

  if [[ -n "$resource_group_id" && -n "${FAILED_INSTANCE_GROUP_IDS[$resource_group_id]:-}" ]]; then
    return 0
  fi
  is_older_than_hours "$created_at" "$AGE_HOURS"
}

resource_group_is_deferred() {
  local resource_group_id="$1"
  [[ "$SWEEP" == "true" && "$PROTECT_ALL_SWEEP_RESOURCES" == "true" ]] && return 0
  [[ -n "$resource_group_id" && -n "${PROTECTED_RESOURCE_GROUP_IDS[$resource_group_id]:-}" ]]
}

# --- helper: delete with dry-run guard ---
guarded_delete() {
  local resource_type="$1"
  local resource_id="$2"
  local resource_name="${3:-$resource_id}"
  local delete_status=0

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$SWEEP" == "true" ]]; then
      return 0
    fi
    echo "  [DRY-RUN] would delete $resource_type: $resource_name ($resource_id)"
    return 0
  fi

  echo "  Deleting $resource_type: $resource_name ($resource_id)..."
  case "$resource_type" in
    instance)
      ibmcloud is instance-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    floating-ip)
      ibmcloud is floating-ip-release "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    subnet)
      ibmcloud is subnet-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    security-group)
      ibmcloud is security-group-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    key)
      ibmcloud is key-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    vpc)
      ibmcloud is vpc-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    public-gateway)
      ibmcloud is public-gateway-delete "$resource_id" --force -q 2>&1 || delete_status=$?
      ;;
    vpc-address-prefix)
      local vpc_id="${resource_id%%|*}" prefix_id="${resource_id#*|}"
      ibmcloud is vpc-address-prefix-delete "$vpc_id" "$prefix_id" --force -q 2>&1 || delete_status=$?
      ;;
    resource-group)
      ibmcloud resource group-delete "$resource_name" --force -q 2>&1 || delete_status=$?
      ;;
    *)
      echo "  WARNING: unknown resource type: $resource_type" >&2
      return 1
      ;;
  esac

  if [[ "$SWEEP" == "true" ]]; then
    if [[ "$delete_status" -eq 0 ]]; then
      DELETE_REQUESTS_ACCEPTED=$((DELETE_REQUESTS_ACCEPTED + 1))
    else
      DELETE_REQUESTS_FAILED=$((DELETE_REQUESTS_FAILED + 1))
    fi
  fi
  return "$delete_status"
}

print_resource_section() {
  local section_name="$1"
  if [[ "$SWEEP" == "true" && "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  echo ""
  echo "--- $section_name ---"
}

wait_for_resource_removal() {
  local resource_type="$1"
  local list_command="$2"
  local submitted_map_name="$3"
  local pending_group_map_name="$4"
  local poll_interval="${5:-5}"
  local max_attempts="${6:-12}"
  local -n submitted_map="$submitted_map_name"
  local -n pending_group_map="$pending_group_map_name"
  local attempt current_resources current_ids id resource_group_id pending_count verification_failed=false

  [[ ${#submitted_map[@]} -gt 0 ]] || return 0
  echo "  Waiting for $resource_type deletion to propagate..."
  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if ! current_resources=$(ibmcloud is "$list_command" --output json) ||
       ! current_ids=$(jq -er '[.[].id]' <<< "$current_resources"); then
      echo "  ERROR: failed to verify $resource_type deletion; protecting affected resource groups" >&2
      ERRORS=$((ERRORS + 1))
      verification_failed=true
      for id in "${!submitted_map[@]}"; do
        resource_group_id="${submitted_map[$id]}"
        if [[ -n "$resource_group_id" ]]; then
          pending_group_map["$resource_group_id"]=1
          if [[ "$SWEEP" == "true" ]]; then
            PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
          fi
        elif [[ "$SWEEP" == "true" ]]; then
          PROTECT_ALL_SWEEP_RESOURCES=true
        fi
      done
      break
    fi

    pending_count=0
    for id in "${!submitted_map[@]}"; do
      if jq -e --arg id "$id" 'index($id) != null' <<< "$current_ids" >/dev/null; then
        pending_count=$((pending_count + 1))
      else
        unset 'submitted_map[$id]'
      fi
    done
    [[ "$pending_count" -eq 0 ]] && break
    [[ "$attempt" -eq "$max_attempts" ]] || sleep "$poll_interval"
  done

  if [[ "$verification_failed" == "false" ]]; then
    for id in "${!submitted_map[@]}"; do
      resource_group_id="${submitted_map[$id]}"
      echo "  $resource_type $id is still present; skipping dependent resources in its resource group"
      if [[ -n "$resource_group_id" ]]; then
        pending_group_map["$resource_group_id"]=1
        if [[ "$SWEEP" == "true" ]]; then
          PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
        fi
      elif [[ "$SWEEP" == "true" ]]; then
        PROTECT_ALL_SWEEP_RESOURCES=true
      fi
      ERRORS=$((ERRORS + 1))
    done
  fi
}

# VPC CLI resource JSON omits tags. Use Global Search CRNs to identify
# MAPT-owned resource groups, then include every listed resource in those
# per-instance groups, even when an individual resource lacks MAPT tags.
# For targeted cleanup, retain the legacy name-based fallback.
normalize_target_resources() {
  local resource_type="$1"
  jq --argjson tagged_resource_ids "$TAGGED_RESOURCE_IDS" \
     --argjson blocked_resource_group_ids "$BLOCKED_RESOURCE_GROUP_IDS" \
     --argjson owned_resource_group_ids "$MAPT_RESOURCE_GROUP_IDS" \
     --arg protect_all_sweep_resources "$PROTECT_ALL_SWEEP_RESOURCES" \
     --arg sweep "$SWEEP" \
     --arg tag_filter "$TAG_FILTER" \
     --arg target_rg_id "$TARGET_RESOURCE_GROUP_ID" \
     --arg project_name "$PROJECT_NAME" \
     --arg cluster_id "$CLUSTER_ID" \
     --arg resource_type "$resource_type" '
    map(
      . as $resource |
      if ($tagged_resource_ids | index($resource.id)) != null then
        .tags = ((.tags // []) + ($tag_filter | split(",")))
      else . end
    )
    | if $target_rg_id == "" then . else
        map(if ((.resource_group.id // .resource_group_id) == $target_rg_id)
               and (
                 (($resource_type == "instance" or $resource_type == "key") and .name == $project_name)
                 or
                 (($resource_type != "instance" and $resource_type != "key") and .name == ("main-" + $project_name))
               )
            then .tags = ((.tags // []) + ["iac:mapt", "k8s-type:kind", ("cluster-name:" + $cluster_id)])
            else . end)
      end
    | if $sweep == "true" then
        map(. as $resource |
          ($resource.resource_group.id // $resource.resource_group_id // "") as $group_id |
          if ($owned_resource_group_ids | index($group_id)) != null then
            .tags = ((.tags // []) + ($tag_filter | split(","))) |
            if ($tagged_resource_ids | index($resource.id)) == null
            then .sweep_inferred = true else . end
          else . end)
      else . end
    | map(. as $resource |
        if $sweep == "true" and
           ($protect_all_sweep_resources == "true" or
            ($blocked_resource_group_ids | index($resource.resource_group.id // $resource.resource_group_id // "")) != null)
        then .tags = [] else . end)
  '
}

tagged_resource_group_ids() {
  jq -c --argjson tagged_resource_ids "$TAGGED_RESOURCE_IDS" --argjson resource_groups "$RESOURCE_GROUPS" '
    if type != "array" then error("expected an array of IBM Cloud resources")
    else
      [.[] | . as $resource |
        select(($tagged_resource_ids | index($resource.id)) != null) |
        ($resource.resource_group.id // $resource.resource_group_id // empty)
      ] | unique | map(. as $id | select(any($resource_groups[]; .id == $id and (.default // false | not))))
    end
  '
}

print_group_resources() {
  local resource_type="$1"
  local resource_group_id="$2"
  local resources="$3"
  local name id status created_at decision

  while IFS=$'\t' read -r name id status created_at; do
    [[ -z "$id" ]] && continue
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      if [[ -z "$created_at" || "$created_at" == "unknown" ]] || ! date -d "$created_at" +%s >/dev/null 2>&1; then
        decision="keep: age unknown"
      else
        decision="keep: younger than ${AGE_HOURS}h"
      fi
    elif resource_group_is_deferred "$resource_group_id"; then
      decision="keep: resource group deferred"
    else
      decision="would delete"
      SWEEP_DELETE_RESOURCE_COUNT=$((SWEEP_DELETE_RESOURCE_COUNT + 1))
      SWEEP_DELETE_GROUP_IDS["$resource_group_id"]=1
    fi
    if [[ "$resource_type" == "instance" ]]; then
      printf '    %-18s %s (%s; status: %s; %s)\n' "$resource_type" "$name" "$id" "${status:-unknown}" "$decision"
    else
      printf '    %-18s %s (%s; %s)\n' "$resource_type" "$name" "$id" "$decision"
    fi
  done < <(jq -r --arg group_id "$resource_group_id" --arg resource_type "$resource_type" --argjson default_security_group_ids "$DEFAULT_SECURITY_GROUP_IDS_JSON" '
    .[] | . as $resource | select((.resource_group.id // .resource_group_id // "") == $group_id) |
    select($resource_type != "security-group" or
           (((.is_default // false) | not) and ($default_security_group_ids | index($resource.id)) == null)) |
    [.name, .id, (if ((.status // "") | length) == 0 then "unknown" else .status end), (.created_at // "unknown")] | @tsv
  ' <<< "$resources")
}

print_group_vpcs() {
  local resource_group_id="$1"
  local resources="$2"
  local vpc_id vpc_name created_at prefix_id prefix_name decision prefix_records prefixes

  while IFS=$'\t' read -r vpc_id vpc_name created_at; do
    [[ -z "$vpc_id" ]] && continue
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      decision="keep: younger than ${AGE_HOURS}h"
    elif resource_group_is_deferred "$resource_group_id"; then
      decision="keep: resource group deferred"
    else
      decision="would delete"
    fi
    if ! prefixes=$(ibmcloud is vpc-address-prefixes "$vpc_id" --output json); then
      printf '    %-18s %s (%s; keep: prefix inventory failed)\n' vpc "$vpc_name" "$vpc_id"
      echo "      ERROR: could not list address prefixes for VPC $vpc_id" >&2
      ERRORS=$((ERRORS + 1))
      VPC_PREFIX_INVENTORY_LOADED["$vpc_id"]=failed
      if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
      continue
    fi
    if ! prefix_records=$(jq -r '
      if type != "array" then error("expected an array of address prefixes")
      elif any(.[]; ((.id | type) != "string") or ((.id | length) == 0) or
                      ((.name | type) != "string") or ((.name | length) == 0))
        then error("address prefix is missing a non-empty id or name")
      else .[] | [.id, .name] | @tsv
      end
    ' <<< "$prefixes"); then
      printf '    %-18s %s (%s; keep: prefix inventory failed)\n' vpc "$vpc_name" "$vpc_id"
      echo "      ERROR: could not parse address prefixes for VPC $vpc_id" >&2
      ERRORS=$((ERRORS + 1))
      VPC_PREFIX_INVENTORY_LOADED["$vpc_id"]=failed
      if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
      continue
    fi

    VPC_PREFIX_INVENTORIES["$vpc_id"]="$prefix_records"
    VPC_PREFIX_INVENTORY_LOADED["$vpc_id"]=true
    if [[ "$decision" == "would delete" ]]; then
      SWEEP_DELETE_RESOURCE_COUNT=$((SWEEP_DELETE_RESOURCE_COUNT + 1))
      SWEEP_DELETE_GROUP_IDS["$resource_group_id"]=1
    fi
    printf '    %-18s %s (%s; %s)\n' vpc "$vpc_name" "$vpc_id" "$decision"
    while IFS=$'\t' read -r prefix_id prefix_name; do
      [[ -z "$prefix_id" ]] && continue
      if [[ "$decision" == "would delete" ]]; then
        SWEEP_DELETE_RESOURCE_COUNT=$((SWEEP_DELETE_RESOURCE_COUNT + 1))
        SWEEP_DELETE_GROUP_IDS["$resource_group_id"]=1
      fi
      printf '      address-prefix    %s (%s; %s)\n' "$prefix_name" "$prefix_id" "$decision"
    done <<< "$prefix_records"
  done < <(jq -r --arg group_id "$resource_group_id" '
    .[] | select((.resource_group.id // .resource_group_id // "") == $group_id) |
    [.id, .name, (.created_at // "")] | @tsv
  ' <<< "$resources")
}

print_sweep_group_inventory() {
  [[ "$SWEEP" == "true" ]] || return 0

  echo "--- MAPT Resource Group Inventory ---"
  while IFS= read -r resource_group_id; do
    [[ -z "$resource_group_id" ]] && continue
    local group_name
    group_name=$(jq -r --arg id "$resource_group_id" '.[] | select(.id == $id) | .name' <<< "$RESOURCE_GROUPS")
    if [[ -n "${PROTECTED_RESOURCE_GROUP_REASONS[$resource_group_id]:-}" ]]; then
      printf '  Resource group: %s (%s; deferred: %s)\n' "${group_name:-unknown}" "$resource_group_id" "${PROTECTED_RESOURCE_GROUP_REASONS[$resource_group_id]}"
    else
      printf '  Resource group: %s (%s)\n' "${group_name:-unknown}" "$resource_group_id"
    fi
    print_group_resources instance "$resource_group_id" "$RAW_INSTANCES"
    print_group_resources subnet "$resource_group_id" "$RAW_SUBNETS"
    print_group_resources public-gateway "$resource_group_id" "$RAW_PUBLIC_GATEWAYS"
    print_group_resources floating-ip "$resource_group_id" "$RAW_FIPS"
    print_group_resources security-group "$resource_group_id" "$RAW_SGS"
    print_group_resources key "$resource_group_id" "$RAW_KEYS"
    print_group_vpcs "$resource_group_id" "$RAW_VPCS"
  done < <(jq -r '.[]' <<< "$MAPT_RESOURCE_GROUP_IDS")

  local delete_group_id delete_group_name deferred_group_id delete_group_count=0 deferred_group_count=0
  delete_group_count=${#SWEEP_DELETE_GROUP_IDS[@]}
  while IFS= read -r deferred_group_id; do
    [[ -z "$deferred_group_id" ]] && continue
    if resource_group_is_deferred "$deferred_group_id"; then
      deferred_group_count=$((deferred_group_count + 1))
    fi
  done < <(jq -r '.[]' <<< "$MAPT_RESOURCE_GROUP_IDS")
  echo "--- Initial Sweep Plan ---"
  printf '  %s resource(s) eligible across %s resource group(s) at inventory time:\n' "$SWEEP_DELETE_RESOURCE_COUNT" "$delete_group_count"
  while IFS= read -r delete_group_id; do
    [[ -z "$delete_group_id" ]] && continue
    delete_group_name=$(jq -r --arg id "$delete_group_id" '.[] | select(.id == $id) | .name' <<< "$RESOURCE_GROUPS")
    printf '    %s (%s)\n' "${delete_group_name:-unknown}" "$delete_group_id"
  done < <(printf '%s\n' "${!SWEEP_DELETE_GROUP_IDS[@]}" | sort)
  printf '  Initially deferred resource groups: %s\n' "$deferred_group_count"
  echo "  The eligible set can change if deletion or dependency checks fail."
  echo ""
}

preflight_resource_group_ages() {
  local resource_type="$1"
  local resources="$2"
  local resource_group_id resource_name created_at

  while IFS=$'\t' read -r resource_group_id resource_name created_at; do
    [[ -z "$resource_group_id" || -z "${MAPT_RESOURCE_GROUP_ID_SET[$resource_group_id]:-}" ]] && continue
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id" &&
       [[ -z "${PROTECTED_RESOURCE_GROUP_IDS[$resource_group_id]:-}" ]]; then
      PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
      PROTECTED_RESOURCE_GROUP_REASONS["$resource_group_id"]="$resource_type $resource_name is younger than ${AGE_HOURS}h"
    fi
  done < <(jq -r '.[] | [(.resource_group.id // .resource_group_id // ""), .name, (.created_at // "")] | @tsv' <<< "$resources")
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

# Tags are stored in IBM Cloud Global Search, not in VPC CLI resource JSON.
RESOURCE_TAG_QUERY='family:is AND tags:"iac:mapt" AND tags:"k8s-type:kind"'
RESOURCE_SEARCH_OFFSET=0
TAGGED_RESOURCE_IDS='[]'
while true; do
  RESOURCE_SEARCH_ARGS=(resource search "$RESOURCE_TAG_QUERY" --limit 1000 --output JSON)
  if [[ "$RESOURCE_SEARCH_OFFSET" -gt 0 ]]; then
    RESOURCE_SEARCH_ARGS+=(--offset "$RESOURCE_SEARCH_OFFSET")
  fi
  if ! TAGGED_RESOURCES=$(ibmcloud "${RESOURCE_SEARCH_ARGS[@]}"); then
    echo "ERROR: failed to search IBM Cloud resources for MAPT tags" >&2
    exit 2
  fi
  RESOURCE_SEARCH_COUNT=$(jq -r '.items | length' <<< "$TAGGED_RESOURCES") || {
    echo "ERROR: failed to parse IBM Cloud resource search results" >&2
    exit 2
  }
  if ! PAGE_RESOURCE_IDS=$(jq -er --arg tag_filter "$TAG_FILTER" '
    if (.items | type) != "array" then error("expected resource search items array")
    elif any(.items[]; ((.crn | type) != "string") or ((.tags | type) != "array"))
      then error("resource search item is missing a CRN or tags")
    else
      [.items[] | select(
        (.tags // []) as $tags |
        ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
      ) | (.crn | split(":") | last)] | unique
    end
  ' <<< "$TAGGED_RESOURCES"); then
    echo "ERROR: failed to parse IBM Cloud resource search results" >&2
    exit 2
  fi
  TAGGED_RESOURCE_IDS=$(jq -cn --argjson all "$TAGGED_RESOURCE_IDS" --argjson page "$PAGE_RESOURCE_IDS" '$all + $page | unique')
  if [[ "$RESOURCE_SEARCH_COUNT" -lt 1000 ]]; then
    break
  fi
  RESOURCE_SEARCH_OFFSET=$((RESOURCE_SEARCH_OFFSET + 1000))
done
TAGGED_RESOURCE_COUNT=$(jq 'length' <<< "$TAGGED_RESOURCE_IDS")
echo "Found $TAGGED_RESOURCE_COUNT MAPT-tagged IBM Cloud resource(s)."

TARGET_RESOURCE_GROUP_ID=""
if [[ "$SWEEP" == "false" ]]; then
  TARGET_RESOURCE_GROUP_ID=$(echo "$RESOURCE_GROUPS" | jq -r --arg name "$PROJECT_NAME" '
    .[] | select(.name == $name and (.default // false | not)) | .id
  ' | head -n 1)
fi

ERRORS=0
BLOCKED_RESOURCE_GROUP_IDS='[]'
PROTECT_ALL_SWEEP_RESOURCES=false
declare -A PROTECTED_RESOURCE_GROUP_IDS=() SUBMITTED_INSTANCE_GROUP_IDS=() PENDING_INSTANCE_GROUP_IDS=()
declare -A FAILED_INSTANCE_GROUP_IDS=()
declare -A VPC_PREFIX_INVENTORIES=() VPC_PREFIX_INVENTORY_LOADED=()
declare -A PROTECTED_RESOURCE_GROUP_REASONS=()
declare -A SWEEP_DELETE_GROUP_IDS=()
declare -A DEFAULT_SECURITY_GROUP_IDS=()
declare -A SUBMITTED_SUBNET_GROUP_IDS=() PENDING_SUBNET_GROUP_IDS=()
declare -A SUBMITTED_PUBLIC_GATEWAY_GROUP_IDS=() PENDING_PUBLIC_GATEWAY_GROUP_IDS=()
SWEEP_DELETE_RESOURCE_COUNT=0
DELETE_REQUESTS_ACCEPTED=0
DELETE_REQUESTS_FAILED=0
DEFAULT_SECURITY_GROUP_IDS_JSON='[]'

# Snapshot inventories before deleting anything so tagged sibling resources
# can establish MAPT resource-group ownership for an untagged instance.
RAW_INSTANCES=$(ibmcloud is instances --output json)
RAW_FIPS=$(ibmcloud is floating-ips --output json)
RAW_PUBLIC_GATEWAYS=$(ibmcloud is public-gateways --output json)
RAW_SUBNETS=$(ibmcloud is subnets --output json)
RAW_SGS=$(ibmcloud is security-groups --output json)
RAW_KEYS=$(ibmcloud is keys --output json)
RAW_VPCS=$(ibmcloud is vpcs --output json)
MAPT_RESOURCE_GROUP_IDS='[]'
for resources in "$RAW_INSTANCES" "$RAW_FIPS" "$RAW_PUBLIC_GATEWAYS" "$RAW_SUBNETS" "$RAW_SGS" "$RAW_KEYS" "$RAW_VPCS"; do
  if ! RESOURCE_GROUP_IDS=$(tagged_resource_group_ids <<< "$resources"); then
    echo "ERROR: failed to identify MAPT resource groups from IBM Cloud resources" >&2
    exit 2
  fi
  MAPT_RESOURCE_GROUP_IDS=$(jq -cn --argjson all "$MAPT_RESOURCE_GROUP_IDS" --argjson next "$RESOURCE_GROUP_IDS" '$all + $next | unique')
done

declare -A MAPT_RESOURCE_GROUP_ID_SET=()
while IFS= read -r resource_group_id; do
  [[ -n "$resource_group_id" ]] && MAPT_RESOURCE_GROUP_ID_SET["$resource_group_id"]=1
done < <(jq -r '.[]' <<< "$MAPT_RESOURCE_GROUP_IDS")

# Discover default security group IDs from IBM Cloud's VPC API. The list
# command's is_default field is not consistently populated for these records.
DEFAULT_SG_VPCS=$(echo "$RAW_VPCS" | normalize_target_resources vpc)
while IFS=$'\t' read -r vpc_id vpc_name resource_group_id; do
  [[ -z "$vpc_id" ]] && continue
  if ! default_security_group=$(ibmcloud is vpc-default-security-group "$vpc_id" --output json); then
    echo "ERROR: failed to identify the default security group for VPC $vpc_name" >&2
    if [[ "$SWEEP" == "true" && -n "$resource_group_id" ]]; then
      PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
      PROTECTED_RESOURCE_GROUP_REASONS["$resource_group_id"]="default security group lookup failed for VPC $vpc_name"
      ERRORS=$((ERRORS + 1))
    else
      exit 2
    fi
    continue
  fi
  if ! default_security_group_id=$(jq -er '.id | select(type == "string" and length > 0)' <<< "$default_security_group"); then
    echo "ERROR: failed to parse the default security group for VPC $vpc_name" >&2
    if [[ "$SWEEP" == "true" && -n "$resource_group_id" ]]; then
      PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
      PROTECTED_RESOURCE_GROUP_REASONS["$resource_group_id"]="default security group lookup failed for VPC $vpc_name"
      ERRORS=$((ERRORS + 1))
    else
      exit 2
    fi
    continue
  fi
  DEFAULT_SECURITY_GROUP_IDS["$default_security_group_id"]="$resource_group_id"
done < <(echo "$DEFAULT_SG_VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, (.resource_group.id // .resource_group_id // "")] | @tsv
')
DEFAULT_SECURITY_GROUP_IDS_JSON=$(printf '%s\n' "${!DEFAULT_SECURITY_GROUP_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')

# Discover failed instances and preflight every known resource in each owned
# group before deleting anything. A recent resource defers its whole group.
while IFS= read -r resource_group_id; do
  [[ -n "$resource_group_id" ]] && FAILED_INSTANCE_GROUP_IDS["$resource_group_id"]=1
done < <(jq -r --argjson owned "$MAPT_RESOURCE_GROUP_IDS" '
  .[] | select(.status == "failed") |
  (.resource_group.id // .resource_group_id // "") as $group_id |
  select(($owned | index($group_id)) != null) | $group_id
' <<< "$RAW_INSTANCES")
preflight_resource_group_ages instance "$RAW_INSTANCES"
preflight_resource_group_ages floating-ip "$RAW_FIPS"
preflight_resource_group_ages public-gateway "$RAW_PUBLIC_GATEWAYS"
preflight_resource_group_ages subnet "$RAW_SUBNETS"
preflight_resource_group_ages security-group "$RAW_SGS"
preflight_resource_group_ages key "$RAW_KEYS"
preflight_resource_group_ages vpc "$RAW_VPCS"
BLOCKED_RESOURCE_GROUP_IDS=$(printf '%s\n' "${!PROTECTED_RESOURCE_GROUP_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
print_sweep_group_inventory

# --- 1. Instances ---
print_resource_section "Instances"
INSTANCES=$(echo "$RAW_INSTANCES" | normalize_target_resources instance)
MATCHING_INSTANCES=$(echo "$INSTANCES" | jq -r --arg tag_filter "$TAG_FILTER" '
  [.[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  )]
')
INSTANCE_DELETE_COUNT=0
while IFS=$'\t' read -r id name created_at resource_group_id status; do
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_older_than_hours "$created_at" "$AGE_HOURS"; then
      if [[ "$status" == "failed" && -n "$resource_group_id" ]]; then
        echo "  Instance $name has failed status; bypassing the age threshold"
      else
        echo "  Skipping instance $name (not old enough)"
        if [[ -n "$resource_group_id" ]]; then
          PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
          echo "  Protecting resource group $resource_group_id because the instance is too new"
        else
          echo "  ERROR: instance $name has no resource group; protecting all sweep resources" >&2
          PROTECT_ALL_SWEEP_RESOURCES=true
          ERRORS=$((ERRORS + 1))
        fi
        continue
      fi
    fi
  fi
  if guarded_delete "instance" "$id" "$name"; then
    if [[ "$SWEEP" == "true" && "$status" == "failed" && -n "$resource_group_id" ]]; then
      FAILED_INSTANCE_GROUP_IDS["$resource_group_id"]=1
    fi
    if [[ "$DRY_RUN" == "false" ]]; then
      INSTANCE_DELETE_COUNT=$((INSTANCE_DELETE_COUNT + 1))
      if [[ -n "$resource_group_id" ]]; then
        SUBMITTED_INSTANCE_GROUP_IDS["$id"]="$resource_group_id"
      elif [[ "$SWEEP" == "true" ]]; then
        echo "  ERROR: instance $name has no resource group; protecting all sweep resources" >&2
        PROTECT_ALL_SWEEP_RESOURCES=true
        ERRORS=$((ERRORS + 1))
      fi
    fi
  else
    ERRORS=$((ERRORS + 1))
    if [[ "$SWEEP" == "true" ]]; then
      if [[ -n "$resource_group_id" ]]; then
        PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
        echo "  Protecting resource group $resource_group_id because instance deletion failed"
      else
        PROTECT_ALL_SWEEP_RESOURCES=true
      fi
    fi
  fi
done < <(echo "$MATCHING_INSTANCES" | jq -r '.[] | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // ""), (.status // "")] | @tsv')

# Wait for instance deletion to propagate before cleaning dependent resources.
# Sweep mode polls immediately and then every 30 seconds for up to two minutes.
if [[ "$INSTANCE_DELETE_COUNT" -gt 0 ]]; then
  if [[ "$SWEEP" == "true" ]]; then
    wait_for_resource_removal "instance" "instances" SUBMITTED_INSTANCE_GROUP_IDS PENDING_INSTANCE_GROUP_IDS 30 5
  else
    echo "  Waiting 30s for instance deletion to propagate..."
    sleep 30
  fi
fi
BLOCKED_RESOURCE_GROUP_IDS=$(printf '%s\n' "${!PROTECTED_RESOURCE_GROUP_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')

# --- 2. Subnets ---
print_resource_section "Subnets"
SUBNETS=$(echo "$RAW_SUBNETS" | normalize_target_resources subnet)
while IFS=$'\t' read -r id name created_at resource_group_id; do
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      echo "  Skipping subnet $name (not old enough)"
      [[ -n "$resource_group_id" ]] && PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
      continue
    fi
  fi
  if ! guarded_delete "subnet" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then
      PENDING_SUBNET_GROUP_IDS["$resource_group_id"]=1
      [[ "$SWEEP" == "true" ]] && PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
    elif [[ "$SWEEP" == "true" ]]; then
      PROTECT_ALL_SWEEP_RESOURCES=true
    fi
  elif [[ "$DRY_RUN" == "false" ]]; then
    SUBMITTED_SUBNET_GROUP_IDS["$id"]="$resource_group_id"
  fi
done < <(echo "$SUBNETS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')
wait_for_resource_removal "subnet" "subnets" SUBMITTED_SUBNET_GROUP_IDS PENDING_SUBNET_GROUP_IDS

# Deleting the subnet detaches its public gateway; deleting the gateway then
# detaches its floating IP, which can be released afterward.
# --- 3. Public gateways ---
print_resource_section "Public Gateways"
PUBLIC_GATEWAYS=$(echo "$RAW_PUBLIC_GATEWAYS" | normalize_target_resources public-gateway)
while IFS=$'\t' read -r id name created_at resource_group_id; do
  [[ -z "$id" ]] && continue
  if [[ -n "${PENDING_SUBNET_GROUP_IDS[$resource_group_id]:-}" ]]; then continue; fi
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]] && ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
    echo "  Skipping public gateway $name (not old enough)"
    [[ -n "$resource_group_id" ]] && PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
    continue
  fi
  if ! guarded_delete "public-gateway" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then
      PENDING_PUBLIC_GATEWAY_GROUP_IDS["$resource_group_id"]=1
      [[ "$SWEEP" == "true" ]] && PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1
    elif [[ "$SWEEP" == "true" ]]; then
      PROTECT_ALL_SWEEP_RESOURCES=true
    fi
  elif [[ "$DRY_RUN" == "false" ]]; then
    SUBMITTED_PUBLIC_GATEWAY_GROUP_IDS["$id"]="$resource_group_id"
  fi
done < <(echo "$PUBLIC_GATEWAYS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')

wait_for_resource_removal "public gateway" "public-gateways" SUBMITTED_PUBLIC_GATEWAY_GROUP_IDS PENDING_PUBLIC_GATEWAY_GROUP_IDS

# --- 4. Floating IPs ---
print_resource_section "Floating IPs"
if [[ "$DRY_RUN" == "false" ]] && ! RAW_FIPS=$(ibmcloud is floating-ips --output json); then
  echo "  ERROR: failed to refresh floating IP inventory after public gateway cleanup" >&2
  ERRORS=$((ERRORS + 1))
  if [[ "$SWEEP" == "true" ]]; then
    PROTECT_ALL_SWEEP_RESOURCES=true
  fi
  RAW_FIPS='[]'
fi
FIPS=$(echo "$RAW_FIPS" | normalize_target_resources floating-ip)
while IFS=$'\t' read -r id name created_at resource_group_id; do
  if [[ -n "${PENDING_SUBNET_GROUP_IDS[$resource_group_id]:-}" ||
        -n "${PENDING_PUBLIC_GATEWAY_GROUP_IDS[$resource_group_id]:-}" ]]; then continue; fi
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]] && ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
    echo "  Skipping floating IP $name (not old enough)"
    continue
  fi
  if ! guarded_delete "floating-ip" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
  fi
done < <(echo "$FIPS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')

# --- 5. Security Groups ---
print_resource_section "Security Groups"
SGS=$(echo "$RAW_SGS" | normalize_target_resources security-group)
while IFS=$'\t' read -r id name created_at resource_group_id; do
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      echo "  Skipping security group $name (not old enough)"
      continue
    fi
  fi
  if ! guarded_delete "security-group" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
  fi
done < <(echo "$SGS" | jq -r --arg tag_filter "$TAG_FILTER" --argjson default_security_group_ids "$DEFAULT_SECURITY_GROUP_IDS_JSON" '
  .[] | . as $resource | select(
    ((.is_default // false) | not) and
    (($default_security_group_ids | index($resource.id)) == null)
  ) | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')

# --- 6. SSH Keys ---
print_resource_section "SSH Keys"
KEYS=$(echo "$RAW_KEYS" | normalize_target_resources key)
while IFS=$'\t' read -r id name created_at resource_group_id; do
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      echo "  Skipping SSH key $name (not old enough)"
      continue
    fi
  fi
  if ! guarded_delete "key" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
  fi
done < <(echo "$KEYS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')

# --- 7. VPCs ---
print_resource_section "VPCs"
VPCS=$(echo "$RAW_VPCS" | normalize_target_resources vpc)
OWNED_RESOURCE_GROUP_IDS=$(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | (.resource_group.id // .resource_group_id // empty)
' | sort -u)

# Address prefixes must be removed before their VPC.
print_resource_section "VPC Address Prefixes"
while IFS=$'\t' read -r vpc_id vpc_created_at vpc_resource_group_id; do
  [[ -z "$vpc_id" ]] && continue
  if resource_group_is_deferred "$vpc_resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]] && ! is_old_enough_or_failed_instance_group "$vpc_created_at" "$vpc_resource_group_id"; then
    [[ -n "$vpc_resource_group_id" ]] && PROTECTED_RESOURCE_GROUP_IDS["$vpc_resource_group_id"]=1
    continue
  fi
  if [[ "${VPC_PREFIX_INVENTORY_LOADED[$vpc_id]:-}" == "failed" ]]; then
    continue
  elif [[ "${VPC_PREFIX_INVENTORY_LOADED[$vpc_id]:-}" == "true" ]]; then
    PREFIX_RECORDS="${VPC_PREFIX_INVENTORIES[$vpc_id]}"
  else
    if ! PREFIXES=$(ibmcloud is vpc-address-prefixes "$vpc_id" --output json); then
      echo "  ERROR: failed to list address prefixes for VPC $vpc_id" >&2
      ERRORS=$((ERRORS + 1))
      if [[ -n "$vpc_resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$vpc_resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
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
      if [[ -n "$vpc_resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$vpc_resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
      continue
    fi
  fi
  while IFS=$'\t' read -r prefix_id prefix_name; do
    [[ -z "$prefix_id" ]] && continue
    if [[ "$SWEEP" == "true" || "$prefix_name" == "main-${PROJECT_NAME}" ]]; then
      if ! guarded_delete "vpc-address-prefix" "${vpc_id}|${prefix_id}" "$prefix_name"; then
        ERRORS=$((ERRORS + 1))
        if [[ -n "$vpc_resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$vpc_resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
      fi
    fi
  done <<< "$PREFIX_RECORDS"
done < <(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')
while IFS=$'\t' read -r id name created_at resource_group_id; do
  if resource_group_is_deferred "$resource_group_id"; then continue; fi
  if [[ "$SWEEP" == "true" ]]; then
    if ! is_old_enough_or_failed_instance_group "$created_at" "$resource_group_id"; then
      echo "  Skipping VPC $name (not old enough)"
      continue
    fi
  fi
  if ! guarded_delete "vpc" "$id" "$name"; then
    ERRORS=$((ERRORS + 1))
    if [[ -n "$resource_group_id" ]]; then PROTECTED_RESOURCE_GROUP_IDS["$resource_group_id"]=1; else PROTECT_ALL_SWEEP_RESOURCES=true; fi
  fi
done < <(echo "$VPCS" | jq -r --arg tag_filter "$TAG_FILTER" '
  .[] | select(
    (.tags // []) as $tags |
    ($tag_filter | split(",")) | all(. as $t | $tags | any(. == $t))
  ) | [.id, .name, .created_at, (.resource_group.id // .resource_group_id // "")] | @tsv
')

# --- 8. Resource groups ---
# Delete groups last. Any tagged MAPT resource proves group ownership; the
# inventory preflight defers the whole group when a supported resource is new.
if [[ "$SWEEP" == "true" ]]; then
  if ! RESOURCE_GROUPS=$(ibmcloud resource groups --output json); then
    echo "  ERROR: failed to list IBM Cloud resource groups" >&2
    ERRORS=$((ERRORS + 1))
  elif ! RESOURCE_GROUP_RECORDS=$(jq -r '
    if type != "array" then error("expected an array of resource groups")
    elif any(.[]; ((.id | type) != "string") or ((.id | length) == 0) or
                    ((.name | type) != "string") or ((.name | length) == 0))
      then error("resource group is missing a non-empty id or name")
    else .[] | select((.default // false) | not) | [.name, .id] | @tsv
    end
  ' <<< "$RESOURCE_GROUPS"); then
    echo "  ERROR: failed to parse IBM Cloud resource groups" >&2
    ERRORS=$((ERRORS + 1))
  else
    while IFS=$'\t' read -r group_name group_id; do
      [[ -z "$group_id" ]] && continue
      [[ -n "${MAPT_RESOURCE_GROUP_ID_SET[$group_id]:-}" ]] || continue
      if resource_group_is_deferred "$group_id"; then
        continue
      fi
      if [[ "$DRY_RUN" == "false" ]]; then
        if ! REMAINING_GROUP_RESOURCES=$(ibmcloud resource service-instances --type all -g "$group_name" --limit 100 --output JSON); then
          echo "  ERROR: failed to inventory remaining resources in $group_name" >&2
          PROTECTED_RESOURCE_GROUP_IDS["$group_id"]=1
          ERRORS=$((ERRORS + 1))
          continue
        elif ! REMAINING_GROUP_RESOURCE_COUNT=$(jq -er 'if type == "array" then length else error("expected a resource array") end' <<< "$REMAINING_GROUP_RESOURCES"); then
          echo "  ERROR: failed to parse remaining resources in $group_name" >&2
          PROTECTED_RESOURCE_GROUP_IDS["$group_id"]=1
          ERRORS=$((ERRORS + 1))
          continue
        elif [[ "$REMAINING_GROUP_RESOURCE_COUNT" -gt 0 ]]; then
          echo "  Skipping resource group $group_name ($REMAINING_GROUP_RESOURCE_COUNT resource(s) remain)"
          PROTECTED_RESOURCE_GROUP_IDS["$group_id"]=1
          continue
        fi
      fi
      guarded_delete "resource-group" "$group_id" "$group_name" || ERRORS=$((ERRORS + 1))
    done <<< "$RESOURCE_GROUP_RECORDS"
  fi
else
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
if [[ "$SWEEP" == "true" ]]; then
  local_deferred_group_count=0
  while IFS= read -r resource_group_id; do
    [[ -z "$resource_group_id" ]] && continue
    if resource_group_is_deferred "$resource_group_id"; then
      local_deferred_group_count=$((local_deferred_group_count + 1))
    fi
  done < <(jq -r '.[]' <<< "$MAPT_RESOURCE_GROUP_IDS")
  echo "=== Sweep execution summary ==="
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  Dry-run: no delete requests were sent."
  else
    printf '  Delete requests accepted: %s\n' "$DELETE_REQUESTS_ACCEPTED"
    printf '  Delete requests failed: %s\n' "$DELETE_REQUESTS_FAILED"
    printf '  Resource groups protected during execution: %s\n' "$local_deferred_group_count"
  fi
fi
if [[ $ERRORS -gt 0 ]]; then
  echo "=== Cleanup completed with $ERRORS error(s) ==="
  exit 2
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "=== Dry-run complete (no resources were deleted) ==="
else
  echo "=== Cleanup completed successfully ==="
fi
