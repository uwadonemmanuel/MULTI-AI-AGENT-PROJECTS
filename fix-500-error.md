# Fix 500 Internal Server Error on /chat Endpoint

## Quick Diagnosis

Run this to see the full error:
```bash
./check-chat-error.sh
```

Or manually check logs:
```bash
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1
```

## Common Causes & Fixes

### 1. Missing GROQ_API_KEY (Most Common)

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

**Verify:**
```bash
# Check if env var is set in task definition
aws ecs describe-task-definition \
  --task-definition multi-ai-agent \
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
- Check that the model name is in the allowed list:
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

### 5. Import/Module Errors

**Error in logs:**
```
ModuleNotFoundError: No module named '...'
ImportError: ...
```

**Fix:**
- Check Dockerfile includes all dependencies
- Rebuild Docker image
- Check requirements.txt

### 6. LangChain/LangGraph Errors

**Error in logs:**
```
TypeError: ...
AttributeError: ...
```

**Fix:**
- Check LangChain version compatibility
- Update dependencies if needed

## Step-by-Step Fix

### Step 1: Get Full Error Details

```bash
# View recent logs with full traceback
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1 | grep -A 20 "500\|Error\|Traceback"
```

### Step 2: Check Environment Variables

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
  --query 'taskDefinition.containerDefinitions[0].environment[*]' \
  --output table
```

### Step 3: Add Missing Environment Variables

If `GROQ_API_KEY` or `TAVILY_API_KEY` are missing:

1. **Via AWS Console:**
   - Go to Task Definition
   - Create new revision
   - Add environment variables
   - Update service

2. **Via AWS CLI:**
   ```bash
   # Get current task definition
   aws ecs describe-task-definition \
     --task-definition $TASK_DEF_ARN \
     --region eu-north-1 \
     --query 'taskDefinition' > task-def.json
   
   # Update with Python (see script below)
   python3 update-env-vars.py task-def.json
   
   # Register new revision
   NEW_TASK_DEF_ARN=$(aws ecs register-task-definition \
     --cli-input-json file://task-def-updated.json \
     --region eu-north-1 \
     --query 'taskDefinition.taskDefinitionArn' \
     --output text)
   
   # Update service
   aws ecs update-service \
     --cluster flawless-ostrich-q69e6k \
     --service llmops-task-service-c2r05qot \
     --task-definition $NEW_TASK_DEF_ARN \
     --region eu-north-1
   ```

### Step 4: Verify Fix

```bash
# Check service is updating
aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].{Status:status,Deployments:deployments[*].{Status:status,TaskDef:taskDefinition}}' \
  --output table

# Test the endpoint
curl -X POST http://18.60.97.60:8501/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are a helpful assistant.",
    "messages": ["Hello"],
    "allow_search": false
  }'
```

## Quick Fix Script

Save this as `update-env-vars.py`:

```python
#!/usr/bin/env python3
import json
import sys

if len(sys.argv) < 2:
    print("Usage: python3 update-env-vars.py <task-def.json>")
    sys.exit(1)

with open(sys.argv[1], 'r') as f:
    task_def = json.load(f)

container_def = task_def['containerDefinitions'][0]

# Get existing environment variables
env_vars = container_def.get('environment', [])

# Check if keys exist
has_groq = any(e.get('name') == 'GROQ_API_KEY' for e in env_vars)
has_tavily = any(e.get('name') == 'TAVILY_API_KEY' for e in env_vars)

# Remove existing if present
env_vars = [e for e in env_vars 
            if e.get('name') not in ['GROQ_API_KEY', 'TAVILY_API_KEY']]

# Add new ones (you'll need to provide actual keys)
if not has_groq:
    groq_key = input("Enter GROQ_API_KEY (or press Enter to skip): ").strip()
    if groq_key:
        env_vars.append({'name': 'GROQ_API_KEY', 'value': groq_key})

if not has_tavily:
    tavily_key = input("Enter TAVILY_API_KEY (or press Enter to skip): ").strip()
    if tavily_key:
        env_vars.append({'name': 'TAVILY_API_KEY', 'value': tavily_key})

container_def['environment'] = env_vars

# Remove fields that can't be set
for key in ['taskDefinitionArn', 'revision', 'status', 'requiresAttributes', 
            'compatibilities', 'registeredAt', 'registeredBy']:
    task_def.pop(key, None)

# Save updated task definition
with open('task-def-updated.json', 'w') as f:
    json.dump(task_def, f, indent=2)

print("✅ Updated task definition saved to task-def-updated.json")
print(f"   Environment variables: {[e['name'] for e in env_vars]}")
```

## Most Likely Issue

Based on the code, the **most likely cause** is:

**Missing `GROQ_API_KEY` environment variable**

When `ChatGroq(model=llm_id)` is called without an API key, it will fail and cause a 500 error.

**Quick Fix:**
1. Go to ECS Task Definition
2. Add `GROQ_API_KEY` environment variable
3. Add `TAVILY_API_KEY` environment variable (if using search)
4. Create new revision
5. Update service

## Verify After Fix

1. **Check logs:**
   ```bash
   aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1
   ```

2. **Test endpoint:**
   ```bash
   curl -X POST http://18.60.97.60:8501/chat \
     -H "Content-Type: application/json" \
     -d '{
       "model_name": "llama-3.1-8b-instant",
       "system_prompt": "You are helpful.",
       "messages": ["Test"],
       "allow_search": false
     }'
   ```

3. **Should see:**
   - `200 OK` response
   - No errors in logs
   - Valid JSON response with `{"response": "..."}`

