#!/bin/bash
# Find ECS services in the cluster

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k

echo "=========================================="
echo "Finding ECS Services"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if cluster exists
echo "1. Checking if cluster exists..."
CLUSTER_EXISTS=$(aws ecs describe-clusters \
  --clusters $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'clusters[0].clusterName' \
  --output text 2>/dev/null)

if [ -z "$CLUSTER_EXISTS" ] || [ "$CLUSTER_EXISTS" = "None" ]; then
  echo "   ❌ Cluster not found: $CLUSTER_NAME"
  echo ""
  echo "   Available clusters:"
  aws ecs list-clusters \
    --region $AWS_REGION \
    --query 'clusterArns[*]' \
    --output text 2>/dev/null | awk -F'/' '{print "     - " $NF}'
  exit 1
fi

echo "   ✅ Cluster found: $CLUSTER_EXISTS"
echo ""

# List all services in cluster
echo "2. Services in cluster:"
echo "----------------------------------------"
SERVICES=$(aws ecs list-services \
  --cluster $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'serviceArns[*]' \
  --output text 2>/dev/null)

if [ -z "$SERVICES" ] || [ "$SERVICES" = "None" ]; then
  echo "   ⚠️  No services found in cluster"
  echo ""
  echo "   You need to create a service first."
  echo "   See: ecs-container-config.md for container configuration"
else
  echo "   Found services:"
  for service in $SERVICES; do
    SERVICE_NAME=$(basename $service)
    echo ""
    echo "   Service: $SERVICE_NAME"
    
    # Get service details
    SERVICE_DETAILS=$(aws ecs describe-services \
      --cluster $CLUSTER_NAME \
      --services $SERVICE_NAME \
      --region $AWS_REGION \
      --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,TaskDef:taskDefinition}' \
      --output json 2>/dev/null)
    
    if [ ! -z "$SERVICE_DETAILS" ] && [ "$SERVICE_DETAILS" != "null" ]; then
      echo "$SERVICE_DETAILS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"     Status: {d.get('Status', 'N/A')}\")
print(f\"     Running: {d.get('RunningCount', 0)} / Desired: {d.get('DesiredCount', 0)}\")
print(f\"     Task Def: {d.get('TaskDef', 'N/A')}\")
" 2>/dev/null || echo "     (Could not get details)"
    fi
  done
fi

echo ""
echo "=========================================="
echo "Quick Actions:"
echo "=========================================="
echo ""
echo "To use a service, update your scripts with the correct service name:"
echo ""
echo "  export ECS_SERVICE='<service-name-from-above>'"
echo ""
echo "Or update Jenkinsfile:"
echo "  ECS_SERVICE = '<service-name-from-above>'"
echo ""
echo "ECS Console:"
echo "  https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services"


