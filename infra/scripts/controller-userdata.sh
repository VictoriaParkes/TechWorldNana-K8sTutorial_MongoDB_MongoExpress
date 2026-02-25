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

# heredoc for block comments:
: <<'COMMENT'
This user_data script runs automatically when a controller EC2 instance boots.
It retrieves all control plane certificates from AWS Secrets Manager and saves
them locally.

What It Does
Setup (lines 1-9):
 - set -e → Exit if any command fails
 - Sets variables from Terraform: controller index and AWS region

Certificate Retrieval Pattern (repeated 6 times):

Each secret follows this flow:
aws secretsmanager get-secret-value \
  --secret-id <secret-name> \
  --region $REGION \
  --query SecretString \
  --output text | jq -r '.private_key' > /tmp/<file>.pem

The 6 Secrets Retrieved

1. CA Certificate
 - Secret: `k8s-certs-ca`
 - Output: `/tmp/ca.pem`
 - No `jq` parsing (plain text, not JSON)

2. API Server
- Secret: `k8s-certs-kubernetes-api`
- Outputs: `/tmp/kubernetes-key.pem` and `/tmp/kubernetes.pem`

3. Service Account
 - Secret: `k8s-certs-service-account`
 - Outputs: `/tmp/service-account-key.pem` and `/tmp/service-account.pem`

4. Controller Manager
 - Secret: `k8s-certs-controller-manager`
 - Outputs: `/tmp/kube-controller-manager-key.pem` and `/tmp/kube-controller-manager.pem`

5. Scheduler
 - Secret: `k8s-certs-scheduler`
 - Outputs: `/tmp/kube-scheduler-key.pem` and `/tmp/kube-scheduler.pem`

6. Admin
 - Secret: `k8s-certs-admin`
 - Outputs: `/tmp/admin-key.pem` and `/tmp/admin.pem`

Set Permissions
 - Private keys: `600` (owner read/write only)
 - Certificates: `644` (owner read/write, others read only)

How jq Works
`jq -r '.private_key'` extracts the private_key field from JSON:
{"private_key": "...", "certificate": "..."}

→ Returns just the private key string

This script automates certificate distribution
COMMENT
