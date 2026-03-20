# 🔭 Zabbix Stack — GitHub Actions + Terraform + Ansible

Pipeline completa para provisionar e configurar um ambiente Zabbix na AWS, com API pronta para integração com o **Avents**.

---

## 🏗️ Arquitetura

```
GitHub Actions
├── deploy.yml       → Provisiona + Configura
│   ├── Job 1: Terraform  → EC2 Zabbix Server (t3.medium) + EC2 Agents (t3.micro)
│   ├── Job 2: Ansible    → Instala Zabbix Server + PostgreSQL + Frontend
│   └── Job 3: Ansible    → Instala Zabbix Agent 2 + registra hosts via API
└── destroy.yml      → Destrói toda a infraestrutura (requer confirmação)
```

### Recursos AWS criados

| Recurso | Qtd | Tipo |
|---|---|---|
| EC2 Zabbix Server | 1 | t3.medium |
| EC2 Zabbix Agents | N (configurável) | t3.micro |
| Elastic IP | 1 | — |
| Security Groups | 2 | zabbix-server, zabbix-agent |

---

## 🔐 Secrets necessários no GitHub

Configure em **Settings → Secrets and variables → Actions**:

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key da IAM com permissões EC2 + S3 |
| `AWS_SECRET_ACCESS_KEY` | Secret Key da IAM |
| `AWS_REGION` | Ex: `us-east-1` |
| `AWS_KEY_PAIR_NAME` | Nome do Key Pair criado na AWS |
| `SSH_PRIVATE_KEY` | Conteúdo da chave `.pem` (começa com `-----BEGIN`) |
| `TF_STATE_BUCKET` | Nome do bucket S3 para armazenar o tfstate |
| `ZABBIX_ADMIN_PASSWORD` | Senha do admin Zabbix (substitui o padrão) |
| `ZABBIX_DB_PASSWORD` | Senha do usuário PostgreSQL do Zabbix |

### Permissões mínimas IAM

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 🚀 Como usar

### 1. Pré-requisitos

- Bucket S3 criado para o tfstate
- Key Pair criado na AWS (`.pem` salvo como secret `SSH_PRIVATE_KEY`)
- Todos os secrets configurados

### 2. Deploy

1. Vá em **Actions → 🚀 Deploy Zabbix Stack**
2. Clique em **Run workflow**
3. Informe:
   - `environment`: `staging` ou `production`
   - `agent_count`: quantidade de VMs com Zabbix Agent (ex: `3`)
4. Acompanhe os 3 jobs

Ao final, o summary do workflow exibirá:

```
🌐 Zabbix URL  : http://<IP>/zabbix
🔌 API URL     : http://<IP>/zabbix/api_jsonrpc.php
```

### 3. Destroy

1. Vá em **Actions → 💣 Destroy Zabbix Stack**
2. Clique em **Run workflow**
3. Selecione o ambiente e digite `DESTROY` para confirmar

---

## 🔌 Integração com Avents (API Zabbix)

### Endpoint
```
POST http://<ZABBIX_SERVER_IP>/zabbix/api_jsonrpc.php
Content-Type: application/json
```

### Autenticar e buscar eventos
```bash
# 1. Login
curl -s -X POST http://<IP>/zabbix/api_jsonrpc.php \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "user.login",
    "params": { "username": "Admin", "password": "SUA_SENHA" },
    "id": 1
  }'
# Resposta: { "result": "TOKEN_AQUI" }

# 2. Buscar eventos (últimas 24h)
curl -s -X POST http://<IP>/zabbix/api_jsonrpc.php \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "event.get",
    "params": {
      "output": "extend",
      "time_from": '$(date -d "24 hours ago" +%s)',
      "sortfield": "clock",
      "sortorder": "DESC",
      "limit": 100
    },
    "auth": "TOKEN_AQUI",
    "id": 2
  }'
```

### Token de API (sem expiração)
O Ansible cria automaticamente um token chamado `avents-integration`. Para gerá-lo manualmente:

```json
{
  "jsonrpc": "2.0",
  "method": "token.create",
  "params": {
    "name": "avents-integration",
    "userid": "1",
    "status": 0
  },
  "auth": "TOKEN_SESSÃO",
  "id": 1
}
```

Use o token retornado no header `Authorization: Bearer <token>` nas chamadas do Avents.

---

## 📁 Estrutura de arquivos

```
.
├── .github/workflows/
│   ├── deploy.yml          # Pipeline de deploy (3 jobs)
│   └── destroy.yml         # Pipeline de destroy (com confirmação)
├── terraform/
│   ├── main.tf             # EC2, Security Groups, Elastic IP
│   ├── variables.tf        # Variáveis configuráveis
│   └── outputs.tf          # IPs, IDs e URLs
└── ansible/
    ├── inventory/
    │   └── aws_ec2.yml     # Inventário dinâmico AWS
    ├── group_vars/
    │   └── all.yml         # Variáveis globais
    ├── roles/
    │   ├── zabbix_server/  # Instala Server + PostgreSQL + Frontend
    │   └── zabbix_agent/   # Instala Agent 2 + registra no Server
    ├── zabbix_server.yml   # Playbook do servidor
    └── zabbix_agents.yml   # Playbook dos agents
```
