#!/bin/bash
# Check why ECS tasks are not running

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

echo "=========================================="
echo "Checking ECS Task Status"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Region: $AWS_REGION"
echo ""

# 1. Check service status
echo "1. Service Status:"
echo "----------------------------------------"
SERVICE_INFO=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,PendingCount:pendingCount,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition,RunningCount:runningCount,DesiredCount:desiredCount}}' \
  --output json 2>/dev/null)

if [ -z "$SERVICE_INFO" ] || [ "$SERVICE_INFO" = "null" ]; then
  echo "   ❌ Service not found!"
  echo "   Service name: $SERVICE_NAME"
  echo "   Check if service exists in cluster"
  exit 1
fi

echo "$SERVICE_INFO" | python3 -m json.tool 2>/dev/null || echo "$SERVICE_INFO"

# Extract counts
RUNNING_COUNT=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('RunningCount', 0))" 2>/dev/null || echo "0")
DESIRED_COUNT=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('DesiredCount', 0))" 2>/dev/null || echo "0")
PENDING_COUNT=$(echo "$SERVICE_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('PendingCount', 0))" 2>/dev/null || echo "0")

echo ""
echo "   Summary:"
echo "   - Desired tasks: $DESIRED_COUNT"
echo "   - Running tasks: $RUNNING_COUNT"
echo "   - Pending tasks: $PENDING_COUNT"

if [ "$RUNNING_COUNT" = "0" ] && [ "$DESIRED_COUNT" = "0" ]; then
  echo ""
  echo "   ⚠️  Service has 0 desired count - service is scaled down"
  echo "   Update service to set desired count > 0"
elif [ "$RUNNING_COUNT" = "0" ] && [ "$DESIRED_COUNT" -gt "0" ]; then
  echo ""
  echo "   ⚠️  No running tasks but desired count is $DESIRED_COUNT"
  echo "   Tasks may be failing to start - check stopped tasks"
fi

# 2. Check all tasks (running and stopped)
echo ""
echo "2. All Tasks (Running and Stopped):"
echo "----------------------------------------"

# Running tasks
RUNNING_TASKS=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --desired-status RUNNING \
  --region $AWS_REGION \
  --query 'taskArns[*]' \
  --output text 2>/dev/null)

if [ ! -z "$RUNNING_TASKS" ] && [ "$RUNNING_TASKS" != "None" ]; then
  echo "   Running tasks:"
  for task in $RUNNING_TASKS; do
    echo "     - $task"
  done
else
  echo "   ⚠️  No running tasks"
fi

# Stopped tasks
STOPPED_TASKS=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --desired-status STOPPED \
  --region $AWS_REGION \
  --query 'taskArns[*]' \
  --output text 2>/dev/null)

if [ ! -z "$STOPPED_TASKS" ] && [ "$STOPPED_TASKS" != "None" ]; then
  echo ""
  echo "   Stopped tasks (last 5):"
  STOPPED_COUNT=0
  for task in $STOPPED_TASKS; do
    if [ $STOPPED_COUNT -lt 5 ]; then
      STOPPED_REASON=$(aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $task \
        --region $AWS_REGION \
        --query 'tasks[0].{Reason:stoppedReason,Code:stopCode,At:stoppedAt}' \
        --output json 2>/dev/null)
      
      echo "     Task: $(basename $task)"
      echo "$STOPPED_REASON" | python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"       Reason: {d.get('Reason', 'N/A')}\"); print(f\"       Code: {d.get('Code', 'N/A')}\"); print(f\"       Stopped: {d.get('At', 'N/A')}\")" 2>/dev/null || echo "       (Could not get details)"
      echo ""
      STOPPED_COUNT=$((STOPPED_COUNT + 1))
    fi
  done
else
  echo ""
  echo "   ℹ️  No stopped tasks found"
fi

# 3. Check service events
echo ""
echo "3. Recent Service Events (last 10):"
echo "----------------------------------------"
SERVICE_EVENTS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].events[:10]' \
  --output json 2>/dev/null)

if [ ! -z "$SERVICE_EVENTS" ] && [ "$SERVICE_EVENTS" != "null" ] && [ "$SERVICE_EVENTS" != "[]" ]; then
  echo "$SERVICE_EVENTS" | python3 -c "
import sys, json
events = json.load(sys.stdin)
for event in events:
    print(f\"   [{event.get('createdAt', 'N/A')}] {event.get('message', 'N/A')}\")
" 2>/dev/null || echo "$SERVICE_EVENTS"
else
  echo "   No recent events"
fi

# 4. Check if service needs to be updated
echo ""
echo "4. Recommendations:"
echo "----------------------------------------"

if [ "$DESIRED_COUNT" = "0" ]; then
  echo "   ❌ Service is scaled to 0"
  echo "   Fix: Update service desired count to 1 or more"
  echo ""
  echo "   Command:"
  echo "   aws ecs update-service \\"
  echo "     --cluster $CLUSTER_NAME \\"
  echo "     --service $SERVICE_NAME \\"
  echo "     --desired-count 1 \\"
  echo "     --region $AWS_REGION"
elif [ "$RUNNING_COUNT" = "0" ] && [ "$DESIRED_COUNT" -gt "0" ]; then
  echo "   ⚠️  Tasks are failing to start"
  echo "   Check stopped tasks above for error reasons"
  echo ""
  echo "   Common issues:"
  echo "   - Missing environment variables (GROQ_API_KEY, TAVILY_API_KEY)"
  echo "   - Application crash on startup"
  echo "   - Health check failing"
  echo "   - Resource limits too low"
  echo ""
  echo "   Check logs: ./view-logs.sh"
  echo "   Or check stopped task reason above"
elif [ "$PENDING_COUNT" -gt "0" ]; then
  echo "   ⏳ Tasks are starting (pending: $PENDING_COUNT)"
  echo "   Wait a few minutes and check again"
else
  echo "   ✅ Service appears to be running"
  echo "   Running tasks: $RUNNING_COUNT"
fi

echo ""
echo "=========================================="
echo "Quick Actions:"
echo "=========================================="
echo ""
echo "1. Update service desired count:"
echo "   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 1 --region $AWS_REGION"
echo ""
echo "2. Force new deployment:"
echo "   aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region $AWS_REGION"
echo ""
echo "3. Check logs:"
echo "   ./view-logs.sh"
echo ""
echo "4. ECS Console:"
echo "   https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"



