#!/bin/bash

# SonarQube Setup Script
# This script sets up SonarQube with proper configuration

echo "Setting up SonarQube..."

# 1. Configure system settings (required for SonarQube)
echo "Configuring system settings..."
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072
ulimit -n 131072
ulimit -u 8192

# 2. Stop and remove existing SonarQube container if it exists
echo "Cleaning up existing SonarQube container..."
docker stop sonarqube-dind 2>/dev/null || true
docker rm sonarqube-dind 2>/dev/null || true

# 3. Run SonarQube container with proper configuration
echo "Starting SonarQube container..."
docker run -d --name sonarqube-dind \
  --restart=unless-stopped \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:lts

# 4. Wait for SonarQube to start
echo "Waiting for SonarQube to start (this may take 1-2 minutes)..."
sleep 10

# 5. Check container status
echo "Checking container status..."
docker ps | grep sonarqube-dind

echo ""
echo "SonarQube setup complete!"
echo "Access SonarQube at: http://localhost:9000"
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "To view logs: docker logs -f sonarqube-dind"
echo "To stop: docker stop sonarqube-dind"
echo "To start: docker start sonarqube-dind"


