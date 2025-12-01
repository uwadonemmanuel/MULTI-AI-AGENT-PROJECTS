# AWS Access Key Best Practices for Jenkins

## Your Use Case: Application Running Outside AWS

Since Jenkins is running in Docker (outside AWS infrastructure), you need to use access keys. However, you can implement best practices to improve security.

## Recommended Setup

### Option 1: IAM User with Least Privilege (Current Approach - Improved)

#### Step 1: Create IAM User with Minimal Permissions

Instead of `AmazonEC2ContainerRegistryFullAccess`, create a custom policy with only what you need:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:DescribeRepositories"
            ],
            "Resource": "arn:aws:ecr:*:*:repository/your-repo-name/*"
        }
    ]
}
```

#### Step 2: Enable MFA for IAM User (Optional but Recommended)

1. Go to IAM → Users → Select your user
2. Security credentials → Assign MFA device
3. This adds an extra layer of security

#### Step 3: Set Up Credential Rotation Policy

1. Create a reminder to rotate keys every 90 days
2. Use AWS Secrets Manager for automatic rotation (if using AWS services)

### Option 2: Use AWS STS AssumeRole (More Secure)

If you have an AWS account, you can use temporary credentials:

#### Step 1: Create IAM Role

1. Go to IAM → Roles → Create Role
2. Trust entity: "AWS account" or "Another AWS account"
3. Attach the ECR policy
4. Note the Role ARN

#### Step 2: Update Jenkinsfile to Use AssumeRole

```groovy
stage('Build and Push Docker Image to ECR') {
    steps {
        script {
            // Assume role and get temporary credentials
            sh '''
                aws sts assume-role \
                    --role-arn arn:aws:iam::ACCOUNT_ID:role/JenkinsECRRole \
                    --role-session-name jenkins-session \
                    --duration-seconds 3600 > /tmp/assume-role-output.json
                
                export AWS_ACCESS_KEY_ID=$(cat /tmp/assume-role-output.json | jq -r '.Credentials.AccessKeyId')
                export AWS_SECRET_ACCESS_KEY=$(cat /tmp/assume-role-output.json | jq -r '.Credentials.SecretAccessKey')
                export AWS_SESSION_TOKEN=$(cat /tmp/assume-role-output.json | jq -r '.Credentials.SessionToken')
            '''
            
            // Use temporary credentials
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-token']]) {
                // Your ECR push commands here
            }
        }
    }
}
```

### Option 3: Use AWS Secrets Manager (Most Secure for Production)

1. Store credentials in AWS Secrets Manager
2. Jenkins retrieves credentials at runtime
3. Automatic rotation support

## Security Best Practices Checklist

- [x] Use least privilege IAM policies (not full access)
- [ ] Store credentials in Jenkins Credentials Manager (encrypted)
- [ ] Never commit credentials to Git
- [ ] Rotate access keys every 90 days
- [ ] Use different credentials for dev/staging/prod
- [ ] Enable CloudTrail to monitor access
- [ ] Set up alerts for unusual access patterns
- [ ] Use MFA for IAM user (if possible)
- [ ] Consider using temporary credentials (STS AssumeRole)
- [ ] Review and audit IAM permissions regularly

## Current Setup Improvements

### 1. Update IAM Policy to Least Privilege

Instead of `AmazonEC2ContainerRegistryFullAccess`, use a custom policy that only allows:
- ECR push/pull operations
- Only for your specific repository

### 2. Add Credential Rotation Reminder

Set up a calendar reminder to rotate keys every 90 days.

### 3. Enable CloudTrail Logging

Monitor all AWS API calls:
1. Go to CloudTrail → Create trail
2. Enable logging for all regions
3. Set up S3 bucket for logs

### 4. Use Environment-Specific Credentials

- `aws-credentials-dev` for development
- `aws-credentials-prod` for production
- Different IAM users for each environment

## Quick Security Audit Script

```bash
#!/bin/bash
# Check AWS credentials security

echo "Checking AWS credential security..."

# Check if credentials are in environment
if [ ! -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "⚠️  WARNING: AWS credentials in environment variables"
fi

# Check if credentials are in files
if grep -r "AKIA" . --exclude-dir=.git 2>/dev/null; then
    echo "⚠️  WARNING: Potential AWS access keys found in files"
fi

# Check credential age (if using AWS CLI)
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI installed"
    # Check IAM user access key age
    aws iam list-access-keys --user-name YOUR_USER_NAME
fi

echo "Security check complete"
```

## Migration Path

1. **Immediate**: Update IAM policy to least privilege
2. **Short-term**: Set up credential rotation schedule
3. **Medium-term**: Implement STS AssumeRole if possible
4. **Long-term**: Move to AWS Secrets Manager or IAM roles (if moving Jenkins to AWS)

## References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)
- [Jenkins AWS Credentials Plugin](https://plugins.jenkins.io/aws-credentials/)




