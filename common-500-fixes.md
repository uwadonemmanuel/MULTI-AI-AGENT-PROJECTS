# Common 500 Error Fixes for /chat Endpoint

Based on the code, here are the most likely causes and fixes:

## Most Common Causes

### 1. Missing GROQ_API_KEY (Most Likely)

**Error in logs:**
```
ValueError: GROQ_API_KEY is required
```
or
```
AuthenticationError: Invalid API key
```

**Fix:**
1. Go to ECS Task Definition
2. Add environment variable: `GROQ_API_KEY` = `gsk_...`
3. Create new revision
4. Update service

**Quick check:**
```bash
# Check if env var is set
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].taskDefinition' \
  --output text)

aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region eu-north-1 \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`GROQ_API_KEY`]'
```

### 2. Missing TAVILY_API_KEY (When allow_search=True)

**Error in logs:**
```
ValueError: TAVILY_API_KEY is required when allow_search is True
```

**Fix:**
1. Go to ECS Task Definition
2. Add environment variable: `TAVILY_API_KEY` = `tvly-dev-...`
3. Create new revision
4. Update service

### 3. Invalid Model Name

**Error in logs:**
```
Invalid model name
```

**Fix:**
- Use one of these models:
  - `llama-3.1-8b-instant`
  - `llama-3.3-70b-versatile`
  - `openai/gpt-oss-120b`
  - `openai/gpt-oss-20b`
  - `meta-llama/llama-guard-4-12b`

### 4. Groq API Error

**Error in logs:**
```
Groq API error: ...
```

**Possible causes:**
- Invalid API key
- Rate limit exceeded
- Model decommissioned
- Network issues

**Fix:**
- Verify API key is correct
- Check Groq API status
- Try a different model
- Wait and retry (if rate limited)

### 5. LangChain/LangGraph Errors

**Error in logs:**
```
TypeError: ...
AttributeError: ...
ModuleNotFoundError: ...
```

**Fix:**
- Check Dockerfile includes all dependencies
- Rebuild Docker image
- Check requirements.txt

### 6. ChatGroq Initialization Error

**Error in logs:**
```
Error initializing ChatGroq
```

**Fix:**
- Ensure GROQ_API_KEY is set
- Check API key format is correct
- Verify network connectivity

## Quick Diagnostic Steps

### Step 1: Get Full Error
```bash
./find-500-error.sh
```

### Step 2: Check Environment Variables
```bash
# Check if env vars are set
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].taskDefinition' \
  --output text)

aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region eu-north-1 \
  --query 'taskDefinition.containerDefinitions[0].environment[*]' \
  --output table
```

### Step 3: Test Endpoint
```bash
curl -X POST http://13.60.97.107:9999/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are helpful.",
    "messages": ["Test"],
    "allow_search": false
  }' -v
```

## Most Likely Fix

**90% chance it's missing GROQ_API_KEY**

Quick fix:
1. Go to ECS Task Definition
2. Add `GROQ_API_KEY` environment variable
3. Add `TAVILY_API_KEY` environment variable (if using search)
4. Create new revision
5. Update service
6. Wait 2-3 minutes
7. Test again

See: `ecs-environment-variables-guide.md` for detailed steps.

