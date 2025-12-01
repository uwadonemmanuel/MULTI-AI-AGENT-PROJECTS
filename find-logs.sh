#!/bin/bash
# Find CloudWatch log groups for ECS

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

echo "=========================================="
echo "Finding CloudWatch Log Groups"
echo "=========================================="
echo ""

# List all log groups that might be related
echo "1. Searching for ECS-related log groups..."
echo "----------------------------------------"
aws logs describe-log-groups \
  --region $AWS_REGION \
  --log-group-name-prefix "/ecs" \
  --query 'logGroups[*].logGroupName' \
  --output table 2>/dev/null || echo "  No /ecs log groups found"

echo ""
echo "2. Searching for task definition related log groups..."
echo "----------------------------------------"
aws logs describe-log-groups \
  --region $AWS_REGION \
  --log-group-name-prefix "multi-ai-agent" \
  --query 'logGroups[*].logGroupName' \
  --output table 2>/dev/null || echo "  No multi-ai-agent log groups found"

echo ""
echo "3. All log groups (last 20)..."
echo "----------------------------------------"
aws logs describe-log-groups \
  --region $AWS_REGION \
  --query 'logGroups[*].logGroupName' \
  --output table 2>/dev/null | head -25

echo ""
echo "4. Checking task definition for log configuration..."
echo "----------------------------------------"
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null)

if [ ! -z "$TASK_DEF_ARN" ] && [ "$TASK_DEF_ARN" != "None" ]; then
  echo "  Task Definition: $TASK_DEF_ARN"
  echo ""
  echo "  Log Configuration:"
  aws ecs describe-task-definition \
    --task-definition $TASK_DEF_ARN \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].logConfiguration' \
    --output json 2>/dev/null || echo "  ❌ No log configuration found"
else
  echo "  ❌ Could not get task definition"
fi

echo ""
echo "=========================================="
echo "If no logs found, CloudWatch logging may not be enabled"
echo "See: enable-cloudwatch-logs.md"
echo "=========================================="



