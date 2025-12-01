#!/bin/bash
# Enable CloudWatch logging for ECS task

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export LOG_GROUP="/ecs/multi-ai-agent"

echo "=========================================="
echo "Enabling CloudWatch Logging for ECS Task"
echo "=========================================="
echo ""

# Step 1: Create log group if it doesn't exist
echo "1. Creating log group (if it doesn't exist)..."
aws logs create-log-group \
  --log-group-name $LOG_GROUP \
  --region $AWS_REGION 2>/dev/null && echo "   ✅ Log group created" || echo "   ℹ️  Log group already exists"

# Step 2: Get current task definition
echo ""
echo "2. Getting current task definition..."
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null)

if [ -z "$TASK_DEF_ARN" ] || [ "$TASK_DEF_ARN" = "None" ]; then
  echo "   ❌ Could not get task definition"
  exit 1
fi

echo "   Task Definition: $TASK_DEF_ARN"

# Get task definition JSON
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region $AWS_REGION \
  --query 'taskDefinition' > task-def.json 2>/dev/null

if [ ! -f "task-def.json" ]; then
  echo "   ❌ Failed to get task definition"
  exit 1
fi

echo "   ✅ Task definition saved to task-def.json"

# Step 3: Update with logging configuration
echo ""
echo "3. Updating task definition with CloudWatch logging..."
python3 << 'PYEOF'
import json
import sys

try:
    with open('task-def.json', 'r') as f:
        task_def = json.load(f)
    
    container_def = task_def['containerDefinitions'][0]
    
    # Check if logging is already configured
    if 'logConfiguration' in container_def:
        current_log = container_def['logConfiguration'].get('options', {}).get('awslogs-group', '')
        if current_log == '/ecs/multi-ai-agent':
            print("   ℹ️  CloudWatch logging already configured")
            sys.exit(0)
    
    # Add log configuration
    container_def['logConfiguration'] = {
        'logDriver': 'awslogs',
        'options': {
            'awslogs-group': '/ecs/multi-ai-agent',
            'awslogs-region': 'eu-north-1',
            'awslogs-stream-prefix': 'ecs'
        }
    }
    
    # Remove fields that can't be set
    for key in ['taskDefinitionArn', 'revision', 'status', 'requiresAttributes', 
                'compatibilities', 'registeredAt', 'registeredBy']:
        task_def.pop(key, None)
    
    # Save updated task definition
    with open('task-def-updated.json', 'w') as f:
        json.dump(task_def, f, indent=2)
    
    print("   ✅ Task definition updated with CloudWatch logging")
    
except Exception as e:
    print(f"   ❌ Error: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
  echo "   ❌ Failed to update task definition"
  exit 1
fi

# Step 4: Register new task definition
echo ""
echo "4. Registering new task definition revision..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://task-def-updated.json \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text 2>/dev/null)

if [ -z "$NEW_TASK_DEF_ARN" ] || [ "$NEW_TASK_DEF_ARN" = "None" ]; then
  echo "   ❌ Failed to register new task definition"
  exit 1
fi

echo "   ✅ New task definition: $NEW_TASK_DEF_ARN"

# Step 5: Update service
echo ""
echo "5. Updating service with new task definition..."
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEF_ARN \
  --region $AWS_REGION > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "   ✅ Service update initiated"
else
  echo "   ❌ Failed to update service"
  exit 1
fi

echo ""
echo "=========================================="
echo "✅ CloudWatch logging enabled!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait for new tasks to start (check ECS console)"
echo "2. View logs: aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "3. Check logs: ./check-chat-error.sh"
echo ""
echo "Note: Make sure your ECS task execution role has CloudWatch Logs permissions:"
echo "  - logs:CreateLogStream"
echo "  - logs:PutLogEvents"
echo ""
echo "CloudWatch Logs Console:"
echo "  https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group$LOG_GROUP"


