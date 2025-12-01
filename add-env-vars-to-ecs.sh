#!/bin/bash
# Add environment variables to ECS task definition

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

echo "=========================================="
echo "Add Environment Variables to ECS"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if service exists
echo "1. Checking service..."
SERVICE_EXISTS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].serviceName' \
  --output text 2>/dev/null)

if [ -z "$SERVICE_EXISTS" ] || [ "$SERVICE_EXISTS" = "None" ]; then
  echo "   ❌ Service not found: $SERVICE_NAME"
  echo "   Run: ./find-ecs-service.sh to find correct service name"
  exit 1
fi

echo "   ✅ Service found"
echo ""

# Get current task definition
echo "2. Getting current task definition..."
CURRENT_TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null)

if [ -z "$CURRENT_TASK_DEF_ARN" ] || [ "$CURRENT_TASK_DEF_ARN" = "None" ]; then
  echo "   ❌ Could not get task definition"
  exit 1
fi

echo "   Current Task Definition: $CURRENT_TASK_DEF_ARN"
echo ""

# Get task definition JSON
echo "3. Fetching task definition details..."
TASK_DEF_JSON=$(aws ecs describe-task-definition \
  --task-definition $CURRENT_TASK_DEF_ARN \
  --region $AWS_REGION \
  --query 'taskDefinition' 2>/dev/null)

if [ -z "$TASK_DEF_JSON" ] || [ "$TASK_DEF_JSON" = "null" ]; then
  echo "   ❌ Could not fetch task definition"
  exit 1
fi

echo "   ✅ Task definition fetched"
echo ""

# Check current environment variables
echo "4. Current environment variables:"
echo "----------------------------------------"
CURRENT_ENV=$(echo "$TASK_DEF_JSON" | python3 -c "
import sys, json
task_def = json.load(sys.stdin)
env_vars = task_def.get('containerDefinitions', [{}])[0].get('environment', [])
for env in env_vars:
    name = env.get('name', '')
    if 'API_KEY' in name or 'KEY' in name:
        print(f\"   {name}: {'*' * 20} (hidden)\")
    else:
        print(f\"   {name}: {env.get('value', 'N/A')}\")
if not env_vars:
    print('   (none)')
" 2>/dev/null)

echo "$CURRENT_ENV"
echo ""

# Get API keys
echo "5. Enter API keys (or press Enter to skip):"
echo "----------------------------------------"

# Check if keys are in environment
if [ -z "$GROQ_API_KEY" ]; then
  read -sp "Enter GROQ_API_KEY: " GROQ_API_KEY
  echo ""
else
  echo "   Using GROQ_API_KEY from environment"
fi

if [ -z "$TAVILY_API_KEY" ]; then
  read -sp "Enter TAVILY_API_KEY (optional): " TAVILY_API_KEY
  echo ""
else
  echo "   Using TAVILY_API_KEY from environment"
fi

if [ -z "$GROQ_API_KEY" ] && [ -z "$TAVILY_API_KEY" ]; then
  echo "   ❌ At least GROQ_API_KEY is required"
  exit 1
fi

echo ""

# Update task definition
echo "6. Updating task definition..."
echo "----------------------------------------"

# Create updated container definitions with new environment variables
UPDATED_CONTAINER_DEFS=$(echo "$TASK_DEF_JSON" | python3 -c "
import sys, json

task_def = json.load(sys.stdin)
container_def = task_def['containerDefinitions'][0].copy()

# Get existing environment variables
env_vars = container_def.get('environment', [])

# Remove existing API keys
env_vars = [e for e in env_vars 
            if e.get('name') not in ['GROQ_API_KEY', 'TAVILY_API_KEY']]

# Add new environment variables
import os
if os.getenv('GROQ_API_KEY'):
    env_vars.append({'name': 'GROQ_API_KEY', 'value': os.getenv('GROQ_API_KEY')})
    print('✅ Added GROQ_API_KEY', file=sys.stderr)

if os.getenv('TAVILY_API_KEY'):
    env_vars.append({'name': 'TAVILY_API_KEY', 'value': os.getenv('TAVILY_API_KEY')})
    print('✅ Added TAVILY_API_KEY', file=sys.stderr)

container_def['environment'] = env_vars

# Return updated container definitions as JSON
import json
print(json.dumps([container_def]))
" GROQ_API_KEY="$GROQ_API_KEY" TAVILY_API_KEY="$TAVILY_API_KEY" 2>&1)

if [ $? -ne 0 ]; then
  echo "   ❌ Failed to update container definitions"
  exit 1
fi

# Extract task definition family
TASK_FAMILY=$(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin)['family'])" 2>/dev/null)

# Register new task definition
echo "7. Registering new task definition revision..."
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --family $TASK_FAMILY \
  --container-definitions "$UPDATED_CONTAINER_DEFS" \
  --cpu $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cpu', '256'))") \
  --memory $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('memory', '512'))") \
  --network-mode $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('networkMode', 'awsvpc'))") \
  --requires-compatibilities $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(' '.join(json.load(sys.stdin).get('requiresCompatibilities', ['FARGATE'])))") \
  --execution-role-arn $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('executionRoleArn', ''))") \
  --task-role-arn $(echo "$TASK_DEF_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('taskRoleArn', ''))" 2>/dev/null || echo "") \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text 2>/dev/null)

if [ -z "$NEW_TASK_DEF_ARN" ] || [ "$NEW_TASK_DEF_ARN" = "None" ]; then
  echo "   ❌ Failed to register new task definition"
  exit 1
fi

echo "   ✅ New Task Definition: $NEW_TASK_DEF_ARN"
echo ""

# Update service
echo "8. Updating ECS service..."
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEF_ARN \
  --force-new-deployment \
  --region $AWS_REGION > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "   ✅ Service update initiated"
else
  echo "   ❌ Failed to update service"
  exit 1
fi

echo ""
echo "=========================================="
echo "✅ Environment Variables Added!"
echo "=========================================="
echo ""
echo "New task definition: $NEW_TASK_DEF_ARN"
echo ""
echo "Service is being updated with new task definition."
echo "This will start new tasks with the environment variables."
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for tasks to start"
echo "2. Check task status: ./check-task-status.sh"
echo "3. View logs: ./view-logs.sh"
echo "4. Test connection: ./test-connection.sh"
echo ""
echo "ECS Console:"
echo "https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"


