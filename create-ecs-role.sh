#!/bin/bash
# Script to create ECS service-linked role

echo "Creating ECS service-linked role..."

# Create the ECS service-linked role
aws iam create-service-linked-role \
  --aws-service-name ecs.amazonaws.com \
  2>&1 | tee ecs-role-creation.log

if [ $? -eq 0 ]; then
    echo "✅ ECS service-linked role created successfully!"
elif grep -q "already exists" ecs-role-creation.log; then
    echo "ℹ️  ECS service-linked role already exists"
else
    echo "❌ Error creating role. Check ecs-role-creation.log for details"
    exit 1
fi

# Verify the role exists
echo ""
echo "Verifying role exists..."
aws iam get-role --role-name AWSServiceRoleForECS 2>&1 | grep -q "AWSServiceRoleForECS" && \
    echo "✅ Role verified: AWSServiceRoleForECS" || \
    echo "⚠️  Could not verify role"

