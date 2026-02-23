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
