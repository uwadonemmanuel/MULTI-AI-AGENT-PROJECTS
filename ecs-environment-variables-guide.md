# How to Add Environment Variables to ECS Task Definition

## Quick Steps

### 1. Navigate to ECS Console
- Go to: [AWS ECS Console](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters)
- Select region: **eu-north-1** (or your configured region)

### 2. Find Your Cluster and Service
- **Cluster Name**: `flawless-ostrich-q69e6k` (or check your Jenkinsfile)
- **Service Name**: `llmops-task-service-c2r05qot` (or check your Jenkinsfile)

### 3. Access Task Definition
1. Click on your **cluster name**
2. Go to the **Services** tab
3. Click on your **service name** (`llmops-task-service-c2r05qot`)
4. Click on the **Task Definition** link (e.g., `multi-ai-agent:1`, `multi-ai-agent:2`, etc.)
5. Click **Create new revision**

### 4. Edit Container Definition
1. Scroll down to find your container (likely named `multi-ai-agent`)
2. Expand the container definition
3. Scroll to the **Environment variables** section
4. Click **Add environment variable**

### 5. Add Environment Variables
Add the following environment variables:

| Key | Value | Description |
|-----|-------|-------------|
| `GROQ_API_KEY` | `gsk_...` | Your Groq API key for LLM access |
| `TAVILY_API_KEY` | `tvly-dev-...` | Your Tavily API key for web search |

**Example:**
```
Environment variable 1:
  Key: GROQ_API_KEY
  Value: gsk_your_actual_key_here

Environment variable 2:
  Key: TAVILY_API_KEY
  Value: tvly-dev-your_actual_key_here
```

### 6. Save and Deploy
1. Click **Create** (to create new task definition revision)
2. Go back to your **Service**
3. Click **Update**
4. Under **Task definition**, select the **new revision** you just created
5. Click **Update** to deploy

### 7. Wait for Deployment
- The service will start new tasks with the updated environment variables
- Old tasks will be stopped
- Monitor the **Deployments** tab to see progress

---

## Alternative: Using AWS CLI

If you prefer using the command line:

```bash
# Set your variables
export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export GROQ_API_KEY="gsk_..."
export TAVILY_API_KEY="tvly-dev-..."

# Get current task definition
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

# Update environment variables (requires jq or Python)
python3 << 'PYEOF'
import json

with open('task-def.json', 'r') as f:
    task_def = json.load(f)

# Update environment variables
container_def = task_def['containerDefinitions'][0]

# Remove existing env vars if any
env_vars = [e for e in container_def.get('environment', []) 
            if e['name'] not in ['GROQ_API_KEY', 'TAVILY_API_KEY']]

# Add new env vars
env_vars.extend([
    {'name': 'GROQ_API_KEY', 'value': 'gsk_...'},  # Replace with actual key
    {'name': 'TAVILY_API_KEY', 'value': 'tvly-dev-...'}  # Replace with actual key
])

container_def['environment'] = env_vars

# Remove fields that can't be set
for key in ['taskDefinitionArn', 'revision', 'status', 'requiresAttributes', 
            'compatibilities', 'registeredAt', 'registeredBy']:
    task_def.pop(key, None)

# Save updated task definition
with open('task-def-updated.json', 'w') as f:
    json.dump(task_def, f, indent=2)

print("✅ Updated task definition saved to task-def-updated.json")
PYEOF

# Register new task definition
NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json file://task-def-updated.json \
  --region $AWS_REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

# Update service to use new task definition
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEF_ARN \
  --region $AWS_REGION

echo "✅ Service updated with new task definition"
```

---

## Verify Environment Variables

After deployment, verify the environment variables are set:

### Option 1: Check via AWS Console
1. Go to your ECS Service
2. Click on a **Running task**
3. Click on the **Container** tab
4. Scroll to **Environment** section
5. Verify `GROQ_API_KEY` and `TAVILY_API_KEY` are present

### Option 2: Check via AWS CLI
```bash
# Get running task
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text)

# Describe task (shows environment variables in task definition)
aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].containers[0].environment'
```

---

## Security Best Practices

### ⚠️ Important Security Notes:

1. **Never commit API keys to Git**
   - Keep keys in AWS Secrets Manager or Parameter Store
   - Use IAM roles for ECS tasks when possible

2. **Use AWS Secrets Manager (Recommended)**
   Instead of plain environment variables, use Secrets Manager:
   ```json
   {
     "secrets": [
       {
         "name": "GROQ_API_KEY",
         "valueFrom": "arn:aws:secretsmanager:eu-north-1:ACCOUNT_ID:secret:groq-api-key"
       },
       {
         "name": "TAVILY_API_KEY",
         "valueFrom": "arn:aws:secretsmanager:eu-north-1:ACCOUNT_ID:secret:tavily-api-key"
       }
     ]
   }
   ```

3. **Rotate keys regularly**
   - Update keys in Secrets Manager
   - Create new task definition revision
   - Update service

---

## Troubleshooting

### Environment variables not appearing?
1. Check task definition revision is correct
2. Verify service is using the new revision
3. Check container logs for errors
4. Ensure task has been restarted with new definition

### Application not reading variables?
1. Check your application code reads from `os.getenv('GROQ_API_KEY')`
2. Verify variable names match exactly (case-sensitive)
3. Check container logs for missing key errors

### Need to update keys?
1. Create new task definition revision with updated values
2. Update service to use new revision
3. Old tasks will be stopped, new ones started

---

## Quick Reference

**Your Current Setup:**
- **Region**: `eu-north-1`
- **Cluster**: `flawless-ostrich-q69e6k`
- **Service**: `llmops-task-service-c2r05qot`
- **Container**: `multi-ai-agent`
- **Required Variables**: `GROQ_API_KEY`, `TAVILY_API_KEY`

**AWS Console Links:**
- [ECS Clusters](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters)
- [Your Cluster](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/flawless-ostrich-q69e6k/services)

