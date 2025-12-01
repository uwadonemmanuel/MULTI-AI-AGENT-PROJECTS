#!/bin/bash
# Troubleshoot connection issues to ECS service

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export PUBLIC_IP=13.60.97.107
export PORT=8501

echo "=========================================="
echo "Troubleshooting Connection Issues"
echo "=========================================="
echo "Target: http://$PUBLIC_IP:$PORT"
echo ""

# 1. Check if task is running
echo "1. Checking ECS Task Status..."
echo "----------------------------------------"
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text 2>/dev/null)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "   ❌ No running tasks found!"
  echo "   Check ECS console for task status"
  echo "   https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/tasks"
else
  echo "   ✅ Task found: $TASK_ARN"
  
  TASK_STATUS=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].{Status:lastStatus,HealthStatus:healthStatus,DesiredStatus:desiredStatus}' \
    --output table 2>/dev/null)
  
  echo "$TASK_STATUS"
  
  # Check if task is actually running
  LAST_STATUS=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].lastStatus' \
    --output text 2>/dev/null)
  
  if [ "$LAST_STATUS" != "RUNNING" ]; then
    echo "   ⚠️  Task is not RUNNING (status: $LAST_STATUS)"
    echo "   Check stopped reason:"
    aws ecs describe-tasks \
      --cluster $CLUSTER_NAME \
      --tasks $TASK_ARN \
      --region $AWS_REGION \
      --query 'tasks[0].{StoppedReason:stoppedReason,StoppedAt:stoppedAt}' \
      --output table 2>/dev/null
  fi
fi

# 2. Check service status
echo ""
echo "2. Checking ECS Service Status..."
echo "----------------------------------------"
SERVICE_STATUS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,PendingCount:pendingCount}' \
  --output table 2>/dev/null)

if [ ! -z "$SERVICE_STATUS" ]; then
  echo "$SERVICE_STATUS"
else
  echo "   ❌ Could not get service status"
fi

# 3. Check security group
echo ""
echo "3. Checking Security Group Rules..."
echo "----------------------------------------"
if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
  ENI_ID=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text 2>/dev/null)
  
  if [ ! -z "$ENI_ID" ] && [ "$ENI_ID" != "None" ]; then
    SG_ID=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $ENI_ID \
      --region $AWS_REGION \
      --query 'NetworkInterfaces[0].Groups[0].GroupId' \
      --output text 2>/dev/null)
    
    if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
      echo "   Security Group: $SG_ID"
      echo "   Network Interface: $ENI_ID"
      echo ""
      echo "   Inbound Rules:"
      PORT_RULE=$(aws ec2 describe-security-groups \
        --group-ids $SG_ID \
        --region $AWS_REGION \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`$PORT\` || ToPort==\`$PORT\` || (FromPort<=$PORT && ToPort>=$PORT)]" \
        --output table 2>/dev/null)
      
      if [ ! -z "$PORT_RULE" ]; then
        echo "$PORT_RULE"
        echo "   ✅ Port $PORT rule found"
      else
        echo "   ❌ Port $PORT rule NOT found!"
        echo "   You need to add an inbound rule:"
        echo "     Type: Custom TCP"
        echo "     Port: $PORT"
        echo "     Source: 0.0.0.0/0 (or your IP)"
        echo ""
        echo "   Add rule:"
        echo "   aws ec2 authorize-security-group-ingress \\"
        echo "     --group-id $SG_ID \\"
        echo "     --protocol tcp \\"
        echo "     --port $PORT \\"
        echo "     --cidr 0.0.0.0/0 \\"
        echo "     --region $AWS_REGION"
      fi
    else
      echo "   ⚠️  Could not determine security group"
    fi
  else
    echo "   ⚠️  Could not determine network interface"
  fi
else
  echo "   ⚠️  No task found to check security group"
fi

# 4. Check public IP
echo ""
echo "4. Verifying Public IP..."
echo "----------------------------------------"
if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
  TASK_PUBLIC_IP=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].attachments[0].details[?name==`publicIPv4Address`].value' \
    --output text 2>/dev/null)
  
  if [ ! -z "$TASK_PUBLIC_IP" ] && [ "$TASK_PUBLIC_IP" != "None" ]; then
    echo "   Task Public IP: $TASK_PUBLIC_IP"
    if [ "$TASK_PUBLIC_IP" != "$PUBLIC_IP" ]; then
      echo "   ⚠️  IP mismatch! Expected: $PUBLIC_IP, Got: $TASK_PUBLIC_IP"
      echo "   Try using: http://$TASK_PUBLIC_IP:$PORT"
    else
      echo "   ✅ IP matches"
    fi
  else
    echo "   ⚠️  Could not get public IP from task"
    echo "   The IP might be from a load balancer or different source"
  fi
fi

# 5. Test port connectivity
echo ""
echo "5. Testing Port Connectivity..."
echo "----------------------------------------"
if command -v nc &> /dev/null; then
  echo "   Testing $PUBLIC_IP:$PORT with netcat..."
  if timeout 5 nc -zv $PUBLIC_IP $PORT 2>&1 | grep -q "succeeded"; then
    echo "   ✅ Port $PORT is open and accessible"
  else
    echo "   ❌ Port $PORT is NOT accessible"
    echo "   Possible causes:"
    echo "     - Security group blocking port"
    echo "     - Application not running"
    echo "     - Application not binding to 0.0.0.0"
    echo "     - Firewall blocking connection"
  fi
else
  echo "   ⚠️  'nc' (netcat) not installed"
  echo "   Install: brew install netcat (macOS) or apt-get install netcat (Linux)"
fi

# 6. Check application logs
echo ""
echo "6. Checking Application Logs..."
echo "----------------------------------------"
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
  echo "   Recent logs (last 10 lines):"
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $LOG_STREAM \
    --limit 10 \
    --region $AWS_REGION \
    --query 'events[*].message' \
    --output text 2>/dev/null | tail -10 | sed 's/^/   /'
else
  echo "   ⚠️  No logs found. Enable CloudWatch logging: ./enable-cloudwatch-logs.sh"
fi

# 7. Check task definition port mapping
echo ""
echo "7. Checking Port Mapping in Task Definition..."
echo "----------------------------------------"
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null)

if [ ! -z "$TASK_DEF_ARN" ] && [ "$TASK_DEF_ARN" != "None" ]; then
  PORT_MAPPINGS=$(aws ecs describe-task-definition \
    --task-definition $TASK_DEF_ARN \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].portMappings[*]' \
    --output table 2>/dev/null)
  
  if [ ! -z "$PORT_MAPPINGS" ]; then
    echo "$PORT_MAPPINGS"
    
    HAS_PORT=$(aws ecs describe-task-definition \
      --task-definition $TASK_DEF_ARN \
      --region $AWS_REGION \
      --query "taskDefinition.containerDefinitions[0].portMappings[?containerPort==\`$PORT\`]" \
      --output text 2>/dev/null)
    
    if [ ! -z "$HAS_PORT" ]; then
      echo "   ✅ Port $PORT is mapped"
    else
      echo "   ❌ Port $PORT is NOT mapped in task definition"
    fi
  else
    echo "   ❌ No port mappings found in task definition"
  fi
fi

echo ""
echo "=========================================="
echo "Summary & Next Steps"
echo "=========================================="
echo ""
echo "Common Issues:"
echo "1. Security group not allowing port $PORT"
echo "2. Task not running (check stopped reason)"
echo "3. Application not binding to 0.0.0.0"
echo "4. Wrong IP address"
echo "5. Application crashed on startup"
echo ""
echo "Quick Fixes:"
echo "- Add security group rule: ./fix-security-group.sh"
echo "- Check task logs: ./view-logs.sh"
echo "- Verify task is running: Check ECS console"
echo ""
echo "ECS Console:"
echo "  https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/tasks"

