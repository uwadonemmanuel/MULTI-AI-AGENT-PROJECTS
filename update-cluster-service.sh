#!/bin/bash
# Interactive script to update cluster and service names

echo "=========================================="
echo "Update ECS Cluster and Service Names"
echo "=========================================="
echo ""
echo "This script will help you update all scripts with correct cluster/service names"
echo ""

# Get current values from Jenkinsfile
CURRENT_CLUSTER=$(grep "ECS_CLUSTER" Jenkinsfile 2>/dev/null | head -1 | sed "s/.*ECS_CLUSTER = '\(.*\)'.*/\1/" || echo "")
CURRENT_SERVICE=$(grep "ECS_SERVICE" Jenkinsfile 2>/dev/null | head -1 | sed "s/.*ECS_SERVICE = '\(.*\)'.*/\1/" || echo "")

echo "Current values (from Jenkinsfile):"
echo "  Cluster: ${CURRENT_CLUSTER:-'not set'}"
echo "  Service: ${CURRENT_SERVICE:-'not set'}"
echo ""

# Prompt for new values
read -p "Enter cluster name (or press Enter to keep current): " NEW_CLUSTER
read -p "Enter service name (or press Enter to keep current): " NEW_SERVICE
read -p "Enter region [eu-north-1]: " NEW_REGION
NEW_REGION=${NEW_REGION:-eu-north-1}

# Use new values or keep current
FINAL_CLUSTER=${NEW_CLUSTER:-$CURRENT_CLUSTER}
FINAL_SERVICE=${NEW_SERVICE:-$CURRENT_SERVICE}

if [ -z "$FINAL_CLUSTER" ] || [ -z "$FINAL_SERVICE" ]; then
  echo "❌ Cluster and Service names are required"
  exit 1
fi

echo ""
echo "New values:"
echo "  Cluster: $FINAL_CLUSTER"
echo "  Service: $FINAL_SERVICE"
echo "  Region: $NEW_REGION"
echo ""

read -p "Update all scripts? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled"
  exit 0
fi

# Update Jenkinsfile
echo ""
echo "Updating files..."
if [ -f "Jenkinsfile" ]; then
  sed -i.bak "s/ECS_CLUSTER = '.*'/ECS_CLUSTER = '$FINAL_CLUSTER'/" Jenkinsfile
  sed -i.bak "s/ECS_SERVICE = '.*'/ECS_SERVICE = '$FINAL_SERVICE'/" Jenkinsfile
  sed -i.bak "s/AWS_REGION = '.*'/AWS_REGION = '$NEW_REGION'/" Jenkinsfile
  echo "  ✅ Jenkinsfile updated"
fi

# Update all .sh scripts
for script in *.sh; do
  if [ -f "$script" ]; then
    sed -i.bak "s/export CLUSTER_NAME=.*/export CLUSTER_NAME=$FINAL_CLUSTER/" "$script" 2>/dev/null
    sed -i.bak "s/export SERVICE_NAME=.*/export SERVICE_NAME=$FINAL_SERVICE/" "$script" 2>/dev/null
    sed -i.bak "s/export AWS_REGION=.*/export AWS_REGION=$NEW_REGION/" "$script" 2>/dev/null
    sed -i.bak "s/CLUSTER_NAME=.*/CLUSTER_NAME=$FINAL_CLUSTER/" "$script" 2>/dev/null
    sed -i.bak "s/SERVICE_NAME=.*/SERVICE_NAME=$FINAL_SERVICE/" "$script" 2>/dev/null
  fi
done

echo "  ✅ Scripts updated"
echo ""

# Test the new values
echo "Testing new values..."
aws ecs describe-services \
  --cluster "$FINAL_CLUSTER" \
  --services "$FINAL_SERVICE" \
  --region "$NEW_REGION" \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}' \
  --output table 2>/dev/null && echo "  ✅ Service found!" || echo "  ⚠️  Service not found - check names"

echo ""
echo "=========================================="
echo "✅ Update Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check task status: ./check-task-status.sh"
echo "2. Start service: ./start-ecs-service.sh"
echo "3. Test connection: ./test-connection.sh"

