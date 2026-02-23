#!/bin/bash
set -e

WORKER_INDEX=${worker_index}
REGION=${region}

# AWS CLI is pre-installed on AL2023
# Install jq if not already
dnf install -y jq

# Install dependencies for test
# command -v jq >/dev/null 2>&1 || dnf install -y jq
# command -v aws >/dev/null 2>&1 || dnf install -y aws-cli

# Get CA cert from Secrets Manager
aws secretsmanager get-secret-value \
    --secret-id k8s-certs-ca \
    --region $REGION \
    --query SecretString \
    --output text > /tmp/ca.pem
    
# secret-id = name of Secrets Manager container
# region = region where Secrets Manager is
# query = output only the value of the secret
# output = format output as plain text and redirect to named file
# query would print to terminal without the output redirection

# Get worker-specific cert
aws secretsmanager get-secret-value \
    --secret-id k8s-certs-worker-$WORKER_INDEX \
    --region $REGION \
    --query SecretString \
    --output text | jq -r '.private_key' > /tmp/worker-$WORKER_INDEX-key.pem

aws secretsmanager get-secret-value \
    --secret-id k8s-certs-worker-$WORKER_INDEX \
    --region $REGION \
    --query SecretString \
    --output text | jq -r '.certificate' > /tmp/worker-$WORKER_INDEX.pem

# Get kube-proxy cert
aws secretsmanager get-secret-value \
    --secret-id k8s-certs-kube-proxy \
    --region $REGION \
    --query SecretString \
    --output text | jq -r '.private_key' > /tmp/kube-proxy-key.pem

aws secretsmanager get-secret-value \
    --secret-id k8s-certs-kube-proxy \
    --region $REGION \
    --query SecretString \
    --output text | jq -r '.certificate' > /tmp/kube-proxy.pem

# Set permissions
chmod 600 /tmp/*-key.pem
chmod 644 /tmp/*.pem

# /tmp?
# Temporary storage for initial setup. Later in your Kubernetes setup process,
# you'd typically move these to permanent locations like /var/lib/kubernetes/
# or /etc/kubernetes/pki/.