# How to Find Your ECS Cluster and Service Names

## Step 1: Find Your ECS Cluster Name

### Option A: AWS Console
1. Go to: **ECS Console** → **Clusters**
2. You'll see a list of all your clusters
3. Copy the **exact cluster name** (case-sensitive)

### Option B: AWS CLI
```bash
aws ecs list-clusters --region eu-north-1
```

This will return something like:
```
{
    "clusterArns": [
        "arn:aws:ecs:eu-north-1:844810703328:cluster/multi-ai-agent-cluster"
    ]
}
```

The cluster name is the part after the last `/`: `multi-ai-agent-cluster`

## Step 2: Find Your ECS Service Name

### Option A: AWS Console
1. Go to: **ECS Console** → **Clusters**
2. Click on your cluster name
3. Go to the **Services** tab
4. You'll see a list of services
5. Copy the **exact service name** (case-sensitive)

### Option B: AWS CLI
```bash
# First, get your cluster name
CLUSTER_NAME="your-cluster-name"

# Then list services in that cluster
aws ecs list-services --cluster $CLUSTER_NAME --region eu-north-1
```

This will return something like:
```json
{
    "serviceArns": [
        "arn:aws:ecs:eu-north-1:844810703328:service/multi-ai-agent-cluster/multi-ai-agent-service"
    ]
}
```

The service name is the part after the last `/`: `multi-ai-agent-service`

## Step 3: Update Jenkinsfile

Once you have the correct names, update your `Jenkinsfile`:

```groovy
environment {
    ECS_CLUSTER = 'your-actual-cluster-name'    // Replace with your cluster name
    ECS_SERVICE = 'your-actual-service-name'    // Replace with your service name
}
```

## Common Names to Check

Based on typical setups, your names might be:

- **Cluster names:**
  - `multi-ai-agent-cluster`
  - `llmops-cluster`
  - `default`
  - `your-cluster-name`

- **Service names:**
  - `multi-ai-agent-service`
  - `llmops-service`
  - `multi-ai-agent-def-service-shqlo39p` (auto-generated)
  - `your-service-name`

## Verify Names Are Correct

After updating, you can verify by running:

```bash
# Check if cluster exists
aws ecs describe-clusters --clusters your-cluster-name --region eu-north-1

# Check if service exists
aws ecs describe-services \
  --cluster your-cluster-name \
  --services your-service-name \
  --region eu-north-1
```

If you get an error saying the cluster or service doesn't exist, the name is incorrect.

## Quick Check from Jenkins Container

You can also check from your Jenkins container:

```bash
docker exec jenkins-dind bash -c "
export AWS_ACCESS_KEY_ID='your-key'
export AWS_SECRET_ACCESS_KEY='your-secret'
export AWS_DEFAULT_REGION=eu-north-1
aws ecs list-clusters
aws ecs list-services --cluster your-cluster-name
"
```


