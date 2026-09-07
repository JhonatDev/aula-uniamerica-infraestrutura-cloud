# Evidências — Task 7: testes de funcionamento e segurança

Data da execução final: 06/09/2026

Região dos recursos: São Paulo (`sa-east-1`), com CloudFront global e certificado
do CloudFront no ACM de `us-east-1` por exigência do serviço.

## Endereços testados

- Front-end: `https://todo.jhonatanamigos.site`
- API: `https://api.jhonatanamigos.site`

## Resultado por requisito da atividade

| # | Requisito | Estado | Evidência |
| --- | --- | --- | --- |
| 1 | Front-end acessível pelo domínio | `PASS` | HTTPS retornou `200` e o documento React esperado. |
| 2 | Back-end acessível pelo domínio/API | `PASS` | `GET /todos` retornou `200` pelo domínio definitivo. |
| 3 | Front-end acessa o back-end | `PASS` | A tarefa `Evidência Task 7 - integração OK`, criada na interface, apareceu no retorno da API. |
| 4 | Back-end acessa o banco | `PASS` | CRUD completo criou, atualizou e removeu tarefas no DynamoDB. |
| 5 | Acesso direto ao back-end bloqueado | `PASS` | Lambda sem Function URL e endpoint padrão `execute-api` desativado. |
| 6 | Acesso direto ao banco bloqueado | `PASS` | Requisição DynamoDB sem assinatura foi rejeitada por ausência de autenticação. |
| 7 | Redundância do front-end | `PASS` | CloudFront recuperou `failover-probe.txt` da origem secundária quando ausente na primária. |

## Testes automatizados executados

### API, CORS e persistência

O script `backend/scripts/smoke-test.ps1`, executado contra
`https://api.jhonatanamigos.site`, retornou `PASS` para:

- `GET /todos`;
- CORS;
- `POST /todos`;
- `PATCH /todos/{id}`;
- `DELETE /todos/{id}`.

As tarefas temporárias foram removidas ao final dos testes.

O preflight CORS originado em `https://todo.jhonatanamigos.site` retornou `204`
e autorizou somente os métodos `DELETE`, `GET`, `OPTIONS`, `PATCH` e `POST`.
A configuração não utiliza origem wildcard.

### Front-end, HTTPS, segurança e redundância

O script `frontend/scripts/smoke-test.ps1` retornou:

- documento React: `200`;
- HTTPS: `true`;
- cabeçalhos de segurança: `PASS`;
- failover para origem secundária: `PASS`;
- acesso direto ao bucket primário: `403`;
- acesso direto ao bucket secundário: `403`.

A Content Security Policy autoriza conexões somente com
`https://api.jhonatanamigos.site`, além da própria origem.

### Domínio e certificados

| Domínio | Destino DNS | Certificado |
| --- | --- | --- |
| `todo.jhonatanamigos.site` | `d7f24mswvc1ee.cloudfront.net` | `ISSUED` em `us-east-1` |
| `api.jhonatanamigos.site` | `d-u53to2rwpg.execute-api.sa-east-1.amazonaws.com` | `ISSUED` em `sa-east-1` |

Os registros DNS foram consultados publicamente e nos servidores autoritativos da
GoDaddy.

### Bloqueios de acesso direto

- A API Gateway possui `DisableExecuteApiEndpoint = true`; o endereço padrão
  `execute-api` não entrega mais as rotas da aplicação.
- A consulta `get-function-url-config` da Lambda retornou
  `ResourceNotFoundException`, confirmando que não existe Function URL.
- Uma tentativa de `dynamodb scan --no-sign-request` retornou
  `MissingAuthenticationTokenException`.
- A role da Lambda tem somente `Scan`, `PutItem`, `UpdateItem` e `DeleteItem` na
  tabela do projeto, além da política básica de logs.
- Os dois buckets S3 estão privados e rejeitam acesso direto com `403`.

### Consistência e observabilidade

- Auditoria automatizada: `PASS_WITH_WARNINGS`.
- Controles aprovados: `38`.
- Falhas: `0`.
- Avisos opcionais: `2` — recuperação point-in-time e IAM Access Analyzer.
- Verificação manual: `1` — MFA da conta root, confirmado no console.
- Stack do back-end: `IN_SYNC`, com `0` recursos divergentes.
- Stack do front-end: `IN_SYNC`, com `0` recursos divergentes.
- Streams recentes encontrados nos log groups da API Gateway e da Lambda.

## Capturas finais

- [Tarefa criada no front-end pelo domínio definitivo](screenshots/task-7-frontend-integracao-final.png)
- [Tarefa criada pelo front aparecendo na API definitiva](screenshots/task-7-api-dominio-final.png)

A segunda captura foi realizada antes da limpeza para demonstrar o fluxo
front-end → API Gateway → Lambda → DynamoDB. A tarefa exibida foi removida logo
após a captura.

## Como repetir os testes

```powershell
.\backend\scripts\smoke-test.ps1 `
  -ApiUrl 'https://api.jhonatanamigos.site'

.\frontend\scripts\smoke-test.ps1 `
  -FrontendUrl 'https://todo.jhonatanamigos.site' `
  -ApiUrl 'https://api.jhonatanamigos.site' `
  -PrimaryBucket 'uniamerica-frontend-dev-primarybucket-gnektgyralct' `
  -SecondaryBucket 'uniamerica-frontend-dev-secondarybucket-tsma7wlhra5h'

.\scripts\audit-security.ps1
```

## Conclusão

Os sete testes obrigatórios da atividade foram concluídos com sucesso. A aplicação
está disponível exclusivamente pelos domínios definitivos, os acessos diretos aos
componentes privados estão bloqueados e o mecanismo de redundância do front-end foi
validado.
