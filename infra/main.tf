provider "aws" {
  region = var.region
  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/terraform-execution"
    session_name = "terraform-session-example"
  }
}

resource "aws_vpc" "k8_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "k8_public_subnets" {
  for_each = {
    for i, cidr in var.public_subnet_cidrs :
    "subnet${i + 1}" => { cidr = cidr, index = i }
  }

  vpc_id                  = aws_vpc.k8_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = data.aws_availability_zones.available.names[each.value.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${each.key}"
  }
}

resource "aws_subnet" "k8_private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id     = aws_vpc.k8_vpc.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "k8_igw" {
  vpc_id = aws_vpc.k8_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "k8_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.k8_public_subnets["subnet1"].id

  tags = {
    Name = "${var.project_name}-nat"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.k8_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.k8_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.k8_nat.id
  }

  tags = {
    Name = "${var.project_name}-private-route-table"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  for_each = aws_subnet.k8_public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_rt_association" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.k8_private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "k8_sg" {
  name        = "${var.project_name}-sg"
  description = "Kubernetes security group"
  vpc_id      = aws_vpc.k8_vpc.id

  tags = {
    Name = "${var.project_name}-security-group"
  }
}

# inbound firewall rule that allows HTTP traffic (port 80) to reach resources in the security group, but only from IP addresses in the prefix list
resource "aws_vpc_security_group_ingress_rule" "prefix_ingress_rule" {
  security_group_id = aws_security_group.k8_sg.id

  prefix_list_id = var.prefix_list_id
  from_port      = 80
  ip_protocol    = "tcp"
  to_port        = 80
}

# allows HTTPS traffic (port 443) to reach resources in the security group, but only from IP addresses in the prefix list
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.k8_sg.id
  prefix_list_id    = var.prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# allows SSH traffic (port 22) to reach resources in the security group, but only from IP addresses in the prefix list
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k8_sg.id
  prefix_list_id    = var.prefix_list_id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# allows access to the Kubernetes API server (port 6443), but only from IP addresses in your prefix list
resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.k8_sg.id
  prefix_list_id    = var.prefix_list_id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
}

# allows ping (ICMP) from IP addresses in the prefix list
resource "aws_vpc_security_group_ingress_rule" "icmp_echo" {
  security_group_id = aws_security_group.k8_sg.id
  prefix_list_id    = var.prefix_list_id
  from_port         = 8
  to_port           = 0
  ip_protocol       = "icmp"
}
/* Useful for troubleshooting network connectivity issues from approved locations 
 - ip_protocol = "icmp": Internet Control Message Protocol - used for network diagnostics
 - from_port = -1 / to_port = -1: For ICMP, -1 means all ICMP types/codes
 - Enables ping commands to test if nodes are reachable and measure network latency
*/

# allows all traffic within the VPC (10.0.0.0/16) and pod network (10.200.0.0/16)
resource "aws_vpc_security_group_ingress_rule" "vpc_internal" {
  security_group_id = aws_security_group.k8_sg.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}
/* This enables unrestricted communication between all resources inside your VPC
(nodes, load balancers, databases). Essential for Kubernetes nodes to communicate
with each other for cluster operations without firewall restrictions.
 - cidr_ipv4 = "10.0.0.0/16": Your VPC's internal network range
 - ip_protocol = "-1": All protocols (TCP, UDP, ICMP, etc.)
 - No port restrictions - all ports are open
*/

# allows ALL traffic from the Kubernetes pod network (10.200.0.0/16)
resource "aws_vpc_security_group_ingress_rule" "pod_network" {
  security_group_id = aws_security_group.k8_sg.id
  cidr_ipv4         = "10.200.0.0/16"
  ip_protocol       = "-1"
}
/* Enables pod-to-pod communication across the cluster. Pods get IPs from this
range and need unrestricted access to communicate with each other for services,
DNS lookups, and inter-pod networking that Kubernetes requires.
 - cidr_ipv4 = "10.200.0.0/16": The CIDR block for Kubernetes pod networks
 - ip_protocol = "-1": Allows all protocols for pod communication
*/

# Allow SSH from bastion to private instances
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id            = aws_security_group.k8_sg.id
  referenced_security_group_id = aws_security_group.k8_sg.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.k8_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "load_balancer" {
  load_balancer_type = "network"
  name               = "${var.project_name}-load-balancer"
  internal           = false

  subnets = [for subnet in aws_subnet.k8_public_subnets : subnet.id]

  tags = {
    Name = "${var.project_name}-load-balancer"
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name        = "${var.project_name}-target-group"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.k8_vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    interval            = 30
    unhealthy_threshold = 2
    protocol            = "TCP"
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.alb_target_group.arn
      }
    }
  }

  tags = {
    Name = "${var.project_name}-alb-listener"
  }
}

resource "aws_lb_target_group_attachment" "target_group_attachment" {
  for_each = {
    for k, v in aws_instance.K8s_controllers :
    k => v
  }

  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = each.value.private_ip
  port             = 6443
}

resource "aws_instance" "K8s_controllers" {
  count = length(var.private_subnet_cidrs)

  ami                    = data.aws_ami.image_id.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.k8s_key_pair.key_name
  subnet_id              = aws_subnet.k8_private_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.k8_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  source_dest_check      = false
  monitoring             = true

  user_data = templatefile("${path.module}/scripts/controller-userdata.sh", {
    controller_index = count.index
    region       = var.region
  })

  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  tags = {
    Name = "controller-${count.index}"
  }
}

resource "aws_instance" "K8s_workers" {
  count = length(var.private_subnet_cidrs)

  ami                    = data.aws_ami.image_id.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.k8s_key_pair.key_name
  subnet_id              = aws_subnet.k8_private_subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.k8_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.k8s_profile.name
  source_dest_check      = false
  monitoring             = true

  user_data = templatefile("${path.module}/scripts/worker-userdata.sh", {
    worker_index = count.index
    region       = var.region
  })

  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  tags = {
    Name = "worker-${count.index}"
  }
}

/*
K8s_workers User-data:
This code generates a customized startup script for each worker instance by
injecting variables into a template file.

user_data: Script that runs automatically when the EC2 instance first boots

templatefile(): Terraform function that:

  1. Reads a template file
  2. Replaces placeholders with actual values
  3. Returns the rendered script

"${path.module}/scripts/worker-userdata.sh": Path to your template file
(relative to Terraform module)

Variables passed to template:
 - worker_index = count.index: Worker number (0, 1, 2, etc.)
 - region = var.region: AWS region (e.g., "us-east-1")

How the Template Works:
The worker-userdata.sh file, references the variables:
 - ${worker_index}: Which worker node this is (used for unique naming)
 - ${region}: AWS region (used for API calls)
Retrieves worker-specific certificate:
aws secretsmanager get-secret-value \
  --secret-id k8s-certs-worker-$WORKER_INDEX \
  --region $REGION

worker-0 gets:
WORKER_INDEX=0
REGION=us-east-1
worker-1 gets:
WORKER_INDEX=1
REGION=us-east-1

This allows each worker to retrieve its unique certificate (k8s-certs-worker-0,
k8s-certs-worker-1, etc.) from Secrets Manager automatically on boot.
*/

# Bastion host for accessing private instances
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.image_id.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.k8s_key_pair.key_name
  subnet_id                   = aws_subnet.k8_public_subnets["subnet1"].id
  vpc_security_group_ids      = [aws_security_group.k8_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.k8_vpc.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.k8_private_subnets : subnet.id]
  security_group_ids  = [aws_security_group.k8_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-secretsmanager-endpoint"
  }
}
