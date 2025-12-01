# Fix Connection Timeout - Complete Guide

## Problem
```
curl: (28) Failed to connect to 13.60.97.107 port 8501 after 75002 ms: Couldn't connect to server
```

## Root Causes Identified

### 1. ✅ Application Binding Issue (FIXED)

**Problem:** Both services were binding to `127.0.0.1` (localhost) instead of `0.0.0.0`

**Fixes Applied:**
- ✅ Backend (FastAPI): Changed to bind to `0.0.0.0:9999`
- ✅ Frontend (Streamlit): Changed to bind to `0.0.0.0:8501`

**Files Changed:**
- `app/main.py` - Both `run_backend()` and `run_frontend()` functions

### 2. Security Group Rules

**Check:**
```bash
./troubleshoot-connection.sh
```

**Fix:**
```bash
./fix-security-group.sh
```

**Manual Fix:**
1. Go to: [EC2 Security Groups](https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups?region=eu-north-1)
2. Find security group from your ECS task
3. Add inbound rules:
   - **Rule 1:** Port 8501, TCP, Source: 0.0.0.0/0
   - **Rule 2:** Port 9999, TCP, Source: 0.0.0.0/0

### 3. Task Not Running

**Check:**
```bash
./troubleshoot-connection.sh
```

**Common Issues:**
- Application crashed on startup
- Missing environment variables
- Health check failing

## Complete Fix Steps

### Step 1: Run Diagnostic
```bash
./troubleshoot-connection.sh
```

This will identify:
- ✅ Task status
- ✅ Security group rules
- ✅ Port mappings
- ✅ Public IP address
- ✅ Application logs

### Step 2: Fix Security Group (if needed)
```bash
./fix-security-group.sh
```

This will:
- Find your security group
- Add port 8501 rule if missing
- Add port 9999 rule if missing

### Step 3: Commit and Deploy Code Changes

The code fixes are already applied. Now deploy:

```bash
# Commit the binding fixes
git add app/main.py
git commit -m "Fix: Bind services to 0.0.0.0 for external access"
git push
```

Jenkins pipeline will:
1. Rebuild Docker image
2. Push to ECR
3. Deploy to ECS

### Step 4: Wait and Verify

**Wait 2-3 minutes** for deployment, then:

```bash
# Test Streamlit (port 8501)
curl -I http://13.60.97.107:8501

# Test FastAPI (port 9999)
curl http://13.60.97.107:9999/docs

# Or use browser:
# http://13.60.97.107:8501
```

## What Was Fixed

### Before:
```python
# Backend - only accessible from localhost
subprocess.run(["uvicorn", "app.backend.api:app", "--host", "127.0.0.1", "--port", "9999"])

# Frontend - only accessible from localhost
subprocess.run(["streamlit", "run", "app/frontend/ui.py"])
```

### After:
```python
# Backend - accessible from outside container
subprocess.run(["uvicorn", "app.backend.api:app", "--host", "0.0.0.0", "--port", "9999"])

# Frontend - accessible from outside container
subprocess.run([
    "streamlit", "run", "app/frontend/ui.py",
    "--server.address", "0.0.0.0",
    "--server.port", "8501"
])
```

## Verification Checklist

After deployment, verify:

- [ ] Task is RUNNING (not STOPPED)
- [ ] Security group allows port 8501
- [ ] Security group allows port 9999
- [ ] Port 8501 is accessible: `curl http://13.60.97.107:8501`
- [ ] Port 9999 is accessible: `curl http://13.60.97.107:9999/docs`
- [ ] Application logs show services starting
- [ ] No errors in CloudWatch logs

## Quick Test Commands

```bash
# Test port connectivity
nc -zv 13.60.97.107 8501
nc -zv 13.60.97.107 9999

# Test HTTP endpoints
curl http://13.60.97.107:8501
curl http://13.60.97.107:9999/docs

# Test API endpoint
curl -X POST http://13.60.97.107:9999/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "llama-3.1-8b-instant",
    "system_prompt": "You are helpful.",
    "messages": ["Hello"],
    "allow_search": false
  }'
```

## If Still Not Working

1. **Check task logs:**
   ```bash
   ./view-logs.sh
   ```

2. **Check if application started:**
   ```bash
   aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1 | grep -i "starting\|error\|failed"
   ```

3. **Verify task is using new image:**
   - Check ECS Service → Deployments tab
   - Verify new task definition revision is active

4. **Check public IP hasn't changed:**
   ```bash
   ./troubleshoot-connection.sh
   ```

## Summary

**Main Fix:** Changed application binding from `127.0.0.1` to `0.0.0.0`

**Next Steps:**
1. ✅ Code fixed (already done)
2. ⏳ Commit and push
3. ⏳ Jenkins pipeline rebuilds and deploys
4. ⏳ Fix security group if needed
5. ⏳ Test connection

After these steps, the connection should work!

