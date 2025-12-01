# Access Error Logs from AWS - Complete Guide

## Your Application Logs Location

Your application writes logs to: **`/app/logs/log_YYYY-MM-DD.log`** inside the container.

Based on `app/common/logger.py`:
- Log directory: `logs/` (relative to app root)
- Log files: `log_2025-01-01.log`, `log_2025-01-02.log`, etc.
- Full path in container: `/app/logs/log_YYYY-MM-DD.log`

## Method 1: CloudWatch Logs (Recommended - Easiest)

### Via AWS Console:
1. Go to: [CloudWatch Logs](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups)
2. Find: `/ecs/multi-ai-agent`
3. Click on it → Select log stream → View logs

**Direct Link:**
```
https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups/log-group$252Fecs$252Fmulti-ai-agent
```

### Via Script:
```bash
./view-logs.sh
```

### Via AWS CLI:
```bash
# Follow logs in real-time
aws logs tail /ecs/multi-ai-agent --follow --region eu-north-1

# Get recent logs
aws logs get-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --log-stream-name <STREAM_NAME> \
  --limit 100 \
  --region eu-north-1
```

## Method 2: Access Container Log Files (If ECS Exec Enabled)

### Step 1: Enable ECS Exec

**Via AWS Console:**
1. Go to Task Definition
2. Create new revision
3. Enable "Enable ECS Exec" checkbox
4. Save and update service

**Via AWS CLI:**
```bash
# Update task definition to enable ECS Exec
# (See enable-cloudwatch-logs.sh for example)
```

### Step 2: Access Log Files

**Option A: List log files:**
```bash
./access-container-logs.sh
```

**Option B: View specific log file:**
```bash
export TASK_ARN=$(aws ecs list-tasks \
  --cluster flawless-ostrich-q69e6k \
  --service-name llmops-task-service-c2r05qot \
  --region eu-north-1 \
  --query 'taskArns[0]' \
  --output text)

# View today's log
aws ecs execute-command \
  --cluster flawless-ostrich-q69e6k \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "cat /app/logs/log_$(date +%Y-%m-%d).log" \
  --interactive \
  --region eu-north-1
```

**Option C: Get interactive shell:**
```bash
aws ecs execute-command \
  --cluster flawless-ostrich-q69e6k \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "/bin/sh" \
  --interactive \
  --region eu-north-1

# Then inside container:
cd /app/logs
ls -la
cat log_2025-01-01.log
tail -f log_2025-01-01.log
grep ERROR log_2025-01-01.log
```

**Option D: Copy log file to local:**
```bash
# This requires setting up a way to copy files
# Easiest: Use CloudWatch Logs instead
```

## Method 3: Search Logs for Errors

### Search CloudWatch Logs:
```bash
# Search for errors
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "ERROR" \
  --region eu-north-1

# Search for 500 errors
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "500" \
  --region eu-north-1

# Search for exceptions
aws logs filter-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --filter-pattern "Exception Traceback" \
  --region eu-north-1
```

### Search Container Logs (if ECS Exec enabled):
```bash
aws ecs execute-command \
  --cluster flawless-ostrich-q69e6k \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "grep -i error /app/logs/log_$(date +%Y-%m-%d).log" \
  --interactive \
  --region eu-north-1
```

## Quick Access Commands

### View logs script:
```bash
./view-logs.sh
```

### Check for errors:
```bash
./check-chat-error.sh
```

### Access container logs:
```bash
./access-container-logs.sh
```

## Export Logs to Local File

### From CloudWatch:
```bash
# Export to file
aws logs get-log-events \
  --log-group-name /ecs/multi-ai-agent \
  --log-stream-name <STREAM_NAME> \
  --limit 1000 \
  --region eu-north-1 \
  --query 'events[*].[timestamp,message]' \
  --output text > error-logs.txt
```

### From Container (if ECS Exec enabled):
```bash
# Get log content and save locally
aws ecs execute-command \
  --cluster flawless-ostrich-q69e6k \
  --task $TASK_ARN \
  --container multi-ai-agent \
  --command "cat /app/logs/log_$(date +%Y-%m-%d).log" \
  --interactive \
  --region eu-north-1 > local-log.txt
```

## Troubleshooting

### If CloudWatch logs not found:
```bash
./enable-cloudwatch-logs.sh
```

### If ECS Exec not working:
1. Enable it in Task Definition
2. Ensure IAM permissions are set
3. Use CloudWatch Logs instead (easier)

### If no logs appear:
1. Check if application is writing logs
2. Verify logger configuration
3. Check container is running
4. Check CloudWatch logging is enabled

## Recommended Approach

**For most cases, use CloudWatch Logs:**
- ✅ No ECS Exec needed
- ✅ Easy to search
- ✅ Real-time following
- ✅ Automatic log retention
- ✅ Access from anywhere

**Use container logs only if:**
- You need to access files directly
- You want to modify log files
- You need to debug file system issues

## Quick Reference

| Method | Command | Use Case |
|--------|---------|----------|
| CloudWatch Console | [Link](https://eu-north-1.console.aws.amazon.com/cloudwatch/home?region=eu-north-1#logsV2:log-groups) | View/search logs |
| CloudWatch CLI | `aws logs tail /ecs/multi-ai-agent --follow` | Real-time logs |
| View Script | `./view-logs.sh` | Quick overview |
| Container Files | `./access-container-logs.sh` | Direct file access |
| Error Check | `./check-chat-error.sh` | Find errors |

