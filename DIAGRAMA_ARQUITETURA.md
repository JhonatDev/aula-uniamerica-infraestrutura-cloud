# Diagrama técnico — To-Do App serverless

Arquitetura efetivamente implantada na AWS. Os recursos regionais ficam em São
Paulo (`sa-east-1`); o CloudFront é global e, por exigência desse serviço, seu
certificado ACM fica em N. Virginia (`us-east-1`).

```mermaid
flowchart LR
    U["Usuário<br/>navegador"]
    NET(("Internet"))

    subgraph DNS["DNS autoritativo — GoDaddy"]
        DT["todo.jhonatanamigos.site<br/>CNAME"]
        DA["api.jhonatanamigos.site<br/>CNAME"]
    end

    subgraph GLOBAL["AWS Global"]
        CF["Amazon CloudFront<br/>proxy reverso/CDN<br/>HTTPS 443 — TLS >= 1.2"]
        ACMCF["ACM us-east-1<br/>certificado do front-end"]
    end

    subgraph SP["AWS São Paulo — sa-east-1"]
        subgraph ORIGINS["Front-end serverless redundante"]
            OG["CloudFront Origin Group<br/>failover automático"]
            S3A["S3 privado<br/>origem primária"]
            S3B["S3 privado<br/>origem secundária"]
        end

        APIGW["API Gateway HTTP API<br/>proxy reverso da API<br/>HTTPS 443 — TLS 1.2"]
        ACMAPI["ACM sa-east-1<br/>certificado da API"]
        LAMBDA["AWS Lambda<br/>back-end Express serverless"]
        DDB[("Amazon DynamoDB<br/>tabela Todos<br/>PAY_PER_REQUEST")]
    end

    U -->|"HTTPS 443"| NET
    NET --> DT
    DT -->|"resolve para CloudFront"| CF
    ACMCF -.->|"certificado"| CF
    CF -->|"OAC + SigV4 / HTTPS"| OG
    OG -->|"1ª tentativa"| S3A
    OG -.->|"failover 403/404/5xx"| S3B

    U -->|"aplicação React chama HTTPS 443"| DA
    DA -->|"resolve para domínio regional"| APIGW
    ACMAPI -.->|"certificado"| APIGW
    APIGW -->|"invocação autorizada pelo serviço"| LAMBDA
    LAMBDA -->|"AWS SDK + IAM SigV4 / HTTPS 443"| DDB

    X1["Internet"] -.->|"BLOQUEADO: sem acesso público"| S3A
    X1 -.->|"BLOQUEADO: sem acesso público"| S3B
    X1 -.->|"BLOQUEADO: sem Function URL"| LAMBDA
    X1 -.->|"BLOQUEADO: exige IAM/SigV4"| DDB
    X1 -.->|"BLOQUEADO: endpoint padrão desativado"| APIGW

    classDef public fill:#dbeafe,stroke:#2563eb,color:#111827;
    classDef compute fill:#ffedd5,stroke:#ea580c,color:#111827;
    classDef data fill:#dcfce7,stroke:#16a34a,color:#111827;
    classDef security fill:#f3e8ff,stroke:#9333ea,color:#111827;
    classDef blocked fill:#fee2e2,stroke:#dc2626,color:#111827;
    class U,NET,DT,DA,CF,APIGW public;
    class OG,S3A,S3B,LAMBDA compute;
    class DDB data;
    class ACMCF,ACMAPI security;
    class X1 blocked;
```

## Portas, protocolos e controles

| Origem | Destino | Porta/protocolo | Decisão | Controle aplicado |
| --- | --- | --- | --- | --- |
| Navegador | CloudFront | TCP 443 / HTTPS | Permitido | Certificado ACM, redirecionamento HTTP→HTTPS, TLS mínimo 1.2 e cabeçalhos de segurança |
| CloudFront | S3 primário/secundário | HTTPS / SigV4 | Permitido | Origin Access Control (OAC) limitado à distribuição |
| Navegador/front-end | API Gateway | TCP 443 / HTTPS | Permitido | Domínio próprio, CORS restrito e throttling |
| API Gateway | Lambda | Invocação de serviço AWS | Permitido | Permissão IAM específica; sem acesso direto à função |
| Lambda | DynamoDB | TCP 443 / API AWS SigV4 | Permitido | Role de mínimo privilégio limitada à tabela do projeto |
| Internet | Buckets S3 | HTTP/HTTPS direto | Bloqueado | S3 Block Public Access e política que exige transporte seguro |
| Internet | Lambda | Acesso direto | Bloqueado | Function URL inexistente |
| Internet | DynamoDB | Requisição não autenticada | Bloqueado | Serviço exige credenciais IAM e assinatura SigV4 |
| Internet | Endpoint padrão da API | HTTPS | Bloqueado | `DisableExecuteApiEndpoint = true` |

## Redundância implementada

O build React é publicado em dois buckets S3 privados. O CloudFront usa um
`Origin Group`: consulta primeiro o bucket primário e muda automaticamente para o
secundário quando recebe `403`, `404`, `500`, `502`, `503` ou `504`. O teste com
`failover-probe.txt`, presente apenas no bucket secundário, confirmou o caminho de
failover.
