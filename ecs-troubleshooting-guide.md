# ECS Troubleshooting Guide - "Error with backend"

## Quick Troubleshooting Steps

### 1. Check ECS Task Status

**Via AWS Console:**
1. Go to [ECS Console](https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters)
2. Click on cluster: `flawless-ostrich-q69e6k`
3. Go to **Tasks** tab
4. Click on the running task
5. Check:
   - **Status**: Should be "Running"
   - **Last status**: Should be "Running"
   - **Health status**: Check if it's "Healthy" or "Unhealthy"

**Via AWS CLI:**
```bash
export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot

# List tasks
aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION

# Get task details
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].{Status:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}'
```

---

### 2. Check Container Logs

**Via AWS Console:**
1. Go to your ECS Task
2. Click on the **Logs** tab
3. Select **CloudWatch Logs** (if configured)
4. Look for error messages

**Via AWS CLI:**
```bash
# Get log group name (usually: /ecs/{task-definition-family})
LOG_GROUP="/ecs/multi-ai-agent"

# View recent logs
aws logs tail $LOG_GROUP \
  --follow \
  --region $AWS_REGION \
  --format short

# Or get last 100 lines
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --region $AWS_REGION \
    --query 'logStreams[0].logStreamName' \
    --output text) \
  --limit 100 \
  --region $AWS_REGION \
  --query 'events[*].message' \
  --output text
```

**Common log errors to look for:**
- `ModuleNotFoundError`
- `Connection refused`
- `Port already in use`
- `Environment variable not set`
- `API key missing`

---

### 3. Check Security Group Rules

The security group must allow inbound traffic on port 8501.

**Via AWS Console:**
1. Go to your ECS Task
2. Click on the **Networking** tab
3. Note the **Security group** ID
4. Go to [EC2 Security Groups](https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups)
5. Find your security group
6. Check **Inbound rules**:
   - Should have: `Port 8501` from `0.0.0.0/0` (or your IP)
   - Protocol: `TCP`

**Via AWS CLI:**
```bash
# Get security group from task
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text)

SG_ID=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region $AWS_REGION \
  --query 'NetworkInterfaces[0].Groups[0].GroupId' \
  --output text)

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $AWS_REGION \
  --query 'SecurityGroups[0].IpPermissions'
```

**Fix if missing:**
```bash
# Add inbound rule for port 8501
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8501 \
  --cidr 0.0.0.0/0 \
  --region $AWS_REGION
```

---

### 4. Check Task Definition Configuration

**Common issues:**

1. **Port mapping incorrect:**
   - Container port: `8501`
   - Host port: (empty or `8501`)
   - Protocol: `TCP`

2. **Environment variables missing:**
   - `GROQ_API_KEY`
   - `TAVILY_API_KEY`

3. **Health check failing:**
   - Check health check configuration
   - Path should be accessible
   - Port should match container port

**Check via AWS Console:**
1. Go to Task Definition
2. Check **Container definitions**
3. Verify:
   - Port mappings
   - Environment variables
   - Health check settings

**Check via AWS CLI:**
```bash
# Get current task definition
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text)

# View task definition
aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --region $AWS_REGION \
  --query 'taskDefinition.containerDefinitions[0].{PortMappings:portMappings,Environment:environment,HealthCheck:healthCheck}'
```

---

### 5. Check Application-Specific Issues

**Test if container is running:**
```bash
# Get public IP
PUBLIC_IP="18.60.97.60"

# Test if port is open
nc -zv $PUBLIC_IP 8501
# or
curl -v http://$PUBLIC_IP:8501

# Check if it's a Streamlit app
curl http://$PUBLIC_IP:8501/_stcore/health
```

**Common Streamlit errors:**
- `Error with backend` usually means:
  1. Application crashed on startup
  2. Missing environment variables
  3. Import errors
  4. Port binding issues

---

### 6. Check CloudWatch Metrics

**Via AWS Console:**
1. Go to [CloudWatch](https://eu-north-1.console.aws.amazon.com/cloudwatch/)
2. Go to **Metrics** → **ECS**
3. Check:
   - `CPUUtilization`
   - `MemoryUtilization`
   - `RunningTaskCount`

**High CPU/Memory might indicate:**
- Application is stuck in a loop
- Memory leak
- Resource limits too low

---

### 7. Common Fixes

#### Fix 1: Missing Environment Variables
```bash
# Update task definition with environment variables
# (See ecs-environment-variables-guide.md)
```

#### Fix 2: Application Crashes on Startup
Check logs for:
- Import errors
- Missing dependencies
- Configuration errors

#### Fix 3: Port Not Accessible
- Verify security group allows port 8501
- Check if application binds to `0.0.0.0` not `127.0.0.1`
- Verify port mapping in task definition

#### Fix 4: Health Check Failing
```bash
# Disable health check temporarily to test
# Or update health check path/port
```

#### Fix 5: Resource Limits
```bash
# Increase CPU/Memory if application needs more
# Check task definition → Container → Resource limits
```

---

### 8. Quick Diagnostic Script

Save this as `diagnose-ecs.sh`:

```bash
#!/bin/bash
export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export PUBLIC_IP=18.60.97.60

echo "=== ECS Diagnostic ==="
echo ""

# 1. Check service status
echo "1. Service Status:"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}' \
  --output table

# 2. Check task status
echo ""
echo "2. Task Status:"
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text)

if [ ! -z "$TASK_ARN" ]; then
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].{Status:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason}' \
    --output table
else
  echo "  No tasks found!"
fi

# 3. Check port accessibility
echo ""
echo "3. Port Accessibility:"
if command -v nc &> /dev/null; then
  nc -zv $PUBLIC_IP 8501 2>&1 | head -1
else
  echo "  Install 'nc' (netcat) to test port"
fi

# 4. Check security group
echo ""
echo "4. Security Group (check manually in console):"
echo "  https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups"

# 5. Check logs
echo ""
echo "5. Recent Logs (last 5 lines):"
LOG_GROUP="/ecs/multi-ai-agent"
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name $LOG_GROUP \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --region $AWS_REGION \
  --query 'logStreams[0].logStreamName' \
  --output text 2>/dev/null)

if [ ! -z "$LOG_STREAM" ] && [ "$LOG_STREAM" != "None" ]; then
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $LOG_STREAM \
    --limit 5 \
    --region $AWS_REGION \
    --query 'events[-5:].message' \
    --output text
else
  echo "  No logs found. Check CloudWatch Logs configuration."
fi

echo ""
echo "=== End Diagnostic ==="
```

Run it:
```bash
chmod +x diagnose-ecs.sh
./diagnose-ecs.sh
```

---

### 9. Step-by-Step Debugging

**Step 1: Verify Task is Running**
- Check ECS Console → Tasks → Status should be "Running"

**Step 2: Check Logs**
- Look for startup errors
- Check for missing environment variables
- Look for import/module errors

**Step 3: Verify Network**
- Security group allows port 8501
- Test: `curl http://18.60.97.60:8501`

**Step 4: Check Application**
- Verify environment variables are set
- Check if application binds to `0.0.0.0:8501`
- Verify all dependencies are installed

**Step 5: Test Locally**
- Run container locally with same environment
- Test: `docker run -p 8501:8501 -e GROQ_API_KEY=... your-image`

---

### 10. Most Common Issues

1. **"Error with backend" in Streamlit:**
   - Usually means application crashed
   - Check CloudWatch logs for Python errors
   - Common: Missing API keys, import errors

2. **Connection refused:**
   - Security group not allowing port 8501
   - Application not binding to `0.0.0.0`

3. **502 Bad Gateway:**
   - Health check failing
   - Application not responding

4. **Timeout:**
   - Application taking too long to start
   - Increase health check grace period

---

## Quick Fix Checklist

- [ ] Task status is "Running"
- [ ] Health status is "Healthy" (or health check disabled)
- [ ] Security group allows port 8501 from your IP
- [ ] Environment variables are set (GROQ_API_KEY, TAVILY_API_KEY)
- [ ] Container logs show no errors
- [ ] Port 8501 is accessible: `curl http://18.60.97.60:8501`
- [ ] Application binds to `0.0.0.0:8501` not `127.0.0.1:8501`
- [ ] All dependencies are installed in Docker image
- [ ] Task has sufficient CPU/Memory resources

---

## Need More Help?

1. **Check CloudWatch Logs** - Most errors appear here
2. **Check Task Stopped Reason** - If task keeps stopping
3. **Check Service Events** - Deployment issues
4. **Test locally** - Run container with same config

