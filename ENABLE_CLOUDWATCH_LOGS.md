# How to Enable CloudWatch Logging for ECS Task

## Quick Method: Automated Script (Recommended)

```bash
cd "/Users/emmanuel/Documents/Projects/Andela GenAI/LLMOPS/MULTI-AI-AGENT-PROJECTS"
./enable-cloudwatch-logs.sh
```

This script will:
1. ✅ Create the log group `/ecs/multi-ai-agent`
2. ✅ Update your task definition with CloudWatch logging
3. ✅ Create a new task definition revision
4. ✅ Update your service to use the new revision

---

## Method 1: Via AWS Console (Step-by-Step)

### Step 1: Go to Task Definition
1. Open: [ECS Task Definitions](https://eu-north-1.console.aws.amazon.com/ecs/v2/task-definitions?region=eu-north-1)
2. Find: `multi-ai-agent`
3. Click on it

### Step 2: Create New Revision
1. Click **"Create new revision"** button (top right)

### Step 3: Configure Logging
1. Scroll down to **Container definitions**
2. Expand your container (likely named `multi-ai-agent`)
3. Scroll to the **Logging** section
4. Click **"Configure"** button

### Step 4: Set Logging Options
Configure the following:

| Field | Value |
|-------|-------|
| **Log driver** | Select `awslogs` |
| **Log group** | `/ecs/multi-ai-agent` |
| **Log stream prefix** | `ecs` (optional) |
| **Region** | `eu-north-1` |

**Screenshot guide:**
- Log driver dropdown: Select "awslogs"
- Log group: Type `/ecs/multi-ai-agent`
- Region: Should auto-detect or select `eu-north-1`

### Step 5: Save and Create
1. Click **"Save"** in the logging configuration
2. Scroll to bottom of page
3. Click **"Create"** button

### Step 6: Update Service
1. Go to: [ECS Services](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/flawless-ostrich-q69e6k/services)
2. Click on: `llmops-task-service-c2r05qot`
3. Click **"Update"** button
4. Under **Task definition**, select the **new revision** you just created
5. Click **"Update"** button
6. Wait for deployment (2-3 minutes)

### Step 7: Verify
1. Go to: [CloudWatch Logs](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups)
2. Look for: `/ecs/multi-ai-agent`
3. Click on it to see log streams

---

## Method 2: Via AWS CLI (Automated)

### Step 1: Create Log Group
```bash
aws logs create-log-group \
  --log-group-name /ecs/multi-ai-agent \
  --region eu-north-1
```

### Step 2: Get Current Task Definition
```bash
export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

# Get task definition ARN
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text)

# Download task definition
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region $AWS_REGION \
  --query 'taskDefinition' > task-def.json
```

### Step 3: Update Task Definition with Logging
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

### Step 4: Register New Task Definition
```bash
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://task-def-updated.json \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "New task definition: $NEW_TASK_DEF_ARN"
```

### Step 5: Update Service
```bash
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEF_ARN \
  --region $AWS_REGION

echo "✅ Service updated. New tasks will have CloudWatch logging."
```

---

## Method 3: Use the Automated Script

I've created a script that does all of this automatically:

```bash
./enable-cloudwatch-logs.sh
```

**What it does:**
1. Creates log group if it doesn't exist
2. Gets current task definition
3. Updates it with CloudWatch logging configuration
4. Registers new revision
5. Updates service

**Output:**
```
✅ Log group created
✅ Task definition updated with CloudWatch logging
✅ New task definition: arn:aws:ecs:eu-north-1:...
✅ Service update initiated
```

---

## Verify Logging is Enabled

### Check 1: Task Definition
```bash
# Get current task definition
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].taskDefinition' \
  --output text)

# Check log configuration
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region eu-north-1 \
  --query 'taskDefinition.containerDefinitions[0].logConfiguration' \
  --output json
```

Should show:
```json
{
  "logDriver": "awslogs",
  "options": {
    "awslogs-group": "/ecs/multi-ai-agent",
    "awslogs-region": "eu-north-1",
    "awslogs-stream-prefix": "ecs"
  }
}
```

### Check 2: Log Group Exists
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/multi-ai-agent \
  --region eu-north-1
```

### Check 3: Log Streams Appear
```bash
# Wait 2-3 minutes for new tasks to start, then:
aws logs describe-log-streams \
  --log-group-name /ecs/multi-ai-agent \
  --region eu-north-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

### Check 4: View Logs
```bash
# Follow logs in real-time
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1

# Or use the view script
./view-logs.sh
```

---

## Important: IAM Permissions

Your ECS **task execution role** needs CloudWatch Logs permissions.

### Check Your Task Execution Role:
1. Go to Task Definition
2. Note the **"Task execution role"** name
3. Go to: [IAM Roles](https://eu-north-1.console.aws.amazon.com/iamv2/home?region=eu-north-1#/roles)
4. Find that role
5. Check if it has CloudWatch Logs permissions

### Add Permissions if Missing:

**Option A: Attach AWS Managed Policy**
- Attach: `CloudWatchLogsFullAccess` (or more restrictive)

**Option B: Add Custom Policy**
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

### Common Role Names:
- `ecsTaskExecutionRole`
- `ecs-execution-role`
- Custom role name from your task definition

---

## Troubleshooting

### Issue: No logs appear after enabling

**Check 1: Task is using new revision**
```bash
# Verify service is using new task definition
aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].{TaskDef:taskDefinition,Deployments:deployments[*].taskDefinition}' \
  --output table
```

**Check 2: IAM Permissions**
- Verify task execution role has CloudWatch Logs permissions
- Check CloudWatch Logs console for permission errors

**Check 3: Task Status**
- Ensure tasks are running (not stopped)
- Check "Stopped reason" if tasks keep stopping

**Check 4: Wait Time**
- New tasks take 2-3 minutes to start
- Logs appear after container starts

### Issue: Permission Denied Errors

Add IAM permissions to task execution role (see above).

### Issue: Log Group Not Found

Create it manually:
```bash
aws logs create-log-group \
  --log-group-name /ecs/multi-ai-agent \
  --region eu-north-1
```

---

## Quick Reference

| Method | Command | Time |
|--------|---------|------|
| **Automated Script** | `./enable-cloudwatch-logs.sh` | ~30 seconds |
| **AWS Console** | Follow steps above | ~5 minutes |
| **AWS CLI** | Copy/paste commands | ~2 minutes |

**Recommended:** Use the automated script for fastest setup.

---

## After Enabling

1. **Wait 2-3 minutes** for new tasks to start
2. **View logs:**
   ```bash
   ./view-logs.sh
   # or
   aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1
   ```
3. **Check for errors:**
   ```bash
   ./check-chat-error.sh
   ```

---

## Summary

**Easiest way:**
```bash
./enable-cloudwatch-logs.sh
```

**Then verify:**
```bash
./view-logs.sh
```

That's it! Your logs will now appear in CloudWatch.


