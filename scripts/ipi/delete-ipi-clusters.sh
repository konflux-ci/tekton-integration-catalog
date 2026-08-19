#!/bin/bash

# Description: Sweeper for stranded AWS IPI clusters left behind by the
# konflux-ci-ipi Prow workflow. openshift-install tags every resource it
# creates with "kubernetes.io/cluster/<infra-id>=owned"; this script finds
# infra-ids matching the ci-op-* prefix via that tag and tears down all
# dependent resources for any cluster older than AGE_LIMIT_SECONDS.

# errexit is enabled, but this remains a best-effort sweeper: every AWS call
# below that we intend to tolerate failing (permission blips, resources
# already gone, still-detaching dependencies, deletion timeouts, etc.) is
# explicitly guarded with `|| true` or an inline warning, so one resource's
# failure never aborts the rest of the sweep across other clusters/regions.
set -o errexit -o nounset -o pipefail

# --- Configuration ---
TAG_KEY_PATTERN="kubernetes.io/cluster/ci-op-*"
INFRA_ID_PREFIX="ci-op-"
# 24h (86400 seconds) — longer than any of the three IPI e2e periodics take
# to run, so in-flight nightlies are never targeted.
AGE_LIMIT_SECONDS="${AGE_LIMIT_SECONDS:-86400}"
if ! [[ "$AGE_LIMIT_SECONDS" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] AGE_LIMIT_SECONDS must be a non-negative integer, got: $AGE_LIMIT_SECONDS"
    exit 1
fi

# --- Command Line Argument Handling ---
usage() {
    echo "Usage: $0 [--dry-run|-d]"
    echo "  --dry-run, -d   Report what would be deleted, without deleting anything."
    echo "  (no argument)   DESTRUCTIVE: actually delete stranded resources."
    exit 1
}

if [ "$#" -gt 1 ]; then
    echo "[ERROR] Too many arguments: $*" >&2
    usage
fi

DRY_RUN=false
case "${1:-}" in
    "") ;;
    --dry-run | -d)
        DRY_RUN=true
        ;;
    *)
        echo "[ERROR] Unknown argument: '$1'. Refusing to run in destructive mode on an unrecognized flag." >&2
        usage
        ;;
esac

if $DRY_RUN; then
    echo "=========================================================="
    echo "⚠️  DRY-RUN MODE ENABLED: NO RESOURCES WILL BE DELETED ⚠️"
    echo "=========================================================="
fi

check_required_tools() {
    if ! command -v aws &> /dev/null; then
        echo "[ERROR] aws command not found. Please install the AWS CLI."
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "[ERROR] jq command not found. Please install jq."
        exit 1
    fi
}

# --- Counters (grand totals across all regions/clusters) ---
total_clusters=0
total_vpcs=0
total_ec2s=0
total_eips=0
total_volumes=0
total_subnets=0
total_sgs=0
total_endpoints=0
total_rts=0
total_igws=0
total_enis=0
total_peering=0
total_acls=0
total_vpns=0
total_carriers=0
total_lgw_assoc=0
total_lbs=0
total_nats=0
# infra-ids where the tag was found but no VPC/EC2/NAT/EIP/volume exists —
# collected here instead of printed inline, so the per-region scan stays
# readable and these stale tag-index entries get one consolidated summary.
declare -a ghost_clusters=()

get_age_seconds() {
    local timestamp="$1"
    local epoch_time
    epoch_time=$(date -u -d "$timestamp" +%s 2>/dev/null) || true
    local current_epoch
    current_epoch=$(date +%s) || true

    if [ -z "$epoch_time" ] || [ "$epoch_time" -eq 0 ]; then
        echo "   [WARNING] Could not parse timestamp '$timestamp'; treating age as 0 (will be skipped)." >&2
        echo 0
    else
        echo $((current_epoch - epoch_time))
    fi
}

# Returns 1 on timeout (resource still present after max_attempts) — this is
# a meaningful signal for callers who may want to branch on it, but it means
# every call site MUST be guarded with `|| true` (or an equivalent), since
# errexit is enabled and a bare non-zero return here would otherwise abort
# the whole sweep just because one resource was slow to delete.
wait_for_resource_deletion() {
    local type="$1"
    local id="$2"
    local region="$3"
    local max_attempts=30 # Max 5 minutes (30 * 10 seconds)
    local interval=10
    local attempts=0

    if $DRY_RUN; then
        return 0
    fi

    echo "   [PAUSE] Polling until $type $id is deleted (max 5 min)..."

    while [ "$attempts" -lt "$max_attempts" ]; do
        attempts=$((attempts + 1))
        local exists_check=""
        case "$type" in
            ENI)
                exists_check=$(aws ec2 describe-network-interfaces --region "$region" --network-interface-ids "$id" --query 'NetworkInterfaces[0].NetworkInterfaceId' --output text 2>/dev/null) || true
                ;;
            LB)
                exists_check=$(aws elbv2 describe-load-balancers --region "$region" --load-balancer-arns "$id" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null) || true
                ;;
            CLASSIC_LB)
                exists_check=$(aws elb describe-load-balancers --region "$region" --load-balancer-names "$id" --query 'LoadBalancerDescriptions[0].LoadBalancerName' --output text 2>/dev/null) || true
                ;;
            NAT_GW)
                exists_check=$(aws ec2 describe-nat-gateways --region "$region" --nat-gateway-ids "$id" --query 'NatGateways[0].State' --output text 2>/dev/null) || true
                if [ "$exists_check" == "deleted" ]; then
                    exists_check=""
                fi
                ;;
            EC2)
                exists_check=$(aws ec2 describe-instances --region "$region" --instance-ids "$id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null) || true
                if [ "$exists_check" == "terminated" ]; then
                    exists_check=""
                fi
                ;;
            *)
                return 0
                ;;
        esac

        if [ "$exists_check" == "None" ] || [ -z "$exists_check" ]; then
            echo "   [CONTINUE] $type $id confirmed deleted after $attempts attempts."
            return 0
        fi

        sleep "$interval"
    done

    echo "   [WARNING] $type $id did not delete within the time limit. Continuing cleanup."
    return 1
}

# Execute deletion logic for a single resource. Counters are updated by the caller.
delete_resource() {
    local type="$1"
    local id="$2"
    local region="$3"
    local creation_time="$4"
    local delete_cmd=()

    case "$type" in
        VPC)
            delete_cmd=(aws ec2 delete-vpc --region "$region" --vpc-id "$id")
            ;;
        EC2)
            delete_cmd=(aws ec2 terminate-instances --region "$region" --instance-ids "$id")
            ;;
        EIP)
            delete_cmd=(aws ec2 release-address --region "$region" --allocation-id "$id")
            ;;
        VOLUME)
            delete_cmd=(aws ec2 delete-volume --region "$region" --volume-id "$id")
            ;;
        ENI)
            if ! $DRY_RUN; then
                local attachment_id
                attachment_id=$(aws ec2 describe-network-interfaces --region "$region" --network-interface-ids "$id" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null) || true
                if [ "$attachment_id" != "None" ] && [ -n "$attachment_id" ]; then
                    echo "   [DELETE] Detaching ENI $id ($attachment_id) in $region..."
                    aws ec2 detach-network-interface --region "$region" --attachment-id "$attachment_id" || true
                    # detach-network-interface is async; deleting immediately after
                    # frequently races AWS and fails with "IncorrectState: has
                    # attachments", so wait for the detach to actually land first.
                    aws ec2 wait network-interface-available --region "$region" --network-interface-ids "$id" || true
                fi
            fi
            delete_cmd=(aws ec2 delete-network-interface --region "$region" --network-interface-id "$id")
            ;;
        IGW)
            if ! $DRY_RUN; then
                local vpc_id_to_detach
                vpc_id_to_detach=$(aws ec2 describe-internet-gateways --region "$region" --internet-gateway-ids "$id" --query 'InternetGateways[0].Attachments[0].VpcId' --output text 2>/dev/null) || true
                if [ "$vpc_id_to_detach" != "None" ] && [ -n "$vpc_id_to_detach" ]; then
                    echo "   [DELETE] Detaching IGW $id from VPC $vpc_id_to_detach in $region..."
                    aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$id" --vpc-id "$vpc_id_to_detach" || true
                fi
            fi
            delete_cmd=(aws ec2 delete-internet-gateway --region "$region" --internet-gateway-id "$id")
            ;;
        RT)
            if ! $DRY_RUN; then
                local assoc_ids
                assoc_ids=$(aws ec2 describe-route-tables --region "$region" --route-table-ids "$id" --query 'RouteTables[0].Associations[?Main != `true`].RouteTableAssociationId' --output text 2>/dev/null) || true
                for assoc_id in $assoc_ids; do
                    echo "   [DELETE] Disassociating Route Table $id from subnet ($assoc_id)..."
                    aws ec2 disassociate-route-table --region "$region" --association-id "$assoc_id" || true
                done
            fi
            delete_cmd=(aws ec2 delete-route-table --region "$region" --route-table-id "$id")
            ;;
        SUBNET)
            delete_cmd=(aws ec2 delete-subnet --region "$region" --subnet-id "$id")
            ;;
        SG)
            delete_cmd=(aws ec2 delete-security-group --region "$region" --group-id "$id")
            ;;
        ENDPOINT)
            delete_cmd=(aws ec2 delete-vpc-endpoints --region "$region" --vpc-endpoint-ids "$id")
            ;;
        PEERING)
            delete_cmd=(aws ec2 delete-vpc-peering-connection --region "$region" --vpc-peering-connection-id "$id")
            ;;
        ACL)
            delete_cmd=(aws ec2 delete-network-acl --region "$region" --network-acl-id "$id")
            ;;
        VPN_GW)
            if ! $DRY_RUN; then
                local vpn_vpc_id_to_detach
                vpn_vpc_id_to_detach=$(aws ec2 describe-vpn-gateways --region "$region" --vpn-gateway-ids "$id" --query 'VpnGateways[0].VpcAttachments[?State==`attached`].VpcId | [0]' --output text 2>/dev/null) || true
                if [ "$vpn_vpc_id_to_detach" != "None" ] && [ -n "$vpn_vpc_id_to_detach" ]; then
                    echo "   [DELETE] Detaching VPN Gateway $id from VPC $vpn_vpc_id_to_detach in $region..."
                    aws ec2 detach-vpn-gateway --region "$region" --vpn-gateway-id "$id" --vpc-id "$vpn_vpc_id_to_detach" || true
                fi
            fi
            delete_cmd=(aws ec2 delete-vpn-gateway --region "$region" --vpn-gateway-id "$id")
            ;;
        CARRIER_GW)
            delete_cmd=(aws ec2 delete-carrier-gateway --region "$region" --carrier-gateway-id "$id")
            ;;
        LGW_ASSOC)
            delete_cmd=(aws ec2 delete-local-gateway-route-table-vpc-association --region "$region" --local-gateway-route-table-vpc-association-id "$id")
            ;;
        LB)
            delete_cmd=(aws elbv2 delete-load-balancer --region "$region" --load-balancer-arn "$id")
            ;;
        CLASSIC_LB)
            delete_cmd=(aws elb delete-load-balancer --region "$region" --load-balancer-name "$id")
            ;;
        NAT_GW)
            delete_cmd=(aws ec2 delete-nat-gateway --region "$region" --nat-gateway-id "$id")
            ;;
        *)
            echo "   [ERROR] Unknown resource type: $type"
            return
            ;;
    esac

    if $DRY_RUN; then
        echo "   [DRY-RUN] Would delete $type $id ($creation_time) in $region."
    else
        echo "   [DELETE] Deleting $type $id ($creation_time) in $region..."
        "${delete_cmd[@]}" || echo "   [WARNING] Failed to delete $type $id (may already be gone or have dependents). Continuing."
    fi
}

# Determine how old a stranded cluster is. Prefers EC2 instance launch time
# (bootstrap/master/worker nodes are usually still present on a leaked
# cluster), falls back to the VPC's CloudTrail CreateVpc event, and finally
# assumes "older than 90-day retention" if neither is available — matching
# the fallback used for orphaned mapt VPCs.
get_cluster_age_seconds() {
    local region="$1"
    local infra_id="$2"
    local tag_filter="Name=tag-key,Values=kubernetes.io/cluster/${infra_id}"

    # The stale-fallback below only fires when every query we relied on to
    # rule out a signal actually SUCCEEDED (rc=0) and came back empty. If a
    # query fails outright (throttling, transient permission blip, etc.), an
    # active cluster looks identical to a "no signal, must be old" cluster —
    # so a failed query must never be treated as "confirmed absent"; it must
    # produce UNKNOWN and let the caller skip it.
    local newest_launch ec2_rc=0
    newest_launch=$(aws ec2 describe-instances --region "$region" --filters "$tag_filter" \
        --query 'Reservations[].Instances[].LaunchTime' --output text 2>/dev/null | tr '\t' '\n' | sort -r | head -n1) || ec2_rc=$?

    if [ "$ec2_rc" -ne 0 ]; then
        echo "UNKNOWN"
        return
    fi

    if [ -n "$newest_launch" ] && [ "$newest_launch" != "None" ]; then
        get_age_seconds "$newest_launch"
        return
    fi

    local vpc_id vpc_rc=0
    vpc_id=$(aws ec2 describe-vpcs --region "$region" --filters "$tag_filter" --query 'Vpcs[0].VpcId' --output text 2>/dev/null) || vpc_rc=$?

    if [ "$vpc_rc" -ne 0 ]; then
        echo "UNKNOWN"
        return
    fi

    if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
        local vpc_create_time ct_rc=0
        vpc_create_time=$(aws cloudtrail lookup-events --region "$region" \
            --lookup-attributes "AttributeKey=ResourceName,AttributeValue=$vpc_id" \
            --query "Events[?EventName=='CreateVpc'].EventTime | [0]" --output text 2>/dev/null) || ct_rc=$?

        if [ "$ct_rc" -ne 0 ]; then
            echo "UNKNOWN"
            return
        fi

        if [ -n "$vpc_create_time" ] && [ "$vpc_create_time" != "None" ]; then
            get_age_seconds "$vpc_create_time"
            return
        fi
        # VPC confirmed to exist (successful query) but has no CreateVpc
        # event within CloudTrail's retention window (~90d) — genuinely
        # old, not an API failure, so falling through to stale is safe.
    fi

    # Reached only when EC2 (and VPC, if one exists) queries succeeded and
    # confirmed no usable age signal — genuinely stale, not a query failure.
    echo $((AGE_LIMIT_SECONDS + 1))
}

# Tear down every dependent resource for a single infra-id, in dependency-safe order.
cleanup_cluster() {
    local region="$1"
    local infra_id="$2"
    local age_seconds="$3"
    local tag_filter="Name=tag-key,Values=kubernetes.io/cluster/${infra_id}"

    echo "  --------------------------------------------------"
    echo "  ✅ STRANDED IPI CLUSTER FOUND: $infra_id"
    echo "     Region: $region"
    echo "     Age: $((age_seconds / 3600))h (limit: $((AGE_LIMIT_SECONDS / 3600))h)"

    local vpc_id
    vpc_id=$(aws ec2 describe-vpcs --region "$region" --filters "$tag_filter" --query 'Vpcs[0].VpcId' --output text 2>/dev/null) || true
    [ "$vpc_id" == "None" ] && vpc_id=""

    # Tracks whether any of the tag-scoped (VPC-independent) checks below
    # actually found something. If a cluster has no VPC AND none of these
    # find anything either, the tag that got it discovered in the first
    # place is almost certainly a stale/lagging entry in AWS's tag index for
    # a resource that's already fully gone — not an active leak.
    local resources_found_via_tag=0

    # --- Load Balancers (must go before ENI/EIP so their managed ENIs free up) ---
    if [ -n "$vpc_id" ]; then
        local lbs_arns
        lbs_arns=$(aws elbv2 describe-load-balancers --region "$region" --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" --output text 2>/dev/null) || true
        for lb_arn in $lbs_arns; do
            delete_resource "LB" "$lb_arn" "$region" "$infra_id"
            wait_for_resource_deletion "LB" "$lb_arn" "$region" || true
            total_lbs=$((total_lbs + 1))
        done

        local classic_lbs
        classic_lbs=$(aws elb describe-load-balancers --region "$region" --query "LoadBalancerDescriptions[?VPCId=='$vpc_id'].LoadBalancerName" --output text 2>/dev/null) || true
        for clb_name in $classic_lbs; do
            delete_resource "CLASSIC_LB" "$clb_name" "$region" "$infra_id"
            wait_for_resource_deletion "CLASSIC_LB" "$clb_name" "$region" || true
            total_lbs=$((total_lbs + 1))
        done
    fi

    # --- EC2 Instances (bootstrap/master/worker) ---
    local ec2_ids
    ec2_ids=$(aws ec2 describe-instances --region "$region" --filters "$tag_filter" \
        --query 'Reservations[].Instances[?State.Name!=`terminated`].InstanceId' --output text 2>/dev/null) || true
    for ec2_id in $ec2_ids; do
        delete_resource "EC2" "$ec2_id" "$region" "$infra_id"
        wait_for_resource_deletion "EC2" "$ec2_id" "$region" || true
        total_ec2s=$((total_ec2s + 1))
        resources_found_via_tag=$((resources_found_via_tag + 1))
    done

    # --- NAT Gateways ---
    local nat_gw_ids
    nat_gw_ids=$(aws ec2 describe-nat-gateways --region "$region" --filter "$tag_filter" \
        --query 'NatGateways[?State==`available`].NatGatewayId' --output text 2>/dev/null) || true
    for nat_gw_id in $nat_gw_ids; do
        delete_resource "NAT_GW" "$nat_gw_id" "$region" "$infra_id"
        wait_for_resource_deletion "NAT_GW" "$nat_gw_id" "$region" || true
        total_nats=$((total_nats + 1))
        resources_found_via_tag=$((resources_found_via_tag + 1))
    done

    # --- Elastic Network Interfaces + associated EIPs ---
    if [ -n "$vpc_id" ]; then
        local vpc_filter="Name=vpc-id,Values=$vpc_id"
        local enis
        enis=$(aws ec2 describe-network-interfaces --region "$region" --filters "$vpc_filter" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null) || true
        for eni_id in $enis; do
            local eips_data
            eips_data=$(aws ec2 describe-addresses --region "$region" --query "Addresses[?NetworkInterfaceId=='$eni_id'].AllocationId" --output text 2>/dev/null) || true
            for eip_alloc_id in $eips_data; do
                delete_resource "EIP" "$eip_alloc_id" "$region" "$infra_id"
                total_eips=$((total_eips + 1))
            done
            delete_resource "ENI" "$eni_id" "$region" "$infra_id"
            total_enis=$((total_enis + 1))
        done
    fi

    # --- Standalone EIPs tagged directly with this infra-id (e.g. bootstrap EIP) ---
    local standalone_eips
    standalone_eips=$(aws ec2 describe-addresses --region "$region" --filters "$tag_filter" \
        --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null) || true
    for eip_alloc_id in $standalone_eips; do
        delete_resource "EIP" "$eip_alloc_id" "$region" "$infra_id"
        total_eips=$((total_eips + 1))
        resources_found_via_tag=$((resources_found_via_tag + 1))
    done

    # --- Standalone EBS volumes tagged directly with this infra-id. These
    # aren't part of openshift-install's base VPC/EC2 infra (so they aren't
    # caught by the VPC-scoped checks below), but the in-cluster EBS CSI
    # driver tags dynamically-provisioned PVC volumes with the cluster tag,
    # and a node's root volume can outlive its instance's termination if
    # Delete-on-Termination wasn't set. Only "available" (unattached)
    # volumes are targeted — an in-use volume means something is still
    # actively attached to it, which shouldn't happen for a stale cluster
    # but is a signal to leave it alone rather than force anything.
    local standalone_volumes
    standalone_volumes=$(aws ec2 describe-volumes --region "$region" --filters "$tag_filter" \
        --query 'Volumes[?State==`available`].VolumeId' --output text 2>/dev/null) || true
    for volume_id in $standalone_volumes; do
        delete_resource "VOLUME" "$volume_id" "$region" "$infra_id"
        total_volumes=$((total_volumes + 1))
        resources_found_via_tag=$((resources_found_via_tag + 1))
    done

    if [ -n "$vpc_id" ]; then
        local vpc_filter="Name=vpc-id,Values=$vpc_id"

        local endpoints
        endpoints=$(aws ec2 describe-vpc-endpoints --region "$region" --filters "$vpc_filter" --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null) || true
        for ep_id in $endpoints; do
            delete_resource "ENDPOINT" "$ep_id" "$region" "$infra_id"
            total_endpoints=$((total_endpoints + 1))
        done

        local peering_conns
        peering_conns=$(aws ec2 describe-vpc-peering-connections --region "$region" --filters "Name=requester-vpc-info.vpc-id,Values=$vpc_id" --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text 2>/dev/null) || true
        for pcx_id in $peering_conns; do
            delete_resource "PEERING" "$pcx_id" "$region" "$infra_id"
            total_peering=$((total_peering + 1))
        done

        local vpn_gws
        vpn_gws=$(aws ec2 describe-vpn-gateways --region "$region" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'VpnGateways[].VpnGatewayId' --output text 2>/dev/null) || true
        for vpn_id in $vpn_gws; do
            delete_resource "VPN_GW" "$vpn_id" "$region" "$infra_id"
            total_vpns=$((total_vpns + 1))
        done

        local carrier_gws
        carrier_gws=$(aws ec2 describe-carrier-gateways --region "$region" --filters "$vpc_filter" --query 'CarrierGateways[].CarrierGatewayId' --output text 2>/dev/null) || true
        for carrier_id in $carrier_gws; do
            delete_resource "CARRIER_GW" "$carrier_id" "$region" "$infra_id"
            total_carriers=$((total_carriers + 1))
        done

        local lgw_assocs
        lgw_assocs=$(aws ec2 describe-local-gateway-route-table-vpc-associations --region "$region" --filters "$vpc_filter" --query 'LocalGatewayRouteTableVpcAssociations[].LocalGatewayRouteTableVpcAssociationId' --output text 2>/dev/null) || true
        for assoc_id in $lgw_assocs; do
            delete_resource "LGW_ASSOC" "$assoc_id" "$region" "$infra_id"
            total_lgw_assoc=$((total_lgw_assoc + 1))
        done

        local igws
        igws=$(aws ec2 describe-internet-gateways --region "$region" --query "InternetGateways[?Attachments[0].VpcId=='$vpc_id'].InternetGatewayId" --output text 2>/dev/null) || true
        for igw_id in $igws; do
            delete_resource "IGW" "$igw_id" "$region" "$infra_id"
            total_igws=$((total_igws + 1))
        done

        local rts
        rts=$(aws ec2 describe-route-tables --region "$region" --query "RouteTables[?VpcId=='$vpc_id'].RouteTableId" --output text 2>/dev/null) || true
        for rt_id in $rts; do
            local is_main
            is_main=$(aws ec2 describe-route-tables --region "$region" --route-table-ids "$rt_id" --query 'RouteTables[0].Associations[?Main == `true`].Main' --output text 2>/dev/null) || true
            if [ -z "$is_main" ]; then
                delete_resource "RT" "$rt_id" "$region" "$infra_id"
                total_rts=$((total_rts + 1))
            fi
        done

        local acls
        acls=$(aws ec2 describe-network-acls --region "$region" --filters "$vpc_filter" --query 'NetworkAcls[?IsDefault == `false`].NetworkAclId' --output text 2>/dev/null) || true
        for acl_id in $acls; do
            delete_resource "ACL" "$acl_id" "$region" "$infra_id"
            total_acls=$((total_acls + 1))
        done

        local subnets
        subnets=$(aws ec2 describe-subnets --region "$region" --filters "$vpc_filter" --query 'Subnets[].SubnetId' --output text 2>/dev/null) || true
        for subnet_id in $subnets; do
            delete_resource "SUBNET" "$subnet_id" "$region" "$infra_id"
            total_subnets=$((total_subnets + 1))
        done

        local sgs
        sgs=$(aws ec2 describe-security-groups --region "$region" --filters "$vpc_filter" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null) || true

        # Revoke cross-referencing rules first: IPI clusters' master/worker/
        # bootstrap SGs mutually reference each other via UserIdGroupPairs in
        # their ingress/egress rules, so AWS refuses to delete either SG
        # while the other's rule still references it. Without this pass,
        # every SG deletion below fails with DependencyViolation and neither
        # SG ever gets cleaned up.
        if ! $DRY_RUN; then
            for sg_id in $sgs; do
                local ingress_refs
                ingress_refs=$(aws ec2 describe-security-groups --region "$region" --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissions[?length(UserIdGroupPairs) > `0`]' --output json 2>/dev/null) || true
                if [ -n "$ingress_refs" ] && [ "$ingress_refs" != "null" ] && [ "$ingress_refs" != "[]" ]; then
                    echo "   [DELETE] Revoking cross-referencing ingress rules on SG $sg_id in $region..."
                    aws ec2 revoke-security-group-ingress --region "$region" --group-id "$sg_id" --ip-permissions "$ingress_refs" || true
                fi

                local egress_refs
                egress_refs=$(aws ec2 describe-security-groups --region "$region" --group-ids "$sg_id" \
                    --query 'SecurityGroups[0].IpPermissionsEgress[?length(UserIdGroupPairs) > `0`]' --output json 2>/dev/null) || true
                if [ -n "$egress_refs" ] && [ "$egress_refs" != "null" ] && [ "$egress_refs" != "[]" ]; then
                    echo "   [DELETE] Revoking cross-referencing egress rules on SG $sg_id in $region..."
                    aws ec2 revoke-security-group-egress --region "$region" --group-id "$sg_id" --ip-permissions "$egress_refs" || true
                fi
            done
        fi

        for sg_id in $sgs; do
            delete_resource "SG" "$sg_id" "$region" "$infra_id"
            total_sgs=$((total_sgs + 1))
        done

        delete_resource "VPC" "$vpc_id" "$region" "$infra_id"
        total_vpcs=$((total_vpcs + 1))
    elif [ "$resources_found_via_tag" -gt 0 ]; then
        echo "  ℹ️  No VPC found for $infra_id (already deleted?) — dependent resources cleaned via direct tag lookups only."
    else
        echo "  👻 $infra_id — no VPC, no resources found (likely a stale tag-index entry; see summary at the end)."
        ghost_clusters+=("$region/$infra_id")
    fi

    total_clusters=$((total_clusters + 1))
}

main() {
    check_required_tools

    echo "Searching for stranded IPI clusters (Tag key matching: $TAG_KEY_PATTERN, Older than $AGE_LIMIT_SECONDS seconds)..."
    echo "--------------------------------------------------------"

    # Intentionally NOT guarded: if this fails (bad/missing credentials,
    # region-listing permission denied), fail loudly and stop rather than
    # silently completing with "0 clusters found" everywhere.
    local regions
    regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

    for region in $regions; do
        echo "Checking region: $region"

        # describe-tags supports "*" wildcards on filter values, so this finds
        # every "kubernetes.io/cluster/ci-op-<id>" tag key in one call without
        # needing to know infra-ids up front.
        local infra_ids
        infra_ids=$(aws ec2 describe-tags --region "$region" \
            --filters "Name=key,Values=${TAG_KEY_PATTERN}" \
            --query 'Tags[].Key' --output text 2>/dev/null | tr '\t' '\n' | sed "s#^kubernetes.io/cluster/##" | sort -u) || true

        if [ -z "$infra_ids" ]; then
            echo "  No stranded ${INFRA_ID_PREFIX}* clusters found in $region."
            echo
            continue
        fi

        while read -r infra_id; do
            [ -z "$infra_id" ] && continue

            local age_seconds
            age_seconds=$(get_cluster_age_seconds "$region" "$infra_id")

            if [ "$age_seconds" == "UNKNOWN" ]; then
                echo "  ⚠️  Could not reliably determine age for $infra_id (an AWS query failed) — skipping for safety, will retry next run."
            elif [ "$age_seconds" -gt "$AGE_LIMIT_SECONDS" ]; then
                cleanup_cluster "$region" "$infra_id" "$age_seconds"
            else
                echo "  ⏳ Skipping $infra_id — $((age_seconds / 3600))h old (< $((AGE_LIMIT_SECONDS / 3600))h limit, likely in-flight)"
            fi
        done <<< "$infra_ids"

        echo
    done

    echo "--------------------------------------------------------"
    echo "GRAND TOTALS for stranded ${INFRA_ID_PREFIX}* IPI clusters"
    echo "  Total clusters targeted:      $total_clusters"
    echo "  Total VPCs targeted:          $total_vpcs"
    echo "  Total Load Balancers targeted: $total_lbs"
    echo "  Total NAT Gateways targeted:  $total_nats"
    echo "  Total EC2 Instances targeted: $total_ec2s"
    echo "  Total Elastic Network Interfaces targeted: $total_enis"
    echo "  Total VPC Endpoints targeted: $total_endpoints"
    echo "  Total VPC Peering Connections targeted: $total_peering"
    echo "  Total VPN Gateways targeted:  $total_vpns"
    echo "  Total Carrier Gateways targeted: $total_carriers"
    echo "  Total LGW Route Table Assocs targeted: $total_lgw_assoc"
    echo "  Total Internet Gateways targeted: $total_igws"
    echo "  Total Route Tables targeted:  $total_rts"
    echo "  Total Network ACLs targeted:  $total_acls"
    echo "  Total Subnets targeted:       $total_subnets"
    echo "  Total Security Groups targeted: $total_sgs"
    echo "  Total Elastic IPs targeted:   $total_eips"
    echo "  Total EBS Volumes targeted:   $total_volumes"
    echo "--------------------------------------------------------"
    if [ "${#ghost_clusters[@]}" -gt 0 ]; then
        echo "👻 Likely stale tag-index entries (tag found, but no VPC/EC2/NAT/EIP/volume exists — nothing to clean up):"
        for ghost in "${ghost_clusters[@]}"; do
            echo "   - $ghost"
        done
        echo "These are almost certainly leftover entries in AWS's tag index for clusters already fully deleted elsewhere. Safe to ignore; they should stop appearing once the index catches up."
        echo "--------------------------------------------------------"
    fi
    if $DRY_RUN; then
        echo "Remember: DRY-RUN MODE was active. No resources were deleted."
    fi
}

main
