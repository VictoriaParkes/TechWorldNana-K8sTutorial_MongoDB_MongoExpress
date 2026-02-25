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

: <<'COMMENT'
This worker user_data script runs automatically when a worker EC2 instance boots.
It retrieves worker-specific certificates from AWS Secrets Manager.

Setup
 - `set -e` → Exit on any error
 - Sets `WORKER_INDEX` (0, 1, or 2) and `REGION` from Terraform
 - Installs `jq` for JSON parsing


Certificate Retrieval:

1. CA Certificate
aws secretsmanager get-secret-value \
    --secret-id k8s-certs-ca \
    --region $REGION \
    --query SecretString \
    --output text > /tmp/ca.pem

 - Secret: `k8s-certs-ca`
 - Output: `/tmp/ca.pem`
 - Used to verify API server identity

2. Worker-Specific Kubelet Cert
--secret-id k8s-certs-worker-$WORKER_INDEX

 - Worker-0 gets: `k8s-certs-worker-0`
 - Worker-1 gets: `k8s-certs-worker-1`
 - Worker-2 gets: `k8s-certs-worker-2`
 - Outputs: `/tmp/worker-X-key.pem` and `/tmp/worker-X.pem`
 Unique for each worker node for authentication

 3. Kube-Proxy Cert
 `--secret-id k8s-certs-kube-proxy`

  - Secret: `k8s-certs-kube-proxy`
  - Outputs: `/tmp/kube-proxy-key.pem` and `/tmp/kube-proxy.pem`
  - Used by kube-proxy for communication with API server
  Shared by all workers

Set Permissions
 - Private keys: `chmod 600` (read/write for owner only)
 - Certificates: `chmod 644` (read for all, write for owner)

Key Differences from Controller Script

Workers retrieve:
 - CA cert (verify API server)
 - Worker-specific kubelet cert (unique identity)
 - Kube-proxy cert (shared)

Controllers retrieve:
 - CA cert (verify API server)
 - API server cert
 - Service account cert
 - Controller manager cert
 - Scheduler cert
 - Admin cert

Why /tmp?
Temporary staging during boot. Later Kubernetes setup steps would move these to
permanent locations like `/var/lib/kubelet/` or `/etc/kubernetes/pki/`.
COMMENT
