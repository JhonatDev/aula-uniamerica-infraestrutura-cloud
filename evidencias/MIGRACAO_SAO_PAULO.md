# Evidências — migração para a região de São Paulo

Data da migração: 06/09/2026

## Estado validado em `sa-east-1`

- Stack `uniamerica-backend-dev`: `CREATE_COMPLETE` e drift `IN_SYNC`.
- API Gateway: `https://nlpabqd73c.execute-api.sa-east-1.amazonaws.com`.
- Teste CRUD da API: `PASS` para GET, POST, PATCH e DELETE.
- Tabela DynamoDB após o teste: vazia.
- Stack `uniamerica-frontend-dev`: `CREATE_COMPLETE` e drift `IN_SYNC`.
- CloudFront global: distribuição `E3ZD17QF6K5UP` em `https://d7f24mswvc1ee.cloudfront.net`.
- Bucket primário em São Paulo: `uniamerica-frontend-dev-primarybucket-gnektgyralct`.
- Bucket secundário em São Paulo: `uniamerica-frontend-dev-secondarybucket-tsma7wlhra5h`.
- Front-end, HTTPS, cabeçalhos de segurança e failover: `PASS`.
- Acesso direto aos dois buckets: bloqueado com `403`.
- CORS da API: restrito à nova distribuição CloudFront e ao desenvolvimento local.

O CloudFront é global. Quando o domínio definitivo for configurado, o certificado ACM usado por ele deverá permanecer em `us-east-1`, conforme requisito do serviço.

## Limpeza concluída

Após a validação manual e a autorização explícita, foram excluídos permanentemente de N. Virginia (`us-east-1`):

- Stack `uniamerica-frontend-dev` e sua distribuição CloudFront antiga.
- Stack `uniamerica-backend-dev`, incluindo API, Lambda, tabela vazia e logs antigos.
- Stack `aws-sam-cli-managed-default` e seu bucket de artefatos antigo.
- 73 versões de objetos e marcadores de exclusão dos três buckets antigos.

Depois da remoção, os três stacks foram confirmados como inexistentes em `us-east-1`. O front-end e a API de São Paulo foram testados novamente e responderam `200`; `/todos` retornou uma lista vazia.
