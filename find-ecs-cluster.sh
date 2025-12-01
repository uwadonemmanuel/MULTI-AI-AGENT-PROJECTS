#!/bin/bash
# Find ECS clusters

export AWS_REGION=eu-north-1

echo "=========================================="
echo "Finding ECS Clusters"
echo "=========================================="
echo "Region: $AWS_REGION"
echo ""

# List all clusters
echo "1. All clusters in region $AWS_REGION:"
echo "----------------------------------------"
CLUSTERS=$(aws ecs list-clusters \
  --region $AWS_REGION \
  --query 'clusterArns[*]' \
  --output text 2>/dev/null)

if [ -z "$CLUSTERS" ] || [ "$CLUSTERS" = "None" ]; then
  echo "   ⚠️  No clusters found in region $AWS_REGION"
  echo ""
  echo "   Possible reasons:"
  echo "   - Cluster doesn't exist"
  echo "   - Wrong region"
  echo "   - AWS credentials don't have access"
  echo ""
  echo "   Check other regions or create a cluster:"
  echo "   https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters"
else
  echo "   Found clusters:"
  for cluster in $CLUSTERS; do
    CLUSTER_NAME=$(basename $cluster)
    echo ""
    echo "   📦 Cluster: $CLUSTER_NAME"
    
    # Get cluster details
    CLUSTER_INFO=$(aws ecs describe-clusters \
      --clusters $CLUSTER_NAME \
      --region $AWS_REGION \
      --query 'clusters[0].{Status:status,ActiveServices:activeServicesCount,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount}' \
      --output json 2>/dev/null)
    
    if [ ! -z "$CLUSTER_INFO" ] && [ "$CLUSTER_INFO" != "null" ]; then
      echo "$CLUSTER_INFO" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"     Status: {d.get('Status', 'N/A')}\")
print(f\"     Services: {d.get('ActiveServices', 0)}\")
print(f\"     Running Tasks: {d.get('RunningTasks', 0)}\")
print(f\"     Pending Tasks: {d.get('PendingTasks', 0)}\")
" 2>/dev/null || echo "     (Could not get details)"
      
      # List services in this cluster
      SERVICES=$(aws ecs list-services \
        --cluster $CLUSTER_NAME \
        --region $AWS_REGION \
        --query 'serviceArns[*]' \
        --output text 2>/dev/null)
      
      if [ ! -z "$SERVICES" ] && [ "$SERVICES" != "None" ]; then
        echo "     Services:"
        for service in $SERVICES; do
          SERVICE_NAME=$(basename $service)
          RUNNING=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --region $AWS_REGION \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null || echo "0")
          DESIRED=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --region $AWS_REGION \
            --query 'services[0].desiredCount' \
            --output text 2>/dev/null || echo "0")
          echo "       - $SERVICE_NAME (Running: $RUNNING/$DESIRED)"
        done
      else
        echo "     Services: None"
      fi
    fi
  done
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. If you found your cluster, update scripts:"
echo "   export CLUSTER_NAME='<cluster-name>'"
echo "   export SERVICE_NAME='<service-name>'"
echo ""
echo "2. Or update Jenkinsfile:"
echo "   ECS_CLUSTER = '<cluster-name>'"
echo "   ECS_SERVICE = '<service-name>'"
echo ""
echo "3. If cluster doesn't exist, create one:"
echo "   https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/create"
echo ""
echo "4. Check other regions:"
echo "   aws ecs list-clusters --region us-east-1"
echo "   aws ecs list-clusters --region us-west-2"
echo "   # etc."



