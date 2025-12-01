#!/bin/bash
# Quick script to view AWS logs from various sources

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export LOG_GROUP="/ecs/multi-ai-agent"

echo "=========================================="
echo "Accessing AWS Logs"
echo "=========================================="
echo ""

# Method 1: CloudWatch Logs
echo "1. CloudWatch Logs (Primary Method):"
echo "----------------------------------------"
echo "   Console URL:"
echo "   https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group$252Fecs$252Fmulti-ai-agent"
echo ""

# Check if log group exists
LOG_GROUP_EXISTS=$(aws logs describe-log-groups \
  --log-group-name-prefix $LOG_GROUP \
  --region $AWS_REGION \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].logGroupName" \
  --output text 2>/dev/null)

if [ ! -z "$LOG_GROUP_EXISTS" ]; then
  # Get latest log stream
  LOG_STREAM=$(aws logs describe-log-streams \
    --log-group-name $LOG_GROUP \
    --order-by LastEventTime \
    --descending \
    --max-items 1 \
    --region $AWS_REGION \
    --query 'logStreams[0].logStreamName' \
    --output text 2>/dev/null)

  if [ ! -z "$LOG_STREAM" ] && [ "$LOG_STREAM" != "None" ]; then
    echo "   ✅ Log group found: $LOG_GROUP"
    echo "   Latest log stream: $LOG_STREAM"
    echo ""
    echo "   Recent logs (last 30 lines):"
    echo "   ----------------------------------------"
    aws logs get-log-events \
      --log-group-name $LOG_GROUP \
      --log-stream-name $LOG_STREAM \
      --limit 30 \
      --region $AWS_REGION \
      --query 'events[*].message' \
      --output text 2>/dev/null | tail -30 | sed 's/^/   /'
    
    echo ""
    echo "   To follow logs in real-time:"
    echo "   aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
  else
    echo "   ⚠️  Log group exists but no log streams found"
    echo "   Wait for new tasks to start, or check if logging is configured"
  fi
else
  echo "   ❌ Log group not found: $LOG_GROUP"
  echo "   Enable CloudWatch logging: ./enable-cloudwatch-logs.sh"
fi

echo ""
echo "2. Search for Errors:"
echo "----------------------------------------"
if [ ! -z "$LOG_GROUP_EXISTS" ]; then
  echo "   Searching for 'ERROR' in logs..."
  ERROR_COUNT=$(aws logs filter-log-events \
    --log-group-name $LOG_GROUP \
    --filter-pattern "ERROR" \
    --region $AWS_REGION \
    --max-items 5 \
    --query 'events | length(@)' \
    --output text 2>/dev/null || echo "0")
  
  if [ "$ERROR_COUNT" != "0" ] && [ ! -z "$ERROR_COUNT" ]; then
    echo "   Found $ERROR_COUNT error(s). Recent errors:"
    aws logs filter-log-events \
      --log-group-name $LOG_GROUP \
      --filter-pattern "ERROR" \
      --region $AWS_REGION \
      --max-items 5 \
      --query 'events[*].message' \
      --output text 2>/dev/null | head -5 | sed 's/^/   /'
  else
    echo "   No errors found in recent logs"
  fi
else
  echo "   Enable logging first to search for errors"
fi

echo ""
echo "3. ECS Service Events:"
echo "----------------------------------------"
SERVICE_EVENTS=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'services[0].events[:5]' \
  --output table 2>/dev/null)

if [ ! -z "$SERVICE_EVENTS" ]; then
  echo "$SERVICE_EVENTS"
else
  echo "   Could not retrieve service events"
fi

echo ""
echo "4. Quick Commands:"
echo "----------------------------------------"
echo "   Follow logs:     aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "   Search errors:   aws logs filter-log-events --log-group-name $LOG_GROUP --filter-pattern 'ERROR' --region $AWS_REGION"
echo "   Search 500:      aws logs filter-log-events --log-group-name $LOG_GROUP --filter-pattern '500' --region $AWS_REGION"
echo "   Export logs:     aws logs get-log-events --log-group-name $LOG_GROUP --log-stream-name <STREAM> --limit 1000 --region $AWS_REGION --query 'events[*].message' --output text > logs.txt"
echo ""
echo "=========================================="
echo "CloudWatch Logs Console:"
echo "https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups"
echo "=========================================="


