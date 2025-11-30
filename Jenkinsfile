pipeline{
    agent any

    environment {
        SONAR_PROJECT_KEY = 'LLMOPS'
        AWS_REGION = 'us-east-1'
        ECR_REPO = 'my-repo'
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
							if [ ! -f sonar-scanner-cli-5.0.1.3006-linux.zip ]; then
								wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
								unzip sonar-scanner-cli-5.0.1.3006-linux.zip
							fi
						'''
						env.SONAR_SCANNER_HOME = "${WORKSPACE}/sonar-scanner/sonar-scanner-5.0.1.3006-linux"
					}
				}
				withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
					withSonarQubeEnv('SonarQube') {
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

    // stage('Build and Push Docker Image to ECR') {
    //         steps {
    //             withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-token']]) {
    //                 script {
    //                     def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
    //                     def ecrUrl = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"

    //                     sh """
    //                     aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ecrUrl}
    //                     docker build -t ${env.ECR_REPO}:${IMAGE_TAG} .
    //                     docker tag ${env.ECR_REPO}:${IMAGE_TAG} ${ecrUrl}:${IMAGE_TAG}
    //                     docker push ${ecrUrl}:${IMAGE_TAG}
    //                     """
    //                 }
    //             }
    //         }
    //     }

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