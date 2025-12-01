#!/bin/bash
# Script to verify ECS cluster and service names

echo "=========================================="
echo "ECS Cluster and Service Name Verification"
echo "=========================================="
echo ""

# Set your AWS region
REGION="eu-north-1"

# Set your AWS credentials (or use AWS CLI default profile)
# export AWS_ACCESS_KEY_ID="your-key"
# export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION=$REGION

echo "Checking ECS clusters in region: $REGION"
echo "----------------------------------------"

# List all clusters
CLUSTERS=$(aws ecs list-clusters --region $REGION --query 'clusterArns[*]' --output text)

if [ -z "$CLUSTERS" ]; then
    echo "❌ No clusters found in region $REGION"
    echo ""
    echo "Please create an ECS cluster first:"
    echo "1. Go to ECS Console → Clusters → Create Cluster"
    echo "2. Choose Fargate launch type"
    echo "3. Give it a name (e.g., 'multi-ai-agent-cluster')"
    exit 1
fi

echo "✅ Found clusters:"
for cluster in $CLUSTERS; do
    CLUSTER_NAME=$(echo $cluster | awk -F'/' '{print $NF}')
    echo "   - $CLUSTER_NAME"
done

echo ""
echo "Checking services in each cluster..."
echo "----------------------------------------"

# Check services in each cluster
for cluster in $CLUSTERS; do
    CLUSTER_NAME=$(echo $cluster | awk -F'/' '{print $NF}')
    echo ""
    echo "Cluster: $CLUSTER_NAME"
    
    SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --region $REGION --query 'serviceArns[*]' --output text 2>/dev/null)
    
    if [ -z "$SERVICES" ]; then
        echo "   ⚠️  No services found in this cluster"
        echo "   → You need to create a service first"
    else
        echo "   ✅ Services found:"
        for service in $SERVICES; do
            SERVICE_NAME=$(echo $service | awk -F'/' '{print $NF}')
            echo "      - $SERVICE_NAME"
        done
    fi
done

echo ""
echo "=========================================="
echo "Recommended Jenkinsfile Configuration:"
echo "=========================================="
echo ""
echo "environment {"
echo "    ECS_CLUSTER = 'YOUR_CLUSTER_NAME'     // Use one of the cluster names above"
echo "    ECS_SERVICE = 'YOUR_SERVICE_NAME'     // Use one of the service names above"
echo "}"
echo ""
echo "Replace the values with the actual names from above!"



