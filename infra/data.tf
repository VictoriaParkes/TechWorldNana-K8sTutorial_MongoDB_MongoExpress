data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "image_id" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  tags = {
    Name = "amazon_linux_2023"
  }
}

/*
This code queries AWS for dynamic information that Terraform needs but doesn't
create. Data sources fetch existing AWS resources.

1. AWS Caller Identity
`data "aws_caller_identity" "current" {}`

What it does: Gets info about the AWS account running Terraform

Returns:
 - `account_id` - AWS account number
 - `arn` - IAM role/user ARN
 - `user_id` - IAM user ID

Used in your code:
 - IAM policies (line in cert_auth.tf references account ID)
 - Outputs (outputs.tf shows account info)

2. Availability Zones
`data "aws_availability_zones" "available" {
  state = "available"
}`

What it does: Lists all available AZs in your region

Returns: Array of AZ names (e.g., ["eu-north-1a", "eu-north-1b", "eu-north-1c"])

Used in your code:
`availability_zone = data.aws_availability_zones.available.names[count.index]`

Distributes subnets across different AZs for high availability

3. Amazon Linux 2023 AMI
`data "aws_ami" "image_id" {
  most_recent = true
  owners      = ["amazon"]`

What it does: Finds the latest Amazon Linux 2023 AMI ID

Filters:
 - `name = "al2023-ami-*-kernel-6.1-x86_64"` - AL2023 with kernel 6.1, x86_64 architecture
 - `virtualization-type = "hvm"` - Hardware Virtual Machine (modern virtualization)
 - `most_recent = true` - Gets newest matching AMI

Returns: AMI ID (e.g., "ami-0c55b159cbfafe1f0")

Used in your code:
`ami = data.aws_ami.image_id.id`

All EC2 instances (controllers, workers, bastion) use this AMI

Why Use Data Sources?
Dynamic values: AMI IDs change with updates; this always gets the latest
Region-specific: AZs differ per region; this adapts automatically
No hardcoding: Account ID fetched dynamically instead of hardcoded
*/