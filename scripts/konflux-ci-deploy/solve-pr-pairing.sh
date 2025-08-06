#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------------
# This script is intended to be executed 
# in a cloned GitHub repository https://github.com/konflux-ci/konflux-ci
#
# It assumes the following relative paths exist:
#   - konflux-ci/release/core/           (where downloaded YAMLs will be saved)
#   - /var/workdir/.env                  (output env file path)
#
# Required environment variables:
#   - COMPONENT_NAME        (e.g. "release-service" or "release-service-catalog")
#   - PR_SOURCE_BRANCH      (source branch of the PR to match)
#   - PR_AUTHOR             (GitHub username of the PR author)
#   - PR_SHA                (SHA of the current component PR)
# -----------------------------------------------------------------------------------

COMPONENT_NAME="${COMPONENT_NAME:-}"
PR_SOURCE_BRANCH="${PR_SOURCE_BRANCH:-}"
PR_AUTHOR="${PR_AUTHOR:-}"
PR_SHA="${PR_SHA:-}"

RELEASE_SERVICE_REPO="konflux-ci/release-service"
INFRA_DEPLOYMENTS_REPO="redhat-appstudio/infra-deployments"
IMAGE_REPO="quay.io/redhat-user-workloads/rhtap-release-2-tenant/release-service/release-service"
WORKDIR="/var/workdir"
ENV_FILE="$WORKDIR/.env"

mkdir -p "$WORKDIR"

log() {
  echo "[INFO] $1"
}

write_env_file() {
  log "Writing env file to $ENV_FILE"
  {
    echo "COMPONENT_NAME=release-service"
    echo "IMAGE_REPO=$IMAGE_REPO"
    echo "IMAGE_TAG=$1"
    echo "PR_OWNER=$PR_AUTHOR"
    echo "PR_SHA=$2"
  } > "$ENV_FILE"
}

fetch_paired_pr_sha() {
  local repo="$1"
  curl -s "https://api.github.com/repos/${repo}/pulls?per_page=100" |
    jq -r ".[] | select(.user.login == \"$PR_AUTHOR\" and .head.ref == \"$PR_SOURCE_BRANCH\")"
}

download_file() {
  local url="$1"
  local dest="$2"
  curl -sSfL "$url" > "$dest"
  log "Downloaded $(basename "$dest")"
}

IMAGE_TAG="on-pr-$PR_SHA"
if [[ -z "$PR_AUTHOR" ]]; then
  IMAGE_TAG=$PR_SHA
  PR_AUTHOR=konflux-ci
fi

konflux_components=( build-service integration-service image-controller release-service)

for component in "${konflux_components[@]}"; do
  if [[ "$COMPONENT_NAME" == "$component" ]]; then
    log "Setting up env vars for '$component'"
    write_env_file "$IMAGE_TAG" "$PR_SHA"
    cat "$ENV_FILE"
  fi
done

if [[ "$COMPONENT_NAME" == "release-service-catalog" || "$COMPONENT_NAME" == "release-service" ]]; then
  if [[ "$COMPONENT_NAME" == "release-service-catalog" ]]; then
    log "Looking for paired PR in $RELEASE_SERVICE_REPO for 'release-service-catalog'"
    PR_TO_PAIR=$(fetch_paired_pr_sha "$RELEASE_SERVICE_REPO")

    if [[ -n "$PR_TO_PAIR" ]]; then
      PAIRED_SHA=$(jq -r '.head.sha' <<< "$PR_TO_PAIR")
      write_env_file "on-pr-$PAIRED_SHA" "$PAIRED_SHA"
      log "Found paired PR in $RELEASE_SERVICE_REPO with SHA: $PAIRED_SHA"
    else
      log "No paired PR found in $RELEASE_SERVICE_REPO by $PR_AUTHOR on branch $PR_SOURCE_BRANCH"
    fi
  fi

  log "Checking for paired PR in $INFRA_DEPLOYMENTS_REPO"
  PR_TO_PAIR=$(fetch_paired_pr_sha "$INFRA_DEPLOYMENTS_REPO")

  REMOTE_NAME="redhat-appstudio"
  GIT_REF="main"

  if [[ -n "$PR_TO_PAIR" ]]; then
    REMOTE_NAME="$PR_AUTHOR"
    GIT_REF=$(jq -r '.head.sha' <<< "$PR_TO_PAIR")
    log "Found paired PR in $INFRA_DEPLOYMENTS_REPO. Using SHA: $GIT_REF"
  else
    log "No paired PR found in $INFRA_DEPLOYMENTS_REPO. Falling back to branch: $GIT_REF"
  fi

  CONFIG_DIR="konflux-ci/release/core"
  mkdir -p "$CONFIG_DIR"

  log "Downloading release_service_config.yaml..."
  download_file \
    "https://raw.githubusercontent.com/$REMOTE_NAME/infra-deployments/$GIT_REF/components/release/development/release_service_config.yaml" \
    "$CONFIG_DIR/release-service-config.yaml"

  log "Downloading release-pipeline-resources-clusterrole.yaml..."
  download_file \
    "https://raw.githubusercontent.com/$REMOTE_NAME/infra-deployments/$GIT_REF/components/release/base/release-pipeline-resources-clusterrole.yaml" \
    "$CONFIG_DIR/release-pipeline-resources-clusterrole.yaml"

  log "Configuration files updated."
fi