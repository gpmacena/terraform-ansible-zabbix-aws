output "zabbix_server_public_ip" {
  description = "IP público do Zabbix Server (Elastic IP)"
  value       = aws_eip.zabbix_server.public_ip
}

output "zabbix_server_id" {
  description = "Instance ID do Zabbix Server"
  value       = aws_instance.zabbix_server.id
}

output "zabbix_frontend_url" {
  description = "URL do frontend Zabbix"
  value       = "http://${aws_eip.zabbix_server.public_ip}/zabbix"
}

output "zabbix_api_url" {
  description = "URL da API JSON-RPC do Zabbix"
  value       = "http://${aws_eip.zabbix_server.public_ip}/zabbix/api_jsonrpc.php"
}

output "agent_instance_ids" {
  description = "IDs das instâncias com Zabbix Agent"
  value       = aws_instance.zabbix_agent[*].id
}

output "agent_public_ips" {
  description = "IPs públicos dos Zabbix Agents"
  value       = aws_instance.zabbix_agent[*].public_ip
}
