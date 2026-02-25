output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "caller_user" {
  value = data.aws_caller_identity.current.user_id
}

output "K8_public_address" {
  value = aws_lb.load_balancer.dns_name
}

output "controller_private_ips" {
  value = [for instance in aws_instance.K8s_controllers : instance.private_ip]
}

output "worker_private_ips" {
  value = [for instance in aws_instance.K8s_workers : instance.private_ip]
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

/*
This code displays important values after `terraform apply` completes. Outputs
show information you need to access and manage your cluster.

AWS Account Info
1. account_id
`value = data.aws_caller_identity.current.account_id`

 - AWS account number
 - Useful for IAM policies and cross-account references

2. caller_arn
`value = data.aws_caller_identity.current.arn`

 - IAM role/user ARN running Terraform
 - Shows who deployed the infrastructure

3. caller_user
'value = data.aws_caller_identity.current.user_id'

 - IAM user ID
 - For audit trails

Cluster Access Info
1. K8_public_address
`value = aws_lb.load_balancer.dns_name`

 - Load balancer DNS name (e.g., "k8s-lb-123456.elb.eu-north-1.amazonaws.com")
 - Critical: This is your Kubernetes API server endpoint
 - Used in kubeconfig files to connect to the cluster

2. controller_private_ips
`value = [for instance in aws_instance.K8s_controllers : instance.private_ip]`

 - Array of controller private IPs (e.g., ["10.0.10.5", "10.0.20.6", "10.0.30.7"])
 - For SSH access via bastion
 - For troubleshooting control plane

3. worker_private_ips
`value = [for instance in aws_instance.K8s_workers : instance.private_ip]`

 - Array of worker private IPs (e.g., ["10.0.10.8", "10.0.20.9", "10.0.30.10"])
 - For SSH access via bastion
 - For debugging worker nodes

4. bastion_public_ip
`value = aws_instance.bastion.public_ip`

 - Bastion host public IP (e.g., "54.123.45.67")
 - Entry point for SSH access to private instances

How to View Outputs
After terraform apply:
`terraform output`

Or specific output:
`terraform output K8_public_address`

Example Usage
SSH to bastion:
`ssh -i keys/kubernetes.id_rsa ec2-user@$(terraform output -raw bastion_public_ip)`

Configure kubectl:
`kubectl config set-cluster kubernetes-the-hard-way \
  --server=https://$(terraform output -raw K8_public_address):443`

SSH to worker-0 via bastion:
`ssh -i keys/kubernetes.id_rsa ec2-user@<bastion_ip>
ssh ec2-user@<worker_private_ip>`

These outputs eliminate manual lookups in the AWS console.
*/