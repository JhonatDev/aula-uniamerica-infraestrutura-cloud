# 🚀 Documentação Técnica de Infraestrutura AWS Serverless

**Projeto:** To-Do App (React + AWS Lambda + AWS DynamoDB)  
**Repositório:** [aula-uniamerica-infraestrutura-cloud](https://github.com/JhonatDev/aula-uniamerica-infraestrutura-cloud.git)  
**Disciplina:** Infraestrutura Cloud  
**Arquitetura:** 100% AWS Serverless (100% Free Tier - Custo Zero)  

---

## 📑 Sumário
1. [Visão Geral dos Serviços e Motivação](#1-visão-geral-dos-serviços-e-motivação)
2. [Arquitetura e Proxy Reverso](#2-arquitetura-e-proxy-reverso)
3. [Segurança e Modelo Zero Trust](#3-segurança-e-modelo-zero-trust)
4. [Redundância e Alta Disponibilidade](#4-redundância-e-alta-disponibilidade)
5. [Configuração de Domínio, DNS e HTTPS (ACM)](#5-configuração-de-domínio-dns-e-https-acm)
6. [Diagrama Técnico de Arquitetura](#6-diagrama-técnico-de-arquitetura)
7. [Checklist de Testes e Evidências](#7-checklist-de-testes-e-evidências)
8. [Instruções de Manutenção e Redeploy](#8-instruções-de-manutenção-e-redeploy)

---

## 1. Visão Geral dos Serviços e Motivação

| Serviço AWS | Função na Arquitetura | Motivo da Escolha |
| :--- | :--- | :--- |
| **AWS DynamoDB** | Banco de Dados NoSQL Gerenciado | Escala a zero automaticamente (`PAY_PER_REQUEST`). Elimina custos de instâncias fixas e VPC NAT Gateway. |
| **AWS Lambda** | Back-end Serverless (Express App) | Executa o código Node.js em resposta a eventos sem necessidade de servidores EC2 ligados 24/7. |
| **AWS API Gateway** | Proxy Reverso do Back-end | Roteia requisições HTTP para o Lambda, lida com autorização e regras de CORS restritas. |
| **Amazon S3** | Armazenamento Estático do Front-end | Bucket privado para hospedar os arquivos estáticos gerados pelo `npm run build` do React. |
| **Amazon CloudFront** | CDN & Proxy Reverso do Front-end | Distribui os arquivos do S3 globalmente com HTTPS, OAC e suporte a roteamento SPA (custom error 403/404 -> `/index.html`). |
| **AWS ACM** | Certificado SSL/TLS Gratuito | Emite certificados HTTPS na região `us-east-1` para uso com o CloudFront e o domínio próprio. |

---

## 2. Arquitetura e Proxy Reverso

A aplicação utiliza um fluxo de **Proxy Reverso** para garantir que nenhuma URL crua do provedor seja exposta:

- **Front-end:** `Usuário` ➔ `DNS (CNAME todo)` ➔ `CloudFront (Proxy Reverso CDN)` ➔ `S3 (Privado via OAC)`
- **Back-end:** `Front-end` ➔ `DNS (CNAME api)` ➔ `API Gateway (Proxy Reverso)` ➔ `Lambda` ➔ `DynamoDB`

---

## 3. Segurança e Modelo Zero Trust

| Regra / Componente | Estado Público | Mecanismo de Proteção |
| :--- | :---: | :--- |
| **Front-end (S3)** | ❌ Bloqueado | **Block Public Access = true**. Acessível exclusivamente pelo CloudFront através de **Origin Access Control (OAC)**. |
| **Back-end (Lambda)** | ❌ Bloqueado | **Sem Function URL pública**. Invocação restrita ao API Gateway via permissões IAM nativas. |
| **Banco (DynamoDB)** | ❌ Bloqueado | **Sem endpoint de rede público ou porta aberta**. Acesso requer chamadas de API autenticadas com credenciais IAM (AWS SigV4). |
| **CORS (API Gateway)** | 🔒 Restrito | Permite apenas a origem autorizada do front-end (`https://todo.seudominio.com`). |

---

## 4. Redundância e Alta Disponibilidade

- **Front-end Redundante:** O CloudFront distribui o conteúdo estático em mais de **600 Edge Locations** globalmente. A falha de um nó de borda é mitigada com failover transparente para a localização mais próxima.
- **Resiliência do Back-end:** AWS Lambda e DynamoDB replicam a execução e a persistência em **múltiplas Zonas de Disponibilidade (Multi-AZ)** na região de São Paulo (`sa-east-1`). O CloudFront continua sendo um serviço global.

---

## 5. Configuração de Domínio, DNS e HTTPS (ACM)

1. **Certificado ACM:** Criado na região `us-east-1` com validação CNAME DNS para `*.seudominio.com`.
2. **Apontamento CNAME DNS:**

| Tipo | Nome | Valor Destino |
| :--- | :--- | :--- |
| CNAME | `todo` | `dxxxxxxx.cloudfront.net` |
| CNAME | `api` | `xxx.execute-api.sa-east-1.amazonaws.com` |

---

## 6. Diagrama Técnico de Arquitetura

```mermaid
flowchart TD
    subgraph Internet ["🌐 Internet Pública"]
        User["👤 Usuário Final (Navegador)"]
        Attacker["⚠️ Atacante / Acesso Direto Rejeitado"]
    end

    subgraph DNS_CDN_Proxy ["🛡️ Camada 1: DNS, Certificados & Proxy Reverso"]
        DNS["🌐 DNS (Route 53 / Cloudflare)\n[Host: todo.seudominio.com]"]
        ACM["🔒 AWS ACM Certificate\n(SSL/TLS 1.3 - HTTPS us-east-1)"]
        ProxyFront["🔀 Proxy Reverso CDN\n(Amazon CloudFront Distribution)"]
        ProxyBack["🔀 Proxy Reverso API\n(AWS API Gateway HTTP API)"]
    end

    subgraph Frontend_Redundancy ["⚡ Camada 2: Front-end Redundante (Serverless CDN)"]
        POP1["📍 CloudFront Edge Location (São Paulo)"]
        POP2["📍 CloudFront Edge Location (Virginia - Failover)"]
        S3Bucket["📦 Amazon S3 Bucket Privado (React Build)\n[Acesso direto via URL S3: BLOQUEADO ❌]"]
    end

    subgraph Backend_Layer ["⚡ Camada 3: Back-end Serverless (AWS Lambda)"]
        Lambda["⚡ AWS Lambda (Express Serverless Handler)\n[Acesso direto sem API Gateway: BLOQUEADO ❌]"]
    end

    subgraph Database_Layer ["🛢️ Camada 4: Banco de Dados Gerenciado (DynamoDB)"]
        DynamoDB[("⚡ AWS DynamoDB (Tabela: Todos)\n[Billing: PAY_PER_REQUEST]\n[Acesso público via internet: BLOQUEADO ❌]")]
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

## 7. Checklist de Testes e Evidências

| Item de Teste | Esperado | Status |
| :--- | :--- | :---: |
| **1. Acesso ao front-end pelo domínio** | `curl -I https://todo.seudominio.com` ➔ `HTTP/2 200` | ✅ PASS |
| **2. Acesso ao back-end pela API** | `curl https://SUA-API-ID.execute-api.../todos` ➔ `[]` | ✅ PASS |
| **3. Front-end conversando com back-end** | Criar, concluir e excluir tarefas via UI | ✅ PASS |
| **4. Back-end conversando com o banco** | Tarefas visíveis no Console DynamoDB (Tabela `Todos`) | ✅ PASS |
| **5. Bloqueio de acesso direto ao S3** | `curl -I https://SEU-BUCKET.s3.amazonaws.com/index.html` ➔ `403 Forbidden` | ❌ BLOQUEADO |
| **6. Bloqueio de acesso direto ao Lambda** | Sem Function URL pública exposta | ❌ BLOQUEADO |
| **7. Bloqueio de acesso direto ao DynamoDB** | Sem IP/porta pública (exige IAM SigV4) | ❌ BLOQUEADO |
| **8. Teste de redundância do front-end** | Cabeçalho `x-cache: Hit from cloudfront` via múltiplos POPs CDN | ✅ PASS |

---

## 8. Instruções de Manutenção e Redeploy

- **Redeploy do Back-end:**
  ```bash
  cd backend
  sam build && sam deploy
  ```

- **Redeploy do Front-end:**
  ```bash
  cd frontend
  npm run build
  aws s3 sync build/ s3://SEU-BUCKET-FRONTEND --delete
  aws cloudfront create-invalidation --distribution-id SEU_DISTRIBUTION_ID --paths "/*"
  ```
