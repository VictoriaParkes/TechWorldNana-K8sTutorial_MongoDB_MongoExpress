#!/bin/bash
set -e

CONTROLLER_INDEX=${controller_index}
REGION=${region}

# AWS CLI is pre-installed on AL2023
# Install jq if not already
dnf install -y jq

# Install dependencies for test
# command -v jq >/dev/null 2>&1 || dnf install -y jq
# command -v aws >/dev/null 2>&1 || dnf install -y aws-cli

# CA cert
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-ca \
  --region $REGION \
  --query SecretString \
  --output text > /tmp/ca.pem

# Kubernetes API Server certs
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-kubernetes-api \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/kubernetes-key.pem

aws secretsmanager get-secret-value \
  --secret-id k8s-certs-kubernetes-api \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.certificate' > /tmp/kubernetes.pem

# Service Account certs
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-service-account \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/service-account-key.pem

aws secretsmanager get-secret-value \
  --secret-id k8s-certs-service-account \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.certificate' > /tmp/service-account.pem

# Controller Manager certs
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-controller-manager \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/kube-controller-manager-key.pem

aws secretsmanager get-secret-value \
  --secret-id k8s-certs-controller-manager \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.certificate' > /tmp/kube-controller-manager.pem

# Scheduler certs
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-scheduler \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/kube-scheduler-key.pem

aws secretsmanager get-secret-value \
  --secret-id k8s-certs-scheduler \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.certificate' > /tmp/kube-scheduler.pem

# Admin certs
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-admin \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/admin-key.pem

aws secretsmanager get-secret-value \
  --secret-id k8s-certs-admin \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.certificate' > /tmp/admin.pem

# Set permissions
chmod 600 /tmp/*-key.pem
chmod 644 /tmp/*.pem
