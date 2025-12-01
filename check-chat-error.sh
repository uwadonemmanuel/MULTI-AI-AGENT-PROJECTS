#!/bin/bash
# Check CloudWatch logs for /chat endpoint errors

export AWS_REGION=eu-north-1
export LOG_GROUP="/ecs/multi-ai-agent"

echo "=========================================="
echo "Checking /chat Endpoint Errors"
echo "=========================================="
echo ""

# Get the latest log stream
echo "Getting latest log stream..."
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name $LOG_GROUP \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --region $AWS_REGION \
  --query 'logStreams[0].logStreamName' \
  --output text 2>/dev/null)

if [ -z "$LOG_STREAM" ] || [ "$LOG_STREAM" = "None" ]; then
  echo "❌ No log stream found"
  echo ""
  echo "CloudWatch logging is not enabled for your ECS task."
  echo ""
  echo "To enable logging, run:"
  echo "  ./enable-cloudwatch-logs.sh"
  echo ""
  echo "Or check for existing log groups:"
  echo "  ./find-logs.sh"
  echo ""
  echo "See: enable-cloudwatch-logs.md for detailed instructions"
  exit 1
fi

echo "Log Stream: $LOG_STREAM"
echo ""

# Get recent logs with errors
echo "Recent logs with errors (last 50 lines):"
echo "----------------------------------------"
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name $LOG_STREAM \
  --limit 50 \
  --region $AWS_REGION \
  --query 'events[*].message' \
  --output text 2>/dev/null | tail -50

echo ""
echo "=========================================="
echo "Searching for specific error patterns..."
echo "=========================================="
echo ""

# Search for error patterns
echo "1. Looking for Traceback/Exception errors:"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "Traceback Exception Error" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null | head -30

echo ""
echo "2. Looking for 500 errors:"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "500" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null

echo ""
echo "3. Looking for API key errors:"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "API_KEY GROQ TAVILY" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null

echo ""
echo "4. Looking for model errors:"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "model decommissioned invalid" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null

echo ""
echo "=========================================="
echo "Full recent logs (last 100 lines):"
echo "=========================================="
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name $LOG_STREAM \
  --limit 100 \
  --region $AWS_REGION \
  --query 'events[*].[timestamp,message]' \
  --output text 2>/dev/null | tail -100

echo ""
echo "=========================================="
echo "To see live logs, run:"
echo "aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "=========================================="

