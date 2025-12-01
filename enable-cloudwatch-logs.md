# Enable CloudWatch Logs for ECS Task

## Problem
No CloudWatch log streams found - logging is not configured for your ECS task.

## Solution: Enable CloudWatch Logging

### Option 1: Via AWS Console (Easiest)

1. **Go to Task Definition:**
   - [ECS Task Definitions](https://eu-north-1.console.aws.amazon.com/ecs/v2/task-definitions)
   - Find: `multi-ai-agent`
   - Click on it

2. **Create New Revision:**
   - Click "Create new revision"

3. **Edit Container:**
   - Expand the container definition (e.g., `multi-ai-agent`)
   - Scroll to **Logging** section
   - Click **Configure**

4. **Configure Logging:**
   - **Log driver**: Select `awslogs`
   - **Log group**: Enter `/ecs/multi-ai-agent` (or create new)
   - **Log stream prefix**: Enter `ecs` (optional)
   - **Region**: `eu-north-1`
   - Click **Save**

5. **Create Revision:**
   - Click "Create" at the bottom

6. **Update Service:**
   - Go to your Service: `llmops-task-service-c2r05qot`
   - Click "Update"
   - Under "Task definition", select the new revision
   - Click "Update"

### Option 2: Via AWS CLI

#### Step 1: Create Log Group (if it doesn't exist)
```bash
aws logs create-log-group \
  --log-group-name /ecs/multi-ai-agent \
  --region eu-north-1
```

#### Step 2: Get Current Task Definition
```bash
export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text)

# Get task definition JSON
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region $AWS_REGION \
  --query 'taskDefinition' > task-def.json
```

#### Step 3: Update Task Definition with Logging
```bash
python3 << 'PYEOF'
import json

with open('task-def.json', 'r') as f:
    task_def = json.load(f)

container_def = task_def['containerDefinitions'][0]

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

print("✅ Task definition updated with CloudWatch logging")
PYEOF
```

#### Step 4: Register New Task Definition
```bash
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://task-def-updated.json \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "New task definition: $NEW_TASK_DEF_ARN"
```

#### Step 5: Update Service
```bash
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEF_ARN \
  --region $AWS_REGION

echo "✅ Service updated. New tasks will have CloudWatch logging enabled."
```

### Option 3: Use the Automated Script

I'll create a script to do this automatically.

## Verify Logging is Enabled

After updating:

1. **Wait for new tasks to start** (check ECS console)

2. **Check for log streams:**
   ```bash
   aws logs describe-log-streams \
     --log-group-name /ecs/multi-ai-agent \
     --region eu-north-1 \
     --order-by LastEventTime \
     --descending \
     --max-items 5
   ```

3. **View logs:**
   ```bash
   aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1
   ```

## IAM Permissions Required

Your ECS task execution role needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:eu-north-1:*:log-group:/ecs/multi-ai-agent:*"
    }
  ]
}
```

**Check your task execution role:**
1. Go to Task Definition
2. Check "Task execution role"
3. Go to IAM → Roles → Find that role
4. Add the CloudWatch Logs permissions if missing

## Troubleshooting

### Still no logs after enabling?

1. **Check task execution role has permissions**
2. **Verify log group exists:**
   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix /ecs/multi-ai-agent \
     --region eu-north-1
   ```

3. **Check task is using new revision:**
   - Go to ECS Service
   - Check "Deployments" tab
   - Verify new task definition is active

4. **Check task status:**
   - If task keeps stopping, check "Stopped reason"
   - Common: Missing IAM permissions

## Quick Check Script

Run this to check if logging is configured:

```bash
./find-logs.sh
```



