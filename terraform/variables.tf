variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente (staging, production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "O ambiente deve ser 'staging' ou 'production'."
  }
}

variable "key_name" {
  description = "Nome do Key Pair AWS para acesso SSH"
  type        = string
}

variable "server_instance_type" {
  description = "Tipo de instância EC2 para o Zabbix Server"
  type        = string
  default     = "t3.medium"
}

variable "agent_instance_type" {
  description = "Tipo de instância EC2 para os Zabbix Agents"
  type        = string
  default     = "t3.micro"
}

variable "agent_count" {
  description = "Número de instâncias com Zabbix Agent"
  type        = number
  default     = 2

  validation {
    condition     = var.agent_count >= 0 && var.agent_count <= 10
    error_message = "O número de agents deve ser entre 0 e 10."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs permitidos para SSH (GitHub Actions usa 0.0.0.0/0 por padrão — restrinja em produção)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
