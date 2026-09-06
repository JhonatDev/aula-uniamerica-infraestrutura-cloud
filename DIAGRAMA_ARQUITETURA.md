# 📐 Diagrama Técnico de Arquitetura Cloud Serverless (To-Do App)

```mermaid
flowchart TD
    subgraph Internet ["🌐 Internet Pública"]
        User["👤 Usuário Final (Navegador)"]
        Attacker["⚠️ Atacante / Acesso Direto Rejeitado"]
    end

    subgraph DNS_CDN_Proxy ["🛡️ Camada 1: DNS, Certificados & Proxy Reverso"]
        DNS["🌐 DNS (GoDaddy)\n[Hosts: todo.jhonatanamigos.site e api.jhonatanamigos.site]"]
        ACM["🔒 AWS ACM Certificates\n(CloudFront: us-east-1 / API: sa-east-1)"]
        ProxyFront["🔀 Proxy Reverso CDN\n(Amazon CloudFront Distribution)"]
        ProxyBack["🔀 Proxy Reverso API\n(AWS API Gateway HTTP API)"]
    end

    subgraph Frontend_Redundancy ["⚡ Camada 2: Front-end Redundante (Serverless CDN)"]
        POP1["📍 CloudFront Edge Location (São Paulo)"]
        POP2["📍 CloudFront Edge Location (Virginia - Failover)"]
        S3Bucket["📦 Amazon S3 Bucket (React Static SPA)\n[Acesso direto por URL S3: BLOQUEADO ❌]"]
    end

    subgraph Backend_Layer ["⚡ Camada 3: Back-end Serverless (AWS Lambda)"]
        Lambda["⚡ AWS Lambda (Express Serverless Handler)\n[Acesso direto sem API Gateway: BLOQUEADO ❌]"]
    end

    subgraph Database_Layer ["🛢️ Camada 4: Banco de Dados Gerenciado (DynamoDB)"]
        DynamoDB[("⚡ AWS DynamoDB (Tabela: Todos)\n[Billing: PAY_PER_REQUEST]\n[Acesso público pela internet: BLOQUEADO ❌]")]
    end

    %% Fluxos Permitidos
    User -->|1. HTTPS 443| DNS
    DNS -->|2. Resolução TLS 1.3| ProxyFront
    ProxyFront -->|3a. Requisição Front-end /| POP1
    ProxyFront -.->|3a. Redundância / Failover| POP2
    POP1 & POP2 -->|4. Autenticação via OAC| S3Bucket

    DNS -->|2b. Requisição API /api/*| ProxyBack
    ProxyBack -->|5. Invocação IAM Privada| Lambda
    Lambda -->|6. AWS SDK v3 / SigV4| DynamoDB

    %% Fluxos Bloqueados
    Attacker -.->|❌ Bloqueado (403 Forbidden - Sem OAC)| S3Bucket
    Attacker -.->|❌ Bloqueado (Sem Function URL Exposta)| Lambda
    Attacker -.->|❌ Bloqueado (Requer IAM SigV4 Válido)| DynamoDB

    style User fill:#2ecc71,stroke:#27ae60,color:#fff
    style Attacker fill:#e74c3c,stroke:#c0392b,color:#fff
    style DNS fill:#3498db,stroke:#2980b9,color:#fff
    style ACM fill:#9b59b6,stroke:#8e44ad,color:#fff
    style ProxyFront fill:#9b59b6,stroke:#8e44ad,color:#fff
    style ProxyBack fill:#9b59b6,stroke:#8e44ad,color:#fff
    style S3Bucket fill:#f39c12,stroke:#d35400,color:#fff
    style Lambda fill:#f39c12,stroke:#d35400,color:#fff
    style DynamoDB fill:#11998e,stroke:#38ef7d,color:#fff
```

---

## 🔒 Matriz Detalhada de Portas e Protocolos

| Origem | Destino | Porta | Protocolo | Tipo de Tráfego | Status |
| :--- | :--- | :---: | :---: | :--- | :---: |
| **Cliente Web** | **CloudFront** | 443 | HTTPS (TLS 1.3) | Público | ✅ Permitido |
| **Cliente Web** | **API Gateway** | 443 | HTTPS (TLS 1.3) | Público | ✅ Permitido |
| **CloudFront** | **S3 Bucket** | 443 | HTTPS (OAC SigV4) | Interno AWS | ✅ Permitido |
| **API Gateway** | **AWS Lambda** | AWS Internal | IAM Invoke | Interno AWS | ✅ Permitido |
| **AWS Lambda** | **AWS DynamoDB** | 443 | HTTPS (IAM SigV4) | Interno AWS | ✅ Permitido |
| **Internet** | **S3 Bucket Direct** | 80 / 443 | HTTP / HTTPS | Direto | ❌ Bloqueado |
| **Internet** | **Lambda Direct** | Qualquer | Direct Invocation | Direto | ❌ Bloqueado |
| **Internet** | **DynamoDB Direct** | Qualquer | Unauthenticated | Direto | ❌ Bloqueado |
