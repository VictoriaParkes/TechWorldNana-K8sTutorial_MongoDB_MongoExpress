variable "project_name" {
  description = "Project name"
  type        = string
  default     = "kubernetes-the-hard-way"
}

variable "account_id" {
  description = "AWS account number"
  type = string
  default = "108181825727"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnet CIDRs are required for load balancer and NAT gateway."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.2.0.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 1
    error_message = "At least 1 private subnet CIDR is required for Kubernetes nodes."
  }
}

variable "prefix_list_id" {
  description = "Prefix list id"
  type        = string
  default     = "pl-fca24795"
}
