terraform {
  required_version = ">= 1.1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.3.0"
    }
  }

  backend "s3" {
    bucket               = "icarus-terraform"
    key                  = "terraform.tfstate"
    region               = "us-east-2"
    workspace_key_prefix = "workspace"
  }
}

variable "ssh_key_pair_name" {
  description = "Web server SSH key pair name"
  type        = string
  default     = "icarus-admin"
}

locals {
  tags = { Name : "${title(terraform.workspace)} Icarus", Project : "Icarus", Terraform : "True" }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = local.tags
  }
}

resource "aws_vpc" "main" {
  cidr_block                       = "192.168.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
}

resource "aws_internet_gateway" "public_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_gateway.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.public_gateway.id
  }
}

resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

resource "aws_subnet" "public" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, 10)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 10)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
}

resource "aws_security_group" "web_server" {
  description = "Allow HTTP, HTTPS, and SSH access"
  vpc_id      = aws_vpc.main.id
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  # implicit with AWS but Terraform requires this to be explicit
  egress {
    description      = "Allow all egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "web" {
  # CentOS Stream 8 https://www.centos.org/download/aws-images/
  ami                    = "ami-045b0a05944af45c1"
  instance_type          = "t3.nano"
  monitoring             = true
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  ebs_optimized          = true
  key_name               = var.ssh_key_pair_name
  volume_tags            = local.tags
  credit_specification {
    cpu_credits = "standard"
  }
  root_block_device {
    volume_type = "gp3"
  }
}

data "aws_route53_zone" "main" {
  name = "aws.ivyplus.net"
}

resource "aws_route53_record" "web" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  records = [aws_instance.web.public_ip]
  type    = "A"
  ttl     = 60
  zone_id = data.aws_route53_zone.main.zone_id
}

output "web_server_address" {
  value = aws_instance.web.public_ip
}
