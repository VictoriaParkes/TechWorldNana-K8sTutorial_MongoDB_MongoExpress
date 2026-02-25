resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key_pair" {
  key_name   = "kubernetes"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/keys/kubernetes.id_rsa"
  file_permission = "0600"
}

/*
This code generates an SSH key pair for accessing EC2 instances (controllers, workers, bastion).

The 3 Steps
1. Generate SSH Key Pair
`resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}`

What it does: Creates a new 4096-bit RSA key pair

Generates:
 - Private key (secret, stays with you)
 - Public key (uploaded to AWS)

2. Upload Public Key to AWS
`resource "aws_key_pair" "k8s_key_pair" {
  key_name   = "kubernetes"
  public_key = tls_private_key.k8s_key.public_key_openssh
}`

What it does: Registers the public key with AWS EC2

Result: AWS key pair named "kubernetes" in your account

Used in your code:
`key_name = aws_key_pair.k8s_key_pair.key_name`

All EC2 instances reference this key pair for SSH access

3. Save Private Key Locally
`resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/keys/kubernetes.id_rsa"
  file_permission = "0600"
}`

What it does: Saves private key to local file

Location: `infra/keys/kubernetes.id_rsa`

Permission: `0600` (owner read/write only - secure)

How to Use
SSH into instances:
`ssh -i keys/kubernetes.id_rsa ec2-user@<instance-ip>`

Or from bastion:
`ssh -i keys/kubernetes.id_rsa ec2-user@<bastion-ip>
# Then from bastion to private instances
ssh ec2-user@<worker-private-ip>`

Key Difference from Certificate Keys
This SSH key: For shell access to EC2 instances (administrative)

Certificate keys (cert_auth.tf): For Kubernetes component authentication (cluster operations)

Completely separate purposes.
*/