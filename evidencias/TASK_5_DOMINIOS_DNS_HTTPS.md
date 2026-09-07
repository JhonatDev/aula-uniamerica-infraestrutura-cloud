# Task 5 — Domínios, DNS e certificados HTTPS

Data da validação: 06/09/2026

## Endereços definitivos

- Front-end: `https://todo.jhonatanamigos.site`
- API: `https://api.jhonatanamigos.site`
- Provedor DNS autoritativo: GoDaddy

## Certificados

| Uso | Domínio | Região ACM | Estado |
| --- | --- | --- | --- |
| CloudFront | `todo.jhonatanamigos.site` | `us-east-1` | `ISSUED` |
| API Gateway regional | `api.jhonatanamigos.site` | `sa-east-1` | `ISSUED` |

O certificado do CloudFront precisa permanecer em `us-east-1` porque o serviço é
global. Os buckets S3, o API Gateway, a Lambda e o DynamoDB permanecem em
`sa-east-1` (São Paulo).

## Registros DNS de tráfego

| Tipo | Nome | Destino | TTL |
| --- | --- | --- | --- |
| CNAME | `todo` | `d7f24mswvc1ee.cloudfront.net` | 1 hora |
| CNAME | `api` | `d-u53to2rwpg.execute-api.sa-east-1.amazonaws.com` | 1 hora |

Os CNAMEs adicionais de validação do ACM devem ser preservados para permitir a
renovação automática dos certificados.

## Controles implantados

- Alias e certificado ACM associados à distribuição CloudFront `E3ZD17QF6K5UP`.
- Domínio regional e mapeamento `$default` associados à HTTP API `nlpabqd73c`.
- Front-end compilado com `https://api.jhonatanamigos.site` como URL da API.
- Content Security Policy permite conexão somente com a API definitiva.
- CORS permite `https://todo.jhonatanamigos.site` e o desenvolvimento local.
- Endpoint padrão `execute-api` desativado após a validação do domínio definitivo.

## Resultado dos testes

| Teste | Resultado |
| --- | --- |
| Front-end pelo domínio definitivo | `200 OK` |
| Certificado HTTPS do front-end | PASS |
| Cabeçalhos de segurança e CSP | PASS |
| Failover para o bucket secundário | PASS |
| Acesso direto aos dois buckets | `403 Forbidden` |
| API `/todos` pelo domínio definitivo | `200 OK` |
| Preflight CORS do front-end | `204 No Content` |
| CRUD `GET`, `POST`, `PATCH` e `DELETE` | PASS |
| Endpoint padrão do API Gateway | desativado (`DisableExecuteApiEndpoint = true`) |

As tarefas criadas pelos smoke tests foram removidas ao final das execuções.

A auditoria automatizada finalizou com 38 controles `PASS`, 0 `FAIL`, 2 avisos de
recursos opcionais com custo e 1 verificação manual de MFA já confirmada no console.
