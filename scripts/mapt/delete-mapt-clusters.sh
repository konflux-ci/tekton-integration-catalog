#!/bin/bash

# --- Configuration ---
TAG_KEY="origin"
TAG_VALUE="mapt"
PROJECT_TAG_KEY="projectName" 
FILTER="Name=tag:$TAG_KEY,Values=$TAG_VALUE"
# 1 day (86400 seconds)
AGE_LIMIT_SECONDS=$((24 * 60 * 60)) 

# --- Command Line Argument Handling ---
DRY_RUN=false
if [[ "$1" == "--dry-run" || "$1" == "-d" ]]; then
    DRY_RUN=true
    echo "=========================================================="
    echo "⚠️  DRY-RUN MODE ENABLED: NO RESOURCES WILL BE DELETED ⚠️"
    echo "=========================================================="
fi

# --- Counters ---
total_vpcs=0
total_ec2s=0
total_eips=0
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

echo "Searching for resources with Tag: $TAG_KEY=$TAG_VALUE (Older than $AGE_LIMIT_SECONDS seconds)..."
echo "--------------------------------------------------------"

# Get a list of all active AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

# Function to calculate age in seconds from a timestamp (YYYY-MM-DDTHH:MM:SSZ)
get_age_seconds() {
    local timestamp="$1"
    local epoch_time=$(date -u -d "$timestamp" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    
    if [ -z "$epoch_time" ] || [ "$epoch_time" -eq 0 ]; then
        echo 0
    else
        echo $((current_epoch - epoch_time))
    fi
}

# Function to poll the AWS CLI until a resource is confirmed deleted
wait_for_resource_deletion() {
    local type="$1"
    local id="$2"
    local region="$3"
    local max_attempts=30 # Max 5 minutes (30 * 10 seconds)
    local interval=10     # Poll every 10 seconds
    local attempts=0

    if $DRY_RUN; then
        return 0 # Skip polling in dry-run mode
    fi

    echo "   [PAUSE] Polling until $type $id is deleted (max 5 min)..."
    
    while [ "$attempts" -lt "$max_attempts" ]; do
        attempts=$((attempts + 1))
        
        # Check if the resource still exists
        local exists_check=""
        case "$type" in
            ENI)
                exists_check=$(aws ec2 describe-network-interfaces --region "$region" --network-interface-ids "$id" --query 'NetworkInterfaces[0].NetworkInterfaceId' --output text 2>/dev/null)
                ;;
            # Add other complex polling checks here if needed (e.g., LB deletion)
            *)
                # For simplicity, if we don't have a dedicated check, we stop polling.
                return 0
                ;;
        esac

        if [ "$exists_check" == "None" ] || [ -z "$exists_check" ]; then
            echo "   [CONTINUE] $type $id confirmed deleted after $attempts attempts."
            return 0 # Success
        fi

        sleep "$interval"
    done
    
    echo "   [WARNING] $type $id did not delete within the time limit. Continuing cleanup."
    return 1 # Failure to confirm deletion
}

# Function to execute deletion logic
delete_resource() {
    local type="$1"
    local id="$2"
    local region="$3"
    local creation_time="$4"
    local delete_command=""

    # Deletion logic, using appropriate AWS CLI commands
    case "$type" in
        NAT_GW_PROXY)
            delete_command="aws ec2 delete-nat-gateway --region \"$region\" --nat-gateway-id \"$id\""
            ;;
        VPC)
            delete_command="aws ec2 delete-vpc --region \"$region\" --vpc-id \"$id\""
            ;;
        EC2)
            delete_command="aws ec2 terminate-instances --region \"$region\" --instance-ids \"$id\""
            ;;
        EIP)
            delete_command="aws ec2 release-address --region \"$region\" --allocation-id \"$id\""
            ;;
        ENI)
            if ! $DRY_RUN; then
                local attachment_id=$(aws ec2 describe-network-interfaces --region "$region" --network-interface-ids "$id" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null)
                if [ "$attachment_id" != "None" ] && [ -n "$attachment_id" ]; then
                    echo "   [DELETE] Detaching ENI $id ($attachment_id) in $region..."
                    aws ec2 detach-network-interface --region "$region" --attachment-id "$attachment_id"
                fi
            fi
            delete_command="aws ec2 delete-network-interface --region \"$region\" --network-interface-id \"$id\""
            ;;
        IGW)
            if ! $DRY_RUN; then
                local vpc_id_to_detach=$(aws ec2 describe-internet-gateways --region "$region" --internet-gateway-ids "$id" --query 'InternetGateways[0].Attachments[0].VpcId' --output text 2>/dev/null)
                if [ "$vpc_id_to_detach" != "None" ] && [ -n "$vpc_id_to_detach" ]; then
                    echo "   [DELETE] Detaching IGW $id from VPC $vpc_id_to_detach in $region..."
                    aws ec2 detach-internet-gateway --region "$region" --internet-gateway-id "$id" --vpc-id "$vpc_id_to_detach"
                fi
            fi
            delete_command="aws ec2 delete-internet-gateway --region \"$region\" --internet-gateway-id \"$id\""
            ;;
        RT)
            if ! $DRY_RUN; then
                local assoc_ids=$(aws ec2 describe-route-tables --region "$region" --route-table-ids "$id" --query 'RouteTables[0].Associations[?Main != `true`].RouteTableAssociationId' --output text 2>/dev/null)
                for assoc_id in $assoc_ids; do
                    echo "   [DELETE] Disassociating Route Table $id from subnet ($assoc_id)..."
                    aws ec2 disassociate-route-table --region "$region" --association-id "$assoc_id"
                done
            fi
            delete_command="aws ec2 delete-route-table --region \"$region\" --route-table-id \"$id\""
            ;;
        SUBNET)
            delete_command="aws ec2 delete-subnet --region \"$region\" --subnet-id \"$id\""
            ;;
        SG)
            delete_command="aws ec2 delete-security-group --region \"$region\" --group-id \"$id\""
            ;;
        ENDPOINT)
            delete_command="aws ec2 delete-vpc-endpoints --region \"$region\" --vpc-endpoint-ids \"$id\""
            ;;
        PEERING)
            delete_command="aws ec2 delete-vpc-peering-connection --region \"$region\" --vpc-peering-connection-id \"$id\""
            ;;
        ACL)
            delete_command="aws ec2 delete-network-acl --region \"$region\" --network-acl-id \"$id\""
            ;;
        VPN_GW)
            # Delete VPN Gateway relies on Detach happening first (handled by Delete command)
            delete_command="aws ec2 delete-vpn-gateway --region \"$region\" --vpn-gateway-id \"$id\""
            ;;
        CARRIER_GW)
            delete_command="aws ec2 delete-carrier-gateway --region \"$region\" --carrier-gateway-id \"$id\""
            ;;
        LGW_ASSOC)
            delete_command="aws ec2 delete-local-gateway-route-table-vpc-association --region \"$region\" --local-gateway-route-table-vpc-association-id \"$id\""
            ;;
        LB)
             delete_command="aws elbv2 delete-load-balancer --region \"$region\" --load-balancer-arn \"$id\""
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
        eval "$delete_command"
    fi
}


# Loop through each region
for region in $regions; do
  echo "Checking region: $region"
  
  # Initialize regional counters and storage for VPCs targeted for final deletion
  regional_vpc_count=0
  regional_vpcs_to_delete="" 
  
  regional_subnets=0
  regional_sgs=0
  regional_endpoints=0
  regional_rts=0
  regional_igws=0
  regional_ec2s=0
  regional_eips=0
  regional_enis=0 
  regional_peering=0
  regional_acls=0
  regional_vpns=0
  regional_carriers=0
  regional_lgw_assoc=0
  regional_lbs=0

  # -----------------------------------------------------------------
  # 1. VPC IDENTIFICATION (via NAT Gateway)
  # -----------------------------------------------------------------
  
  # 1.1 Get JSON data for tagged NAT Gateways
  nat_gateways_json=$(
    aws ec2 describe-nat-gateways \
      --region "$region" \
      --filter "$FILTER" \
      --output json 2>/dev/null
  )

  # 1.2 Use jq to extract available state and format as: vpc-id,create-time,nat-gw-id,project-name,nat_eni_id (Used for polling)
  # NOTE: Finding the NAT Gateway's ENI ID for polling
  nat_gateways_data=$(
    echo "$nat_gateways_json" | \
    jq -r '.NatGateways[] | select(.State == "available") | 
        .VpcId + "," + 
        .CreateTime + "," + 
        .NatGatewayId + "," + 
        (.Tags[] | select(.Key == "'"$PROJECT_TAG_KEY"'") | .Value) + "," + 
        .NatGatewayAddresses[0].NetworkInterfaceId
    ' 2>/dev/null
  )

  counted_vpcs_string="|" 

  while IFS=',' read -r vpc_id create_time nat_gw_id project_name nat_eni_id; do
    
    if [ -z "$vpc_id" ] || [ -z "$project_name" ]; then
      continue
    fi
    
    if echo "$counted_vpcs_string" | grep -q "|${vpc_id}|"; then
      continue
    fi
    
    age_seconds=$(get_age_seconds "$create_time")
    
    if [ "$age_seconds" -gt "$AGE_LIMIT_SECONDS" ]; then
      
      echo "  --------------------------------------------------"
      echo "  ✅ OLD VPC INFRASTRUCTURE FOUND (Proxy: $nat_gw_id)"
      echo "     VPC ID: $vpc_id"
      echo "     Project: $project_name"
      echo "     Created: $create_time"
      
      # Mark VPC as counted and store it for final deletion pass
      regional_vpc_count=$((regional_vpc_count + 1))
      regional_vpcs_to_delete="$regional_vpcs_to_delete $vpc_id"
      counted_vpcs_string="${counted_vpcs_string}${vpc_id}|" 
      
      # -----------------------------------------------------------------
      # 2. DELETE/REPORT ASSOCIATED RESOURCES by PROJECT TAG or VPC ID
      # -----------------------------------------------------------------
      PROJECT_FILTER="Name=tag:$PROJECT_TAG_KEY,Values=$project_name"
      VPC_FILTER="Name=vpc-id,Values=$vpc_id"
      
      echo "  Searching for related resources with Tag: $PROJECT_TAG_KEY=$project_name and VPC: $vpc_id..."
      
      # --- 2.1 Load Balancers (Deletes ELA ENIs automatically) ---
      # Filter Load Balancers by VPC ID, then delete them.
      lbs_arns_in_vpc=$(
          aws elbv2 describe-load-balancers \
            --region "$region" \
            --query "LoadBalancers[?VpcId=='$vpc_id'].LoadBalancerArn" \
            --output text 2>/dev/null
      )
      
      for lb_arn in $lbs_arns_in_vpc; do
          delete_resource "LB" "$lb_arn" "$region" "Associated with old project"
          regional_lbs=$((regional_lbs + 1))
      done

      # --- 2.2 EC2 Instances (Terminate next) ---
      ec2s_project_json=$(aws ec2 describe-instances --region "$region" --filter "$PROJECT_FILTER" --query 'Reservations[].Instances[]' --output json 2>/dev/null)
      ec2s_project_time=$(echo "$ec2s_project_json" | jq -r '.[] | select(.LaunchTime != null) | .InstanceId + "," + .LaunchTime' 2>/dev/null)

      while IFS=',' read -r ec2_id launch_time; do
          if [ -z "$ec2_id" ]; then
              continue
          fi
          age_seconds=$(get_age_seconds "$launch_time")
          if [ "$age_seconds" -gt "$AGE_LIMIT_SECONDS" ]; then
              delete_resource "EC2" "$ec2_id" "$region" "$launch_time"
              wait_for_resource_deletion "EC2" "$ec2_id" "$region"
              regional_ec2s=$((regional_ec2s + 1))
          fi
      done <<< "$ec2s_project_time"
      
      # --- 2.3 NAT Gateway (Deletion and Poll) ---
      delete_resource "NAT_GW_PROXY" "$nat_gw_id" "$region" "$create_time"
      wait_for_resource_deletion "ENI" "$nat_eni_id" "$region"

      # --- 2.4 Elastic Network Interfaces (ENIs) (Catch remaining) ---
      enis=$(aws ec2 describe-network-interfaces --region "$region" --filter "$VPC_FILTER" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null)
      for eni_id in $enis; do
          delete_resource "ENI" "$eni_id" "$region" "VPC $vpc_id cleanup"
          regional_enis=$((regional_enis + 1))

          # --- 2.4.1 Deletion of ELASTIC IP (EIP) (Catch remaining) ---
          eips_data=$(aws ec2 describe-addresses --region "$region" --query "Addresses[?NetworkInterfaceId=='$eni_id'].AllocationId"  --output text 2>/dev/null)
          
          for eip_alloc_id in $eips_data; do
              delete_resource "EIP" "$eip_alloc_id" "$region" "Associated with old project"
              regional_eips=$((regional_eips + 1))
          done
      done

      # --- 2.5 VPC Endpoints ---
      endpoints=$(aws ec2 describe-vpc-endpoints --region "$region" --filter "$VPC_FILTER" --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null)
      for ep_id in $endpoints; do
          delete_resource "ENDPOINT" "$ep_id" "$region" "Associated with old project"
          regional_endpoints=$((regional_endpoints + 1))
      done
      
      # --- 2.6 VPC Peering Connections ---
      peering_conns=$(aws ec2 describe-vpc-peering-connections --region "$region" --filter "Name=requester-vpc-info.vpc-id,Values=$vpc_id" --query 'VpcPeeringConnections[].VpcPeeringConnectionId' --output text 2>/dev/null)
      for pcx_id in $peering_conns; do
          delete_resource "PEERING" "$pcx_id" "$region" "Associated with old project"
          regional_peering=$((regional_peering + 1))
      done
      
      # --- 2.7 VPN Gateways (Detach and Delete) ---
      vpn_gws=$(aws ec2 describe-vpn-gateways --region "$region" --filter "Name=attachment.vpc-id,Values=$vpc_id" --query 'VpnGateways[].VpnGatewayId' --output text 2>/dev/null)
      for vpn_id in $vpn_gws; do
          delete_resource "VPN_GW" "$vpn_id" "$region" "Associated with old project"
          regional_vpns=$((regional_vpns + 1))
      done

      # --- 2.8 Carrier Gateways ---
      carrier_gws=$(aws ec2 describe-carrier-gateways --region "$region" --filter "$VPC_FILTER" --query 'CarrierGateways[].CarrierGatewayId' --output text 2>/dev/null)
      for carrier_id in $carrier_gws; do
          delete_resource "CARRIER_GW" "$carrier_id" "$region" "Associated with old project"
          regional_carriers=$((regional_carriers + 1))
      done
      
      # --- 2.9 Local Gateway Route Table VPC Associations ---
      lgw_assocs=$(aws ec2 describe-local-gateway-route-table-vpc-associations --region "$region" --filter "$VPC_FILTER" --query 'LocalGatewayRouteTableVpcAssociations[].LocalGatewayRouteTableVpcAssociationId' --output text 2>/dev/null)
      for assoc_id in $lgw_assocs; do
          delete_resource "LGW_ASSOC" "$assoc_id" "$region" "Associated with old project"
          regional_lgw_assoc=$((regional_lgw_assoc + 1))
      done


      # --- 2.10 Internet Gateways (Detach and Delete) ---
      igws=$(aws ec2 describe-internet-gateways --region "$region" --query "InternetGateways[?Attachments[0].VpcId=='$vpc_id'].InternetGatewayId" --output text 2>/dev/null)
      for igw_id in $igws; do
          delete_resource "IGW" "$igw_id" "$region" "Associated with old project"
          regional_igws=$((regional_igws + 1))
      done
      
      # --- 2.11 Route Tables ---
      rts=$(aws ec2 describe-route-tables --region "$region" --query "RouteTables[?VpcId=='$vpc_id'].RouteTableId" --output text 2>/dev/null)
      for rt_id in $rts; do
          is_main=$(aws ec2 describe-route-tables --region "$region" --route-table-ids "$rt_id" --query 'RouteTables[0].Associations[?Main == `true`].Main' --output text 2>/dev/null)
          if [ -z "$is_main" ]; then
             delete_resource "RT" "$rt_id" "$region" "Associated with old project"
             regional_rts=$((regional_rts + 1))
          fi
      done
      
      # --- 2.12 Network ACLs ---
      acls=$(aws ec2 describe-network-acls --region "$region" --filter "$VPC_FILTER" --query 'NetworkAcls[?IsDefault == `false`].NetworkAclId' --output text 2>/dev/null)
      for acl_id in $acls; do
          delete_resource "ACL" "$acl_id" "$region" "Associated with old project"
          regional_acls=$((regional_acls + 1))
      done

      # --- 2.13 Subnets ---
      subnets=$(aws ec2 describe-subnets --region "$region" --filter "$VPC_FILTER" --query 'Subnets[].SubnetId' --output text 2>/dev/null)
      for subnet_id in $subnets; do
          delete_resource "SUBNET" "$subnet_id" "$region" "Associated with old project"
          regional_subnets=$((regional_subnets + 1))
      done
      
      # --- 2.14 Security Groups ---
      sgs=$(aws ec2 describe-security-groups --region "$region" --filter "$VPC_FILTER" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null)
      for sg_id in $sgs; do
          if [[ "$sg_id" != *sg-default* ]]; then
             delete_resource "SG" "$sg_id" "$region" "Associated with old project"
             regional_sgs=$((regional_sgs + 1))
          fi
      done
    fi
  done <<< "$nat_gateways_data"
  
  

  # -----------------------------------------------------------------
  # 4. FINAL VPC DELETION PASS (After all dependencies are removed)
  # -----------------------------------------------------------------
  if [ -n "$regional_vpcs_to_delete" ]; then
      echo "  --- Final Pass: Deleting identified VPCs ---"
      for vpc_to_delete in $regional_vpcs_to_delete; do
          delete_resource "VPC" "$vpc_to_delete" "$region" "After Dependencies Deleted"
      done
  fi

  # -----------------------------------------------------------------
  # 5. Print Regional Summary & Update Grand Totals
  # -----------------------------------------------------------------
  
  if (( regional_vpc_count > 0 || regional_ec2s > 0 || regional_eips > 0 || regional_subnets > 0 || regional_sgs > 0 || regional_endpoints > 0 || regional_rts > 0 || regional_igws > 0 || regional_enis > 0 || regional_peering > 0 || regional_acls > 0 || regional_vpns > 0 || regional_carriers > 0 || regional_lgw_assoc > 0 || regional_lbs > 0 )); then
    echo "  Summary of actions in $region:"
    echo "    VPCs targeted for final delete:     $regional_vpc_count"
    echo "    Load Balancers targeted:            $regional_lbs"
    echo "    EC2 Instances (Older than 1 day) targeted: $regional_ec2s"
    echo "    Elastic Network Interfaces targeted: $regional_enis"
    echo "    VPC Endpoints targeted:             $regional_endpoints"
    echo "    VPC Peering Connections targeted:   $regional_peering"
    echo "    VPN Gateways targeted:              $regional_vpns"
    echo "    Carrier Gateways targeted:          $regional_carriers"
    echo "    LGW Route Table Assocs targeted:    $regional_lgw_assoc"
    echo "    Internet Gateways targeted:         $regional_igws"
    echo "    Route Tables targeted:              $regional_rts"
    echo "    Network ACLs targeted:              $regional_acls"
    echo "    Subnets targeted:                   $regional_subnets"
    echo "    Security Groups targeted:           $regional_sgs"
    echo "    Elastic IPs (Tag match only) targeted: $regional_eips"
    
    # Update global totals
    total_vpcs=$((total_vpcs + regional_vpc_count))
    total_lbs=$((total_lbs + regional_lbs))
    total_endpoints=$((total_endpoints + regional_endpoints))
    total_peering=$((total_peering + regional_peering))
    total_vpns=$((total_vpns + regional_vpns))
    total_carriers=$((total_carriers + regional_carriers))
    total_lgw_assoc=$((total_lgw_assoc + regional_lgw_assoc))
    total_igws=$((total_igws + regional_igws))
    total_rts=$((total_rts + regional_rts))
    total_acls=$((total_acls + regional_acls))
    total_subnets=$((total_subnets + regional_subnets))
    total_sgs=$((total_sgs + regional_sgs))
    total_ec2s=$((total_ec2s + regional_ec2s))
    total_eips=$((total_eips + regional_eips))
    total_enis=$((total_enis + regional_enis))
  else
    echo "  No resources found that match tag and age criteria in $region."
  fi
  echo
done

# Print the final grand totals
echo "--------------------------------------------------------"
echo "GRAND TOTALS for $TAG_KEY=$TAG_VALUE"
echo "  Total VPCs targeted:          $total_vpcs"
echo "  Total Load Balancers targeted: $total_lbs"
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
echo "--------------------------------------------------------"
if $DRY_RUN; then
    echo "Remember: DRY-RUN MODE was active. No resources were deleted."
fi