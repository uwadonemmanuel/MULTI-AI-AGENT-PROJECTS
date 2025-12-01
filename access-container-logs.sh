#!/bin/bash
# Access log files from the logs/ directory in the ECS container

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

echo "=========================================="
echo "Accessing Log Files from ECS Container"
echo "=========================================="
echo ""
echo "Your application writes logs to: /app/logs/log_YYYY-MM-DD.log"
echo ""

# Get running task
echo "1. Finding running task..."
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text 2>/dev/null)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "   ❌ No running tasks found"
  echo "   Check ECS console for task status"
  exit 1
fi

echo "   ✅ Task found: $TASK_ARN"
echo ""

# Check if ECS Exec is enabled
echo "2. Checking ECS Exec configuration..."
EXEC_ENABLED=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].enableExecuteCommand' \
  --output text 2>/dev/null)

if [ "$EXEC_ENABLED" != "true" ]; then
  echo "   ⚠️  ECS Exec is not enabled for this task"
  echo ""
  echo "   To enable ECS Exec:"
  echo "   1. Go to Task Definition"
  echo "   2. Enable 'Enable ECS Exec'"
  echo "   3. Update service"
  echo ""
  echo "   OR use CloudWatch Logs instead (recommended):"
  echo "   ./view-logs.sh"
  echo ""
  echo "   OR access logs via CloudWatch:"
  echo "   https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups"
  exit 1
fi

echo "   ✅ ECS Exec is enabled"
echo ""

# Method 1: Execute command to list log files
echo "3. Listing log files in container..."
echo "   ----------------------------------------"
aws ecs execute-command \
  --cluster $CLUSTER_NAME \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "ls -lah /app/logs/" \
  --interactive \
  --region $AWS_REGION 2>/dev/null || {
  echo "   ⚠️  Could not execute command"
  echo "   You may need to enable ECS Exec in task definition"
  echo ""
  echo "   Alternative: Use CloudWatch Logs"
  echo "   ./view-logs.sh"
  exit 1
}

echo ""
echo "4. To view a specific log file:"
echo "   ----------------------------------------"
echo "   aws ecs execute-command \\"
echo "     --cluster $CLUSTER_NAME \\"
echo "     --task $TASK_ARN \\"
echo "     --container multi-ai-agent \\"
echo "     --command 'cat /app/logs/log_$(date +%Y-%m-%d).log' \\"
echo "     --interactive \\"
echo "     --region $AWS_REGION"
echo ""

echo "5. To tail logs in real-time:"
echo "   ----------------------------------------"
echo "   aws ecs execute-command \\"
echo "     --cluster $CLUSTER_NAME \\"
echo "     --task $TASK_ARN \\"
echo "     --container multi-ai-agent \\"
echo "     --command 'tail -f /app/logs/log_$(date +%Y-%m-%d).log' \\"
echo "     --interactive \\"
echo "     --region $AWS_REGION"
echo ""

echo "6. To get an interactive shell:"
echo "   ----------------------------------------"
echo "   aws ecs execute-command \\"
echo "     --cluster $CLUSTER_NAME \\"
echo "     --task $TASK_ARN \\"
echo "     --container multi-ai-agent \\"
echo "     --command '/bin/sh' \\"
echo "     --interactive \\"
echo "     --region $AWS_REGION"
echo ""
echo "   Then inside the container:"
echo "   cd /app/logs"
echo "   ls -la"
echo "   cat log_2025-01-01.log  # Replace with actual date"
echo "   tail -f log_2025-01-01.log"
echo ""

echo "=========================================="
echo "Recommended: Use CloudWatch Logs Instead"
echo "=========================================="
echo "CloudWatch Logs is easier and doesn't require ECS Exec:"
echo "  ./view-logs.sh"
echo ""
echo "Or access directly:"
echo "  https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups"
echo ""


