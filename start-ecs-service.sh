#!/bin/bash
# Start ECS service or update desired count

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export DESIRED_COUNT=${1:-1}  # Default to 1 if not provided

echo "=========================================="
echo "Starting/Updating ECS Service"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Desired Count: $DESIRED_COUNT"
echo ""

# Check current status
echo "1. Checking current service status..."
CURRENT_COUNT=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].desiredCount' \
  --output text 2>/dev/null)

if [ -z "$CURRENT_COUNT" ] || [ "$CURRENT_COUNT" = "None" ]; then
  echo "   ❌ Service not found!"
  echo "   Service name: $SERVICE_NAME"
  exit 1
fi

echo "   Current desired count: $CURRENT_COUNT"
echo "   New desired count: $DESIRED_COUNT"

if [ "$CURRENT_COUNT" = "$DESIRED_COUNT" ]; then
  echo "   ℹ️  Service already has desired count of $DESIRED_COUNT"
  echo "   Force new deployment instead..."
  
  echo ""
  echo "2. Forcing new deployment..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo "   ✅ New deployment initiated"
  else
    echo "   ❌ Failed to force deployment"
    exit 1
  fi
else
  echo ""
  echo "2. Updating service desired count..."
  aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count $DESIRED_COUNT \
    --region $AWS_REGION > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo "   ✅ Service updated"
    echo "   Desired count set to: $DESIRED_COUNT"
  else
    echo "   ❌ Failed to update service"
    exit 1
  fi
fi

echo ""
echo "3. Waiting for tasks to start (this may take 1-2 minutes)..."
echo "----------------------------------------"

# Wait and check task status
for i in {1..12}; do
  sleep 10
  RUNNING_COUNT=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null)
  
  PENDING_COUNT=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'services[0].pendingCount' \
    --output text 2>/dev/null)
  
  echo "   [$i/12] Running: $RUNNING_COUNT, Pending: $PENDING_COUNT"
  
  if [ "$RUNNING_COUNT" -ge "$DESIRED_COUNT" ]; then
    echo ""
    echo "   ✅ Tasks are running!"
    break
  fi
done

echo ""
echo "4. Final Status:"
echo "----------------------------------------"
FINAL_STATUS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].{RunningCount:runningCount,DesiredCount:desiredCount,PendingCount:pendingCount}' \
  --output table 2>/dev/null)

echo "$FINAL_STATUS"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Check task status:"
echo "   ./check-task-status.sh"
echo ""
echo "2. View logs:"
echo "   ./view-logs.sh"
echo ""
echo "3. Test connection:"
echo "   ./test-connection.sh"
echo ""
echo "4. ECS Console:"
echo "   https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"



