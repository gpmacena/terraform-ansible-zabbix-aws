terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configurado via -backend-config na pipeline
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "zabbix-stack"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github-actions"
    }
  }
}

# ─────────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────────
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────
resource "aws_security_group" "zabbix_server" {
  name        = "zabbix-server-${var.environment}"
  description = "Security Group para Zabbix Server"
  vpc_id      = data.aws_vpc.default.id

  # Zabbix Server port (recebe dados dos agents)
  ingress {
    description = "Zabbix Agent -> Server"
    from_port   = 10051
    to_port     = 10051
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP para frontend e API
  ingress {
    description = "HTTP Frontend / API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH para Ansible
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "zabbix-server-${var.environment}" }
}

resource "aws_security_group" "zabbix_agent" {
  name        = "zabbix-agent-${var.environment}"
  description = "Security Group para instâncias com Zabbix Agent"
  vpc_id      = data.aws_vpc.default.id

  # Zabbix passive checks (server -> agent)
  ingress {
    description     = "Zabbix passive checks"
    from_port       = 10050
    to_port         = 10050
    protocol        = "tcp"
    security_groups = [aws_security_group.zabbix_server.id]
  }

  # SSH para Ansible
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "zabbix-agent-${var.environment}" }
}

# ─────────────────────────────────────────────
# EC2 — Zabbix Server
# ─────────────────────────────────────────────
resource "aws_instance" "zabbix_server" {
  ami                         = data.aws_ami.ubuntu_22.id
  instance_type               = var.server_instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.zabbix_server.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = {
    Name    = "zabbix-server-${var.environment}"
    Role    = "zabbix-server"
    Env     = var.environment
  }
}

# ─────────────────────────────────────────────
# EC2 — Zabbix Agents
# ─────────────────────────────────────────────
resource "aws_instance" "zabbix_agent" {
  count = var.agent_count

  ami                         = data.aws_ami.ubuntu_22.id
  instance_type               = var.agent_instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.zabbix_agent.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name    = "zabbix-agent-${var.environment}-${count.index + 1}"
    Role    = "zabbix-agent"
    Env     = var.environment
  }
}

# ─────────────────────────────────────────────
# Elastic IP para o Servidor (IP fixo)
# ─────────────────────────────────────────────
resource "aws_eip" "zabbix_server" {
  instance = aws_instance.zabbix_server.id
  domain   = "vpc"

  tags = { Name = "zabbix-server-eip-${var.environment}" }
}
