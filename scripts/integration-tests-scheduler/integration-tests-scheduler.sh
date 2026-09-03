#!/bin/bash
set -euo pipefail

###############################################################################
# Konflux Integration Test Scenario Scheduler
###############################################################################
#
# This script automates the scheduling and execution of integration test scenarios in Konflux.
# It can be run locally by logging into the Konflux cluster or you can execute as a Kubernetes CronJob.
# For detailed setup instructions, refer to the official documentation:
# https://konflux-ci.dev/docs/how-tos/testing/integration/periodic-integration-tests.
# NOTE: The schhedule flag helps to not run CronJobs if there are no commits from the previous execution.
#
# -------------------------------------------
# HOW IT WORKS:
# -------------------------------------------
# 1. **Clone the Repository:**
#    - It verifies and clones the specified GitHub repository and branch into a temporary directory.
#
# 2. **Check for Recent Commits (Optional):**
#    - If the `--no-old-commits-run` flag is set, the script checks whether any new commits
#      have been made since the specified time.
#    - If no new commits are found, the script exits without triggering tests.
#
# 3. **Trigger Integration Tests:**
#    - The script identifies the latest valid snapshot related to push events.
#    - If a valid snapshot is found, it labels it to trigger the corresponding integration test scenario.
#    - If no valid snapshot is found, the script exits with an error message.
#
# -------------------------------------------
# USAGE EXAMPLE:
# -------------------------------------------
# The following command schedules an integration test to run every 2 hours,
# checks a GitHub repository, and triggers a test only if new commits are detected in last 2 hours:
#
# /bin/bash schedule-integration-scenario.sh --schedule 2h \
#             --repository-url https://github.com/konflux-ci/build-service.git \
#             --branch main \
#             --konflux-scenario-name my-scenario \
#             --konflux-tenant-name my-tenant \
#             --konflux-application-name my-app \
#             --konflux-component-name my-component \
#             --no-old-commits-run
#
# -------------------------------------------
# REQUIRED PARAMETERS:
# -------------------------------------------

# --konflux-scenario-name <name>    Name of the Konflux integration test scenario.
# --konflux-tenant-name <name>      Konflux workspace where application, component and integration test scenario are created.
# --konflux-application-name <name> The name of the Konflux application being tested.
# --konflux-component-name <name>   The component name that will be trigger the scenario.
#
# -------------------------------------------
# OPTIONAL FLAGS:
# -------------------------------------------
# --schedule <time>                 Time interval for scheduling the test (e.g., 5d, 3h, 30m).
# --repository-url <url>            The GitHub repository URL to monitor.
# --branch <branch>                 The branch to check for updates.
# --no-old-commits-run              If set, tests will only run if new commits are detected.
#
###############################################################################

cd "$(mktemp -d)"

export SCHEDULE=""
export REPO_URL=""
export BRANCH=""
export KONFLUX_SCENARIO_NAME=""
export KONFLUX_TENANT_NAME=""
export KONFLUX_APPLICATION_NAME=""
export KONFLUX_COMPONENT_NAME=""
export NO_OLD_COMMITS_RUN="false"

show_help() {
    echo -e "\nUsage: $0 --schedule <time> --repository-url <url> --branch <branch> \\"
    echo "         --konflux-scenario-name <name> --konflux-tenant-name <name> \\"
    echo "         --konflux-application-name <name> --konflux-component-name <name> [options]"
    echo
    echo "Required flags:"
    echo "  --konflux-scenario-name <name>     Indicates the konflux integration test scenario name. This scenario must be created before executing this script."
    echo "  --konflux-tenant-name <name>       The namespace where your application, component and scenario are created."
    echo "  --konflux-application-name <name>  The name of your konflux application."
    echo "  --konflux-component-name <name>    Konflux component name where the Integration Test scenario will be executed."
    echo
    echo "Optional flags:"
    echo "  --schedule <time>                  Time format: Nd, Nh, Nm (e.g., 5d, 3h, 30m). This value must match the schedule format used in CronJobs. For example Cronjob schedule: 0 0 */2 * * then the flag value should be 2d."
    echo "  --repository-url <url>             GitHub repository URL,"
    echo "  --branch <branch>                  Repository branch name,"
    echo "  --no-old-commits-run               Skip the trigger Integration Tests if there are no recent commits compared with --scheduled flag."
    exit 1
}

calculate_past_time() {
    local input="$1"

    if ! [[ $input =~ ^[0-9]+[dhm]$ ]]; then
        echo "[ERROR] Invalid format. Use a number followed by 'd' (days), 'h' (hours), or 'm' (minutes)." >&2
        show_help
    fi

    local num=${input//[!0-9]/}
    local unit=${input//[0-9]/}

    case "$unit" in
        d) seconds=$((num * 86400)) ;;
        h) seconds=$((num * 3600))  ;;
        m) seconds=$((num * 60))    ;;
    esac

    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -v-"${num}${unit}" +"%Y-%m-%d %H:%M:%S"
    else
        date -d "@$(( $(date +%s) - seconds ))" +"%Y-%m-%d %H:%M:%S"
    fi
}

clone_repository() {
    local repo_url="$1"
    local branch="$2"

    if ! [[ $repo_url =~ ^https://github\.com/[^/]+/[^/]+/?$ ]]; then
        echo "[ERROR] Invalid GitHub repository URL."
        show_help
    fi

    echo "[INFO] Cloning repository: $repo_url (Branch: $branch)"
    git clone --branch "$branch" "$repo_url" .
}

check_recent_commits() {
    local since_time="$1"
    local commit_count
    commit_count=$(git rev-list --count --since="$since_time" HEAD)

    if [[ "$commit_count" -eq 0 ]]; then
        echo "[WARN] Trigger of periodic integration tests will be cancelled due to no commits in the last $SCHEDULE."
        exit 0
    fi
}

trigger_integration_tests() {
    local scenario="$1"
    local tenant="$2"
    local application="$3"
    local component="$4"

    echo -e "[INFO] Fetching latest snapshot from ${tenant} related to push events."

    LATEST_SNAPSHOT=$(kubectl get snapshots -n "${tenant}" -o json | \
        jq --arg application "$application" --arg component "$component" -r '
            .items
            | map(select(
                .metadata.labels."appstudio.openshift.io/application" == $application and
                .metadata.labels."appstudio.openshift.io/component" == $component and
                .metadata.labels."pac.test.appstudio.openshift.io/event-type" == "push" and
                (.status.conditions // [] | map(select(
                    .type == "AutoReleased" and
                    .reason == "AutoReleased" and
                    .status == "True"
                    ))
                | length > 0)
            ))
            | sort_by(.metadata.creationTimestamp) | last | .metadata.name')

    if [[ -z "${LATEST_SNAPSHOT}" || "${LATEST_SNAPSHOT}" == "null" ]]; then
        echo -e "[ERROR] No valid snapshot found. The job will not be triggered."
        exit 1
    fi

    echo -e "[INFO] Triggering test scenario ${scenario} from snapshot ${LATEST_SNAPSHOT}."

    kubectl -n "${tenant}" label snapshot "${LATEST_SNAPSHOT}" test.appstudio.openshift.io/run="${scenario}"

    echo "[INFO] The test scenario successfully triggered!"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --schedule)
            SCHEDULE="$2"
            shift 2
            ;;
        --repository-url)
            REPO_URL="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --konflux-scenario-name)
            KONFLUX_SCENARIO_NAME="$2"
            shift 2
            ;;
        --konflux-tenant-name)
            KONFLUX_TENANT_NAME="$2"
            shift 2
            ;;
        --konflux-application-name)
            KONFLUX_APPLICATION_NAME="$2"
            shift 2
            ;;
        --konflux-component-name)
            KONFLUX_COMPONENT_NAME="$2"
            shift 2
            ;;
        --no-old-commits-run)
            NO_OLD_COMMITS_RUN="true"
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Invalid option: $1"
            show_help
            ;;
    esac
done

if [[ -z "$KONFLUX_SCENARIO_NAME" || -z "$KONFLUX_TENANT_NAME" || -z "$KONFLUX_APPLICATION_NAME" || -z "$KONFLUX_COMPONENT_NAME" ]]; then
    echo -e "[ERROR] Missing required flags for Konflux test execution.\n"
    show_help
fi

if [[ -n "$SCHEDULE" && ( -z "$REPO_URL" || -z "$BRANCH" || -z "$NO_OLD_COMMITS_RUN" ) ]]; then
    echo -e "[ERROR] --repository-url, --no-old-commits-run and --branch are required when --schedule flag is specified.\n"
    show_help
fi

# Run repository related logic only if --schedule flag is provided
if [[ -n "$SCHEDULE" && "$NO_OLD_COMMITS_RUN" == "true" ]]; then
    SINCE_TIME=$(calculate_past_time "$SCHEDULE")
    echo "[INFO] Checking for commits since: $SINCE_TIME"

    clone_repository "$REPO_URL" "$BRANCH"
    check_recent_commits "$SINCE_TIME"
fi

# Trigger the integration tests
trigger_integration_tests "$KONFLUX_SCENARIO_NAME" "$KONFLUX_TENANT_NAME" "$KONFLUX_APPLICATION_NAME" "$KONFLUX_COMPONENT_NAME"
