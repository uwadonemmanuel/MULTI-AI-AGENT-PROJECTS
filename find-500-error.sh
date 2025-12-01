#!/bin/bash
# Find the full error traceback for 500 errors

export AWS_REGION=eu-north-1
export LOG_GROUP="/ecs/multi-ai-agent"

echo "=========================================="
echo "Finding 500 Error Details"
echo "=========================================="
echo ""

# Get latest log stream
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
  echo "   Enable CloudWatch logging first: ./enable-cloudwatch-logs.sh"
  exit 1
fi

echo "Log Stream: $LOG_STREAM"
echo ""

# Search for 500 errors and surrounding context
echo "1. Searching for 500 errors with context..."
echo "----------------------------------------"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "500" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null

echo ""
echo "2. Searching for Traceback/Exception..."
echo "----------------------------------------"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-names $LOG_STREAM \
  --filter-pattern "Traceback Exception Error" \
  --region $AWS_REGION \
  --max-items 10 \
  --query 'events[*].message' \
  --output text 2>/dev/null | head -50

echo ""
echo "3. Recent logs around 500 errors (last 100 lines)..."
echo "----------------------------------------"
# Get recent logs and show context around 500 errors
aws logs get-log-events \
  --log-group-name $LOG_GROUP \
  --log-stream-name $LOG_STREAM \
  --limit 100 \
  --region $AWS_REGION \
  --query 'events[*].message' \
  --output text 2>/dev/null | grep -A 10 -B 10 "500\|Traceback\|Exception\|Error" | tail -50

echo ""
echo "4. Full recent logs (last 50 lines)..."
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
echo "To see live logs:"
echo "aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo "=========================================="

