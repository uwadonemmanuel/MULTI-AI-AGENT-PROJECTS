# Fix: No Running Tasks Found

## Problem
```
❌ No running tasks found!
```

## Quick Diagnosis

Run this to see why tasks aren't running:
```bash
./check-task-status.sh
```

This will show:
- Service status and desired count
- Why tasks stopped (if any)
- Recent service events
- Recommendations

## Common Causes & Fixes

### 1. Service Scaled to 0 (Most Common)

**Symptom:** Desired count = 0

**Fix:**
```bash
./start-ecs-service.sh
```

Or manually:
```bash
aws ecs update-service \
  --cluster flawless-ostrich-q69e6k \
  --service llmops-task-service-c2r05qot \
  --desired-count 1 \
  --region eu-north-1
```

### 2. Tasks Failing to Start

**Symptom:** Desired count > 0 but running count = 0

**Check stopped tasks:**
```bash
./check-task-status.sh
```

**Common reasons:**
- Missing environment variables (GROQ_API_KEY, TAVILY_API_KEY)
- Application crash on startup
- Health check failing
- Resource limits too low
- Task definition error

**Fix:**
1. Check stopped task reason (from script output)
2. Fix the issue (add env vars, fix code, etc.)
3. Force new deployment:
   ```bash
   ./start-ecs-service.sh
   ```

### 3. Tasks Pending (Starting)

**Symptom:** Pending count > 0

**Action:** Wait 2-3 minutes for tasks to start

**Check status:**
```bash
./check-task-status.sh
```

### 4. Service Not Found

**Symptom:** Service doesn't exist

**Fix:** Create the service or check service name

## Quick Fix Steps

### Step 1: Check Status
```bash
./check-task-status.sh
```

### Step 2: Start Service (if scaled to 0)
```bash
./start-ecs-service.sh
```

This will:
- Set desired count to 1
- Start new tasks
- Wait and show status

### Step 3: Check Why Tasks Stopped (if they keep stopping)

Look at the "Stopped tasks" section in the output. Common reasons:

**"Essential container in task exited"**
- Application crashed
- Check logs: `./view-logs.sh`
- Check environment variables

**"Task failed to start"**
- Resource limits too low
- Task definition error
- IAM permissions missing

**"Stopped by user"**
- Manually stopped
- Just restart: `./start-ecs-service.sh`

### Step 4: Verify Tasks Are Running

```bash
# Check status again
./check-task-status.sh

# Test connection
./test-connection.sh
```

## Manual Fixes

### Via AWS Console:

1. **Go to Service:**
   - [ECS Services](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/flawless-ostrich-q69e6k/services)
   - Click: `llmops-task-service-c2r05qot`

2. **Check Desired Count:**
   - If 0, click "Update"
   - Set "Desired count" to 1
   - Click "Update"

3. **Check Stopped Tasks:**
   - Go to "Tasks" tab
   - Click on stopped task
   - Check "Stopped reason"
   - Fix the issue

4. **Force New Deployment:**
   - Click "Update"
   - Check "Force new deployment"
   - Click "Update"

### Via AWS CLI:

```bash
# Update desired count
aws ecs update-service \
  --cluster flawless-ostrich-q69e6k \
  --service llmops-task-service-c2r05qot \
  --desired-count 1 \
  --region eu-north-1

# Force new deployment
aws ecs update-service \
  --cluster flawless-ostrich-q69e6k \
  --service llmops-task-service-c2r05qot \
  --force-new-deployment \
  --region eu-north-1
```

## Most Likely Fix

**90% chance:** Service is scaled to 0

**Quick fix:**
```bash
./start-ecs-service.sh
```

This will:
1. Set desired count to 1
2. Start tasks
3. Show status

## After Starting Tasks

1. **Wait 2-3 minutes** for tasks to start
2. **Check status:**
   ```bash
   ./check-task-status.sh
   ```
3. **Test connection:**
   ```bash
   ./test-connection.sh
   ```
4. **Check logs:**
   ```bash
   ./view-logs.sh
   ```

## Troubleshooting

### Tasks keep stopping?

1. **Check stopped reason:**
   ```bash
   ./check-task-status.sh
   ```

2. **Common fixes:**
   - Add missing environment variables
   - Fix application errors
   - Increase CPU/Memory limits
   - Fix health check

3. **Check logs:**
   ```bash
   ./view-logs.sh
   ```

### Service not found?

- Verify service name: `llmops-task-service-c2r05qot`
- Check cluster name: `flawless-ostrich-q69e6k`
- Service might need to be created

## Summary

**Quickest fix:**
```bash
./start-ecs-service.sh
```

**Check why it's not working:**
```bash
./check-task-status.sh
```



