pipeline{
    agent any

    environment {
        SONAR_PROJECT_KEY = 'LLMOPS'
        AWS_REGION = 'us-east-1'
        ECR_REPO = 'multi-ai-agent'
        IMAGE_TAG = 'latest'
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
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                script {
                    def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                    def ecrUrl = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"

                    sh """
                    # Login to ECR
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ecrUrl}
                    
                    # Create ECR repository if it doesn't exist
                    aws ecr describe-repositories --repository-names ${env.ECR_REPO} --region ${AWS_REGION} || \
                    aws ecr create-repository --repository-name ${env.ECR_REPO} --region ${AWS_REGION}
                    
                    # Build Docker image
                    docker build -t ${env.ECR_REPO}:${IMAGE_TAG} .
                    
                    # Tag image for ECR
                    docker tag ${env.ECR_REPO}:${IMAGE_TAG} ${ecrUrl}:${IMAGE_TAG}
                    
                    # Push image to ECR
                    docker push ${ecrUrl}:${IMAGE_TAG}
                    
                    echo "Successfully pushed ${ecrUrl}:${IMAGE_TAG}"
                    """
                }
            }
        }
    }

    //     stage('Deploy to ECS Fargate') {
    // steps {
    //     withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-token']]) {
    //         script {
    //             sh """
    //             aws ecs update-service \
    //               --cluster multi-ai-agent-cluster \
    //               --service multi-ai-agent-def-service-shqlo39p  \
    //               --force-new-deployment \
    //               --region ${AWS_REGION}
    //             """
    //             }
    //         }
    //     }
    //  }
        
    }
}