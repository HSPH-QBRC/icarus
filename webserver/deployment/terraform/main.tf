terraform {
  required_version = ">= 1.1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.7.0"
    }
  }

  backend "s3" {
    bucket               = "icarus-terraform"
    key                  = "terraform.tfstate"
    region               = "us-east-2"
    workspace_key_prefix = "workspace"
  }
}

locals {
  secrets_dir = "/home/centos"
  tags        = { Name : "${title(terraform.workspace)} Icarus", Project : "Icarus", Terraform : "True" }
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
  ami                         = "ami-045b0a05944af45c1"
  instance_type               = "t3.micro"
  monitoring                  = true
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_server.id]
  ebs_optimized               = true
  key_name                    = var.ssh_key_pair_name
  volume_tags                 = local.tags
  user_data_replace_on_change = true
  root_block_device {
    volume_type = "gp3"
  }
  provisioner "file" {
    source      = "../secrets/config.ini"
    destination = "${local.secrets_dir}/config.ini"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-encrypt-cert.pem"
    destination = "${local.secrets_dir}/sp-encrypt-cert.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-encrypt-key.pem"
    destination = "${local.secrets_dir}/sp-encrypt-key.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-signing-cert.pem"
    destination = "${local.secrets_dir}/sp-signing-cert.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  provisioner "file" {
    source      = "../secrets/sp-signing-key.pem"
    destination = "${local.secrets_dir}/sp-signing-key.pem"
    connection {
      host        = self.public_ip
      user        = "centos"
      private_key = file("../secrets/icarus-admin.pem")
    }
  }
  user_data = <<-EOT
  #!/usr/bin/bash -ex

  # install Puppet and other dependencies
  /usr/bin/dnf -y install https://yum.puppet.com/puppet7-release-el-8.noarch.rpm
  /usr/bin/dnf -y install git puppet-agent ruby

  # configure Icarus
  export PROJECT_ROOT=/srv/icarus
  /usr/bin/mkdir $PROJECT_ROOT
  /usr/bin/chown centos:centos $PROJECT_ROOT
  /usr/bin/su -c "/usr/bin/git clone https://github.com/HSPH-QBRC/icarus.git $PROJECT_ROOT" centos
  /usr/bin/su -c "cd $PROJECT_ROOT && /usr/bin/git checkout -q ${var.git_commit}" centos

  # install librarian-puppet and Puppet modules
  /usr/bin/gem install librarian-puppet -v 3.0.1 --no-document
  # need to set $HOME: https://github.com/rodjek/librarian-puppet/issues/258
  export HOME=/root
  /usr/local/bin/librarian-puppet config path /opt/puppetlabs/puppet/modules --global
  /usr/local/bin/librarian-puppet config tmp /tmp --global
  PATH=/opt/puppetlabs/bin:$PATH
  cd $PROJECT_ROOT/webserver/deployment/puppet && /usr/local/bin/librarian-puppet install

  # run Puppet
  export FACTER_SITE_URL="${var.site_url}"
  export FACTER_SECRETS_DIR="${local.secrets_dir}"
  /opt/puppetlabs/bin/puppet apply $PROJECT_ROOT/webserver/deployment/puppet/manifests/site.pp
  EOT
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

resource "aws_route53_record" "web6" {
  name    = "covid.${data.aws_route53_zone.main.name}"
  records = aws_instance.web.ipv6_addresses
  type    = "AAAA"
  ttl     = 60
  zone_id = data.aws_route53_zone.main.zone_id
}
