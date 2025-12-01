# Fix: Missing GROQ_API_KEY and TAVILY_API_KEY

## Problem
```
ERROR - GROQ_API_KEY is not set in environment variables
```

This causes tasks to crash or fail when trying to use the AI agent.

## Quick Fix

### Option 1: Automated Script (Recommended)

```bash
./add-env-vars-to-ecs.sh
```

This script will:
1. Get your current task definition
2. Prompt for API keys
3. Add them to the task definition
4. Register a new revision
5. Update the service

### Option 2: Via AWS Console

1. **Go to ECS Task Definitions:**
   - [Task Definitions](https://eu-north-1.console.aws.amazon.com/ecs/v2/task-definitions?region=eu-north-1)

2. **Find your task definition:**
   - Look for the task definition used by your service
   - Click on it

3. **Create new revision:**
   - Click "Create new revision"
   - Scroll to "Container definitions"
   - Click on your container

4. **Add environment variables:**
   - Scroll to "Environment variables"
   - Click "Add environment variable"
   - Add:
     - Name: `GROQ_API_KEY`
     - Value: `gsk_...` (your Groq API key)
   - Click "Add environment variable" again
   - Add:
     - Name: `TAVILY_API_KEY`
     - Value: `tvly-dev-...` (your Tavily API key)

5. **Create revision:**
   - Click "Create"

6. **Update service:**
   - Go to your service
   - Click "Update"
   - Select the new task definition revision
   - Check "Force new deployment"
   - Click "Update"

### Option 3: Via AWS CLI

```bash
# Set your API keys
export GROQ_API_KEY="gsk_..."
export TAVILY_API_KEY="tvly-dev-..."

# Run the script
./add-env-vars-to-ecs.sh
```

## Required Environment Variables

### GROQ_API_KEY (Required)
- **Purpose:** Used to authenticate with Groq API for LLM
- **Format:** `gsk_...`
- **Where to get:** [Groq Console](https://console.groq.com/)

### TAVILY_API_KEY (Optional but Recommended)
- **Purpose:** Used for web search functionality
- **Format:** `tvly-dev-...` or `tvly-...`
- **Where to get:** [Tavily Console](https://tavily.com/)
- **Note:** Only needed if `allow_search=True` in API calls

## Verify Environment Variables Are Set

After updating, check if variables are set:

```bash
# Get current task definition
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].taskDefinition' \
  --output text)

# Check environment variables
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region eu-north-1 \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`GROQ_API_KEY` || name==`TAVILY_API_KEY`]' \
  --output table
```

## After Adding Environment Variables

1. **Wait 2-3 minutes** for new tasks to start

2. **Check task status:**
   ```bash
   ./check-task-status.sh
   ```

3. **View logs to verify:**
   ```bash
   ./view-logs.sh
   ```
   
   You should see:
   ```
   INFO - ChatGroq initialized successfully
   ```
   
   Instead of:
   ```
   ERROR - GROQ_API_KEY is not set in environment variables
   ```

4. **Test the application:**
   ```bash
   ./test-connection.sh
   ```

## Troubleshooting

### Tasks Still Failing?

1. **Check logs:**
   ```bash
   ./view-logs.sh
   ```

2. **Verify API keys are correct:**
   - Test Groq API key: https://console.groq.com/
   - Test Tavily API key: https://tavily.com/

3. **Check task definition revision:**
   - Make sure service is using the new revision
   - Force new deployment if needed

### API Key Format Issues?

- **GROQ_API_KEY:** Should start with `gsk_`
- **TAVILY_API_KEY:** Should start with `tvly-` or `tvly-dev-`

### Service Not Updating?

Force a new deployment:
```bash
aws ecs update-service \
  --cluster flawless-ostrich-q69e6k \
  --service llmops-task-service-c2r05qot \
  --force-new-deployment \
  --region eu-north-1
```

## Security Best Practices

⚠️ **Important:** API keys are sensitive!

- **Don't commit API keys to Git**
- **Use AWS Secrets Manager** for production (recommended)
- **Rotate keys regularly**
- **Use least privilege IAM roles**

For production, consider using AWS Secrets Manager:
1. Store API keys in Secrets Manager
2. Reference secrets in task definition
3. Task execution role needs `secretsmanager:GetSecretValue` permission

## Summary

**Quickest fix:**
```bash
./add-env-vars-to-ecs.sh
```

**What it does:**
1. Adds `GROQ_API_KEY` and `TAVILY_API_KEY` to task definition
2. Creates new revision
3. Updates service to use new revision
4. Starts new tasks with environment variables

**After running:**
- Wait 2-3 minutes
- Check logs: `./view-logs.sh`
- Test: `./test-connection.sh`

