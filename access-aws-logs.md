# Access Error Logs from AWS

## Multiple Ways to Access Logs

### 1. CloudWatch Logs (Primary Method)

#### Via AWS Console:
1. Go to: [CloudWatch Logs](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups)
2. Find log group: `/ecs/multi-ai-agent`
3. Click on it
4. Select a log stream (most recent one)
5. View logs in real-time

**Direct link:**
```
https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group$252Fecs$252Fmulti-ai-agent
```

#### Via AWS CLI:
```bash
# List log groups
aws logs describe-log-groups \
  --region eu-north-1 \
  --log-group-name-prefix "/ecs"

# List log streams
aws logs describe-log-streams \
  --log-group-name /ecs/multi-ai-agent \
  --region eu-north-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 10

# View recent logs
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1

# Get last 100 log events
aws logs get-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --log-stream-name <STREAM_NAME> \
  --limit 100 \
  --region eu-north-1 \
  --query 'events[*].message' \
  --output text
```

### 2. ECS Task Logs (If Logging to File)

If your application writes logs to files in the container:

#### Access via ECS Exec (SSH into container):
```bash
# Get running task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster flawless-ostrich-q69e6k \
  --service-name llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'taskArns[0]' \
  --output text)

# Enable ECS Exec (if not already enabled)
# Then connect to container
aws ecs execute-command \
  --cluster flawless-ostrich-q69e6k \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "/bin/sh" \
  --interactive \
  --region eu-north-1

# Once inside container, check for log files:
# ls -la /app/logs/
# cat /app/logs/error.log
# tail -f /app/logs/application.log
```

### 3. S3 Logs (If Configured)

If logs are written to S3:

```bash
# List S3 buckets
aws s3 ls

# Check for logs bucket
aws s3 ls s3://your-logs-bucket/logs/ --recursive

# Download logs
aws s3 cp s3://your-logs-bucket/logs/error.log ./error.log
```

### 4. Application Log Files in Container

If your app writes to `/app/logs/` or similar:

#### Check Dockerfile for log location:
```bash
# View Dockerfile to see where logs are written
cat Dockerfile | grep -i log
```

#### Common log locations:
- `/app/logs/`
- `/var/log/`
- `/tmp/`
- `./logs/` (relative to app directory)

### 5. ECS Service Events

Check service-level events:

```bash
# Get service events (deployment issues, etc.)
aws ecs describe-services \
  --cluster flawless-ostrich-q69e6k \
  --services llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'services[0].events[*]' \
  --output table
```

### 6. ECS Task Stopped Reason

If tasks are stopping:

```bash
# Get stopped tasks
aws ecs list-tasks \
  --cluster flawless-ostrich-q69e6k \
  --desired-status STOPPED \
  --region eu-north-1

# Get stopped reason
TASK_ARN=$(aws ecs list-tasks \
  --cluster flawless-ostrich-q69e6k \
  --desired-status STOPPED \
  --region eu-north-1 \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster flawless-ostrich-q69e6k \
  --tasks $TASK_ARN \
  --region eu-north-1 \
  --query 'tasks[0].{StoppedReason:stoppedReason,StoppedAt:stoppedAt}' \
  --output table
```

## Quick Access Script

Save this as `view-logs.sh`:

```bash
#!/bin/bash
export AWS_REGION=eu-north-1
export LOG_GROUP="/ecs/multi-ai-agent"

echo "=========================================="
echo "Accessing AWS Logs"
echo "=========================================="
echo ""

# Method 1: CloudWatch Logs
echo "1. CloudWatch Logs:"
echo "   Console: https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group$252Fecs$252Fmulti-ai-agent"
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

if [ ! -z "$LOG_STREAM" ] && [ "$LOG_STREAM" != "None" ]; then
  echo "   Latest log stream: $LOG_STREAM"
  echo ""
  echo "   Recent logs (last 50 lines):"
  echo "   ----------------------------------------"
  aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $LOG_STREAM \
    --limit 50 \
    --region $AWS_REGION \
    --query 'events[*].message' \
    --output text 2>/dev/null | tail -50
else
  echo "   ⚠️  No log streams found. Enable CloudWatch logging first."
fi

echo ""
echo "2. To follow logs in real-time:"
echo "   aws logs tail $LOG_GROUP --follow --region $AWS_REGION"
echo ""
echo "3. To search for errors:"
echo "   aws logs filter-log-events --log-group-name $LOG_GROUP --filter-pattern 'ERROR' --region $AWS_REGION"
```

## Search Logs for Specific Errors

### Search for 500 errors:
```bash
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "500" \
  --region eu-north-1 \
  --max-items 20
```

### Search for exceptions:
```bash
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "Exception Traceback Error" \
  --region eu-north-1 \
  --max-items 20
```

### Search for specific text:
```bash
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "GROQ_API_KEY" \
  --region eu-north-1 \
  --max-items 20
```

## Export Logs to File

```bash
# Export last 1000 log events to file
aws logs get-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --log-stream-name <STREAM_NAME> \
  --limit 1000 \
  --region eu-north-1 \
  --query 'events[*].[timestamp,message]' \
  --output text > logs-export.txt

# Or export all logs from a time range
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --region eu-north-1 \
  --query 'events[*].message' \
  --output text > recent-logs.txt
```

## Most Common: CloudWatch Logs

For ECS tasks, **CloudWatch Logs is the standard method**. 

**Quick access:**
```bash
# Follow logs in real-time
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1

# Or use the check script
./check-chat-error.sh
```


