#!/bin/bash
# ECS Diagnostic Script for troubleshooting deployment issues

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export PUBLIC_IP=13.60.97.107

echo "=========================================="
echo "ECS Diagnostic Report"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Public IP: $PUBLIC_IP"
echo "Region: $AWS_REGION"
echo ""

# 1. Check service status
echo "1. Service Status:"
echo "----------------------------------------"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,PendingCount:pendingCount}' \
  --output table 2>/dev/null || echo "  ❌ Error checking service status"

# 2. Check task status
echo ""
echo "2. Task Status:"
echo "----------------------------------------"
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text 2>/dev/null)

if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
  echo "  Task ARN: $TASK_ARN"
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].{Status:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason,StoppedAt:stoppedAt}' \
    --output table 2>/dev/null || echo "  ❌ Error getting task details"
  
  # Get container status
  echo ""
  echo "  Container Status:"
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].containers[0].{Name:name,Status:lastStatus,Reason:reason,ExitCode:exitCode}' \
    --output table 2>/dev/null || echo "  ❌ Error getting container details"
else
  echo "  ⚠️  No tasks found!"
fi

# 3. Check port accessibility
echo ""
echo "3. Port Accessibility (8501):"
echo "----------------------------------------"
if command -v nc &> /dev/null; then
  if nc -zv -w 5 $PUBLIC_IP 8501 2>&1 | grep -q "succeeded"; then
    echo "  ✅ Port 8501 is accessible"
  else
    echo "  ❌ Port 8501 is NOT accessible"
    echo "     Check security group rules"
  fi
else
  echo "  ⚠️  'nc' (netcat) not installed. Install to test port."
  echo "     Test manually: curl http://$PUBLIC_IP:8501"
fi

# 4. Check HTTP response
echo ""
echo "4. HTTP Response:"
echo "----------------------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP:8501 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ HTTP 200 - Service is responding"
elif [ "$HTTP_CODE" = "000" ]; then
  echo "  ❌ Connection failed - Check security group and network"
else
  echo "  ⚠️  HTTP $HTTP_CODE - Service responding but may have errors"
fi

# 5. Check security group (if we can get it)
echo ""
echo "5. Security Group:"
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
      echo "  Security Group ID: $SG_ID"
      echo "  Check rules: https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups?region=eu-north-1"
      
      # Check if port 8501 is allowed
      PORT_8501_ALLOWED=$(aws ec2 describe-security-groups \
        --group-ids $SG_ID \
        --region $AWS_REGION \
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`8501` || ToPort==`8501`]' \
        --output text 2>/dev/null)
      
      if [ ! -z "$PORT_8501_ALLOWED" ]; then
        echo "  ✅ Port 8501 rule found in security group"
      else
        echo "  ❌ Port 8501 rule NOT found in security group"
        echo "     Add inbound rule: TCP 8501 from 0.0.0.0/0"
      fi
    else
      echo "  ⚠️  Could not determine security group"
    fi
  else
    echo "  ⚠️  Could not determine network interface"
  fi
else
  echo "  ⚠️  No task found to check security group"
fi

# 6. Check logs
echo ""
echo "6. Recent Logs (last 10 lines):"
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
  echo "  Log Stream: $LOG_STREAM"
  echo ""
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $LOG_STREAM \
    --limit 10 \
    --region $AWS_REGION \
    --query 'events[*].message' \
    --output text 2>/dev/null | tail -10 || echo "  ❌ Error retrieving logs"
else
  echo "  ⚠️  No logs found. Check CloudWatch Logs configuration."
  echo "     Log Group: $LOG_GROUP"
fi

# 7. Check task definition
echo ""
echo "7. Task Definition:"
echo "----------------------------------------"
TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].taskDefinition' \
  --output text 2>/dev/null)

if [ ! -z "$TASK_DEF_ARN" ] && [ "$TASK_DEF_ARN" != "None" ]; then
  echo "  Task Definition: $TASK_DEF_ARN"
  
  # Check environment variables
  ENV_VARS=$(aws ecs describe-task-definition \
    --task-definition $TASK_DEF_ARN \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].environment[*].name' \
    --output text 2>/dev/null)
  
  if echo "$ENV_VARS" | grep -q "GROQ_API_KEY"; then
    echo "  ✅ GROQ_API_KEY is set"
  else
    echo "  ❌ GROQ_API_KEY is NOT set"
  fi
  
  if echo "$ENV_VARS" | grep -q "TAVILY_API_KEY"; then
    echo "  ✅ TAVILY_API_KEY is set"
  else
    echo "  ❌ TAVILY_API_KEY is NOT set"
  fi
  
  # Check port mappings
  PORTS=$(aws ecs describe-task-definition \
    --task-definition $TASK_DEF_ARN \
    --region $AWS_REGION \
    --query 'taskDefinition.containerDefinitions[0].portMappings[*].containerPort' \
    --output text 2>/dev/null)
  
  if echo "$PORTS" | grep -q "8501"; then
    echo "  ✅ Port 8501 is mapped"
  else
    echo "  ❌ Port 8501 is NOT mapped"
  fi
else
  echo "  ❌ Could not get task definition"
fi

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Check CloudWatch Logs for detailed errors"
echo "2. Verify security group allows port 8501"
echo "3. Ensure environment variables are set"
echo "4. Check application logs for startup errors"
echo ""
echo "CloudWatch Logs:"
echo "  https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group/$LOG_GROUP"
echo ""
echo "ECS Service:"
echo "  https://eu-north-1.console.aws.amazon.com/ecs/v2/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"

