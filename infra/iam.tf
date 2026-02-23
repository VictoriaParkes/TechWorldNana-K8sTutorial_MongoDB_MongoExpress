####################################################
# IAM role for instances to access Secrets Manager #
####################################################

# Inline IAM policy that grants EC2 instances permission to read secrets from
# AWS Secrets Manager
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.project_name}-secrets-access"
  role = aws_iam_role.k8s_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # the secret this policy applies to
        Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:k8s-certs-*"
      },
    ]
  })
}
/*
Attaches a policy directly to the IAM role (inline policy, not managed).
The policy allows the role to access secrets with the prefix k8s-certs-
in the current account and region.
*/

# IAM role for EC2 instances
resource "aws_iam_role" "k8s_instance_role" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
  ] })
}


# Intance profile for EC2 instances
resource "aws_iam_instance_profile" "k8s_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.k8s_instance_role.name
}
/*
An instance profile is a container for an IAM role that allows EC2 instances
to assume that role. EC2 instances can't directly use IAM roles.
The instance profile acts as a bridge: IAM Role → Instance Profile → EC2 Instance
When attached to an EC2 instance, it:
 - Provides temporary AWS credentials to applications running on the instance
 - Auto-rotates credentials every few hours
 - Eliminates need to hardcode AWS access keys

 For this project it means worker nodes can run aws secretsmanager get-secret-value
 without providing permanent credentials - the instance profile automatically
 provides temporary credentials
*/

#################
# Store CA cert #
#################

# empty container in AWS Secrets Manager to hold a secret
resource "aws_secretsmanager_secret" "ca_cert" {
  name = "k8s-certs-ca"
}

# Store the CA certificate inside the Secrets Manager container
# Creates a version of the secret with the actual content, stored as plain text
resource "aws_secretsmanager_secret_version" "ca_cert" {
  # the secrets container
  secret_id = aws_secretsmanager_secret.ca_cert.id
  # the actual secret value (the CA cert PEM data)
  secret_string = tls_self_signed_cert.ca_cert.cert_pem
}

/*
The aws_secretsmanager_secret resource creates an empty secret container in AWS Secrets Manager.
The aws_secretsmanager_secret_version resource adds the actual secret value (a CA certificate)
to that container. This two-step process is required by AWS Secrets Manager.
This allows secret rotation and versioning features to work properly, you can create new versions
recreating the secret itself.
*/

##############################################
# Store worker certs (one secret per worker) #
##############################################

# creates multiple secrets, one for each worker node
# each secret will be named k8s-certs-worker-{worker-name}
resource "aws_secretsmanager_secret" "worker_certs" {
  for_each = aws_instance.K8s_workers
  name     = "k8s-certs-worker-${each.key}"
}

# Store the private key and certificate for each worker node
resource "aws_secretsmanager_secret_version" "worker_certs" {
  for_each = aws_instance.K8s_workers

  secret_id = aws_secretsmanager_secret.worker_certs[each.key].id
  secret_string = jsonencode({
    private_key = tls_private_key.nodes[each.key].private_key_pem
    certificate = tls_locally_signed_cert.nodes[each.key].cert_pem
  })
}

/*
Each worker node needs its own unique certificate for authentication
with the Kubernetes API server. This is handled by creating a separate
AWS Secret Manager secret for each worker node. The secret contains both
the private key and certificate in JSON format.

This allows each worker to retrieve its specific credentials when needed,
without exposing other workers' keys or having to manage them manually.
 - Security isolation, compromised worker only requires revoking one cert (doesn't affect others)
 - Node indendtity, each worker has distinct identity in the cluster
 - Audit trail, API server logs show which specific worker accessed the API
 - Automated rotation, each worker's cert can be rotated independently
*/

##########################
# Store kube-proxy certs #
##########################

# Store the kube-proxy certificate and private key in Secrets Manager as a
# single JSON object, shared by all workers

resource "aws_secretsmanager_secret" "kube_proxy" {
  name = "k8s-certs-kube-proxy"
}

resource "aws_secretsmanager_secret_version" "kube_proxy" {
  secret_id = aws_secretsmanager_secret.kube_proxy.id
  secret_string = jsonencode({
    private_key = tls_private_key.kube_proxy.private_key_pem
    certificate = tls_locally_signed_cert.kube_proxy.cert_pem
  })
}

/*
The kube-proxy component runs on each worker node and needs its own certificate
for secure communication with the API server. Unlike worker nodes which have
unique certificates, kube-proxy uses a shared certificate across all workers.
All kube-proxy instances perform the same role.

This approach:
 - Reduces the number of secrets (only 1 instead of N worker nodes)
 - Simplifies certificate management (single cert to rotate)
 - Maintains security (kube-proxy still has unique identity)
 - Follows Kubernetes best practices (kube-proxy typically uses a dedicated service account)

The certificate is stored in AWS Secrets Manager so it can be retrieved by
kube-proxy containers during cluster setup, without embedding credentials in
configuration files or Docker images.
*/