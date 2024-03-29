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
  availability_zone               = "us-east-2a"
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, 10)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 10)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
}

resource "aws_subnet" "extra" {
  # currently unused but ALB requires at least two subnets in two different AZs
  vpc_id                          = aws_vpc.main.id
  availability_zone               = "us-east-2b"
  cidr_block                      = cidrsubnet(aws_vpc.main.cidr_block, 8, 11)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 11)
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true
}

resource "aws_security_group" "load_balancer" {
  name        = "${local.tags.Name}-loadbalancer"
  description = "Allow HTTP and HTTPS access"
  vpc_id      = aws_vpc.main.id
}
# using standalone security group rules to avoid cycle errors
resource "aws_security_group_rule" "http_ingress" {
  description       = "Allow inbound HTTP traffic from Internet to ALB"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.load_balancer.id
}
resource "aws_security_group_rule" "https_ingress" {
  description       = "Allow inbound HTTPS traffic from Internet to ALB"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.load_balancer.id
}
resource "aws_security_group_rule" "http_egress" {
  description              = "Allow HTTP egress from ALB to web server"
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web_server.id
  security_group_id        = aws_security_group.load_balancer.id
}

resource "aws_security_group" "web_server" {
  name        = "${local.tags.Name}-webserver"
  description = "Allow inbound HTTP from ALB and SSH access from the Internet"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer.id]
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
