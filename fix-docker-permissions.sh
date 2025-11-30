#!/bin/bash
# Script to fix Docker socket permissions in Jenkins container
# Run this inside the Jenkins container as root

echo "Fixing Docker socket permissions..."

# Fix ownership and permissions
chown root:docker /var/run/docker.sock 2>/dev/null || true
chmod 660 /var/run/docker.sock 2>/dev/null || true

# Verify
if [ -S /var/run/docker.sock ]; then
    echo "Docker socket permissions fixed"
    ls -la /var/run/docker.sock
else
    echo "Warning: Docker socket not found"
fi


