#!/bin/bash
# Add security group rule for port 8501

export AWS_REGION=eu-north-1
export CLUSTER_NAME=flawless-ostrich-q69e6k
export SERVICE_NAME=llmops-task-service-c2r05qot
export PORT=8501

echo "=========================================="
echo "Adding Security Group Rule for Port $PORT"
echo "=========================================="
echo ""

# Get running task
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text 2>/dev/null)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "❌ No running tasks found"
  echo "   Start a task first, then run this script"
  exit 1
fi

# Get security group
ENI_ID=$(aws ecs describe-tasks \
  --cluster $CLUSTER_NAME \
  --tasks $TASK_ARN \
  --region $AWS_REGION \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text 2>/dev/null)

if [ -z "$ENI_ID" ] || [ "$ENI_ID" = "None" ]; then
  echo "❌ Could not get network interface"
  exit 1
fi

SG_ID=$(aws ec2 describe-network-interfaces \
  --network-interface-ids $ENI_ID \
  --region $AWS_REGION \
  --query 'NetworkInterfaces[0].Groups[0].GroupId' \
  --output text 2>/dev/null)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  echo "❌ Could not get security group"
  exit 1
fi

echo "Security Group: $SG_ID"
echo ""

# Check if rule already exists
EXISTING_RULE=$(aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $AWS_REGION \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`$PORT\` || ToPort==\`$PORT\` || (FromPort<=$PORT && ToPort>=$PORT)]" \
  --output text 2>/dev/null)

if [ ! -z "$EXISTING_RULE" ]; then
  echo "✅ Port $PORT rule already exists"
  echo ""
  echo "Current rules for port $PORT:"
  aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --region $AWS_REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`$PORT\` || ToPort==\`$PORT\` || (FromPort<=$PORT && ToPort>=$PORT)]" \
    --output table
else
  echo "Adding inbound rule for port $PORT..."
  
  # Add rule
  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port $PORT \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION 2>&1
  
  if [ $? -eq 0 ]; then
    echo "✅ Security group rule added successfully"
    echo ""
    echo "Rule added:"
    echo "  Type: Custom TCP"
    echo "  Port: $PORT"
    echo "  Source: 0.0.0.0/0 (all IPs)"
    echo ""
    echo "⚠️  Note: For production, restrict source to specific IPs"
  else
    echo "❌ Failed to add security group rule"
    echo "   You may need to add it manually via AWS Console:"
    echo "   https://eu-north-1.console.aws.amazon.com/ec2/v2/security-groups?region=eu-north-1"
    exit 1
  fi
fi

echo ""
echo "Test connectivity:"
echo "  curl http://13.60.97.107:$PORT/chat"
echo ""
echo "Or check if port is open:"
echo "  nc -zv 13.60.97.107 $PORT"

