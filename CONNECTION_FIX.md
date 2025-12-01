# Fix Connection Timeout Issue

## Problem
```
curl: (28) Failed to connect to 13.60.97.107 port 8501 after 75002 ms: Couldn't connect to server
```

## Root Causes & Fixes

### 1. Application Binding Issue (FIXED)

**Problem:** Backend was binding to `127.0.0.1` instead of `0.0.0.0`

**Fix Applied:**
- Changed `app/main.py` to bind backend to `0.0.0.0:9999`
- This makes the service accessible from outside the container

**Status:** ✅ Fixed in code

### 2. Security Group Not Allowing Port 8501

**Check:**
```bash
./troubleshoot-connection.sh
```

**Fix:**
```bash
./fix-security-group.sh
```

Or manually:
1. Go to: [EC2 Security Groups](https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups?region=eu-north-1)
2. Find your security group (from ECS task)
3. Add inbound rule:
   - Type: Custom TCP
   - Port: 8501
   - Source: 0.0.0.0/0 (or your IP)

### 3. Task Not Running

**Check:**
```bash
./troubleshoot-connection.sh
```

**Fix:**
- Go to ECS Console
- Check task status
- If stopped, check "Stopped reason"
- Common: Missing environment variables, application crash

### 4. Wrong IP Address

**Check:**
```bash
# Get actual public IP of running task
TASK_ARN=$(aws ecs list-tasks \
  --cluster flawless-ostrich-q69e6k \
  --service-name llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster flawless-ostrich-q69e6k \
  --tasks $TASK_ARN \
  --region eu-north-1 \
  --query 'tasks[0].attachments[0].details[?name==`publicIPv4Address`].value' \
  --output text
```

### 5. Port Mapping Issue

**Check Task Definition:**
- Container port: 8501 (for Streamlit)
- Container port: 9999 (for FastAPI)
- Both should be mapped

## Quick Fix Steps

### Step 1: Run Diagnostic
```bash
./troubleshoot-connection.sh
```

This will show:
- Task status
- Security group rules
- Port mappings
- Application logs

### Step 2: Fix Security Group (if needed)
```bash
./fix-security-group.sh
```

### Step 3: Rebuild and Deploy

After fixing `app/main.py`:
1. Commit changes:
   ```bash
   git add app/main.py
   git commit -m "Fix: Bind backend to 0.0.0.0 for external access"
   git push
   ```

2. Jenkins pipeline will:
   - Rebuild Docker image
   - Push to ECR
   - Deploy to ECS

3. Wait 2-3 minutes for deployment

### Step 4: Verify

```bash
# Test Streamlit (port 8501)
curl http://18.60.97.60:8501

# Test FastAPI (port 9999)
curl http://18.60.97.60:9999/docs
```

## Important Notes

### Ports Used:
- **8501**: Streamlit frontend
- **9999**: FastAPI backend

### Application Binding:
- ✅ **Fixed**: Backend now binds to `0.0.0.0:9999`
- ⚠️ **Check**: Streamlit should also bind to `0.0.0.0:8501`

### Streamlit Configuration:

If Streamlit is also binding to localhost, you may need to create a `.streamlit/config.toml`:

```toml
[server]
address = "0.0.0.0"
port = 8501
```

Or set environment variable:
```bash
STREAMLIT_SERVER_ADDRESS=0.0.0.0
STREAMLIT_SERVER_PORT=8501
```

## After Fixing

1. **Rebuild Docker image** (via Jenkins)
2. **Deploy to ECS** (via Jenkins)
3. **Wait for deployment** (2-3 minutes)
4. **Test connection:**
   ```bash
curl http://13.60.97.107:8501
curl http://13.60.97.107:9999/docs
   ```

## Troubleshooting Script

Run the comprehensive diagnostic:
```bash
./troubleshoot-connection.sh
```

This will identify the exact issue.

