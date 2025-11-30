pipeline{
    agent any

    environment {
        SONAR_PROJECT_KEY = 'LLMOPS'
        SONAR_SCANNER_HOME = tool "sonarqube-scanner"
        AWS_REGION = 'eu-north-1'
        ECR_REPO = 'multi-ai-agent'
        IMAGE_TAG = 'latest'
        ECS_CLUSTER = 'flawless-ostrich-q69e6k'
        ECS_SERVICE = 'llmops-task-service-c2r05qot'
    }

    stages{
        stage('Cloning Github repo to Jenkins'){
            steps{
                script{
                    echo 'Cloning Github repo to Jenkins............'
                    checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[credentialsId: 'github-token', url: 'https://github.com/uwadonemmanuel/MULTI-AI-AGENT-PROJECTS.git']])
                }
            }
        }

    stage('SonarQube Analysis'){
			steps {
				script {
					// Try to use configured tool, or download sonar-scanner
					try {
						env.SONAR_SCANNER_HOME = tool name: 'SonarQube Scanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
					} catch (Exception e) {
						echo "SonarQube Scanner tool not configured, downloading..."
						sh '''
							mkdir -p sonar-scanner
							cd sonar-scanner
							if [ ! -d sonar-scanner-5.0.1.3006-linux ]; then
								# Download SonarQube Scanner
								curl -L -o sonar-scanner-cli-5.0.1.3006-linux.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
								# Extract
								unzip -q sonar-scanner-cli-5.0.1.3006-linux.zip
								chmod +x sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner
							fi
						'''
						env.SONAR_SCANNER_HOME = "${WORKSPACE}/sonar-scanner/sonar-scanner-5.0.1.3006-linux"
					}
				}
				withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
					// Try withSonarQubeEnv first, fallback to direct execution if name doesn't match
					script {
						try {
							withSonarQubeEnv('SonarQube') {
								sh """
								${env.SONAR_SCANNER_HOME}/bin/sonar-scanner \
								-Dsonar.projectKey=${SONAR_PROJECT_KEY} \
								-Dsonar.sources=. \
								-Dsonar.host.url=http://sonarqube-dind:9000 \
								-Dsonar.login=${SONAR_TOKEN}
								"""
							}
						} catch (Exception e) {
							echo "SonarQube server name mismatch, using direct connection..."
							sh """
							${env.SONAR_SCANNER_HOME}/bin/sonar-scanner \
							-Dsonar.projectKey=${SONAR_PROJECT_KEY} \
							-Dsonar.sources=. \
							-Dsonar.host.url=http://sonarqube-dind:9000 \
							-Dsonar.login=${SONAR_TOKEN}
							"""
						}
					}
				}
			}
		}

    stage('Build and Push Docker Image to ECR') {
        steps {
            withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                script {
                    sh """
                    # Set Docker API version for compatibility (downgrade from 1.52 to 1.43)
                    export DOCKER_API_VERSION=1.43
                    
                    # Set AWS credentials
                    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                    export AWS_DEFAULT_REGION=${AWS_REGION}
                    
                    # Get AWS account ID
                    ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                    ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    
                    # Login to ECR (DOCKER_API_VERSION is set above)
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin \${ECR_URL}
                    
                    # Create ECR repository if it doesn't exist
                    aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${AWS_REGION} || \
                    aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}
                    
                    # Build Docker image (DOCKER_API_VERSION is set above)
                    docker build -t ${ECR_REPO}:${IMAGE_TAG} .
                    
                    # Tag image for ECR
                    docker tag ${ECR_REPO}:${IMAGE_TAG} \${ECR_URL}:${IMAGE_TAG}
                    
                    # Push image to ECR
                    docker push \${ECR_URL}:${IMAGE_TAG}
                    
                    echo "Successfully pushed \${ECR_URL}:${IMAGE_TAG}"
                    """
                }
            }
        }
    }

    stage('Deploy to ECS Fargate') {
        steps {
            withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                script {
                    sh """
                    # Set AWS credentials
                    export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                    export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                    export AWS_DEFAULT_REGION=${AWS_REGION}
                    
                    # Get AWS account ID
                    ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                    ECR_URL="\${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
                    
                    echo "=========================================="
                    echo "ECS Deployment Configuration"
                    echo "=========================================="
                    echo "Cluster: ${ECS_CLUSTER}"
                    echo "Service: ${ECS_SERVICE}"
                    echo "Region: ${AWS_REGION}"
                    echo "Image: \${ECR_URL}:${IMAGE_TAG}"
                    echo ""
                    
                    # Verify cluster exists
                    echo "Verifying ECS cluster exists..."
                    CLUSTER_EXISTS=\$(aws ecs describe-clusters --clusters ${ECS_CLUSTER} --region ${AWS_REGION} --query 'clusters[0].clusterName' --output text 2>/dev/null)
                    
                    if [ "\$CLUSTER_EXISTS" != "${ECS_CLUSTER}" ]; then
                        echo "❌ ERROR: Cluster '${ECS_CLUSTER}' not found in region ${AWS_REGION}"
                        echo ""
                        echo "Available clusters:"
                        aws ecs list-clusters --region ${AWS_REGION} --query 'clusterArns[*]' --output text | awk -F'/' '{print "  - " \$NF}' || echo "  (Unable to list clusters)"
                        echo ""
                        echo "Please update ECS_CLUSTER in Jenkinsfile with the correct cluster name."
                        exit 1
                    fi
                    echo "✅ Cluster '${ECS_CLUSTER}' verified"
                    
                    # Verify service exists
                    echo "Verifying ECS service exists..."
                    SERVICE_EXISTS=\$(aws ecs describe-services --cluster ${ECS_CLUSTER} --services ${ECS_SERVICE} --region ${AWS_REGION} --query 'services[0].serviceName' --output text 2>/dev/null)
                    
                    if [ "\$SERVICE_EXISTS" != "${ECS_SERVICE}" ]; then
                        echo "❌ ERROR: Service '${ECS_SERVICE}' not found in cluster '${ECS_CLUSTER}'"
                        echo ""
                        echo "Available services in cluster '${ECS_CLUSTER}':"
                        aws ecs list-services --cluster ${ECS_CLUSTER} --region ${AWS_REGION} --query 'serviceArns[*]' --output text | awk -F'/' '{print "  - " \$NF}' || echo "  (No services found or unable to list)"
                        echo ""
                        echo "Please update ECS_SERVICE in Jenkinsfile with the correct service name."
                        exit 1
                    fi
                    echo "✅ Service '${ECS_SERVICE}' verified"
                    echo ""
                    
                    # Update ECS service to force new deployment with latest image
                    echo "Initiating ECS service update..."
                    aws ecs update-service \
                      --cluster ${ECS_CLUSTER} \
                      --service ${ECS_SERVICE} \
                      --force-new-deployment \
                      --region ${AWS_REGION}
                    
                    if [ \$? -eq 0 ]; then
                        echo "✅ ECS service update initiated successfully"
                        echo ""
                        echo "Waiting for deployment to stabilize (this may take a few minutes)..."
                        
                        # Wait for service to stabilize (optional - can be removed if you want faster pipeline)
                        aws ecs wait services-stable \
                          --cluster ${ECS_CLUSTER} \
                          --services ${ECS_SERVICE} \
                          --region ${AWS_REGION} || \
                        echo "⚠️  Warning: Service deployment may still be in progress. Check ECS console for status."
                        
                        echo ""
                        echo "✅ Deployment completed successfully!"
                    else
                        echo "❌ Failed to update ECS service"
                        exit 1
                    fi
                    """
                }
            }
        }
    }
        
    }
}