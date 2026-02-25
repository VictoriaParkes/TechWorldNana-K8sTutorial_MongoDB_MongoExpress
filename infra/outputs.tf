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

