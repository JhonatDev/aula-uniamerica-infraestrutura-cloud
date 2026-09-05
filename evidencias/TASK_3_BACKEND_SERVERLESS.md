# Evidências — Task 3: back-end serverless

Data da validação: 04/09/2026

Região: `us-east-1`

Stack: `uniamerica-backend-dev`

## Recursos implantados

- CloudFormation: `UPDATE_COMPLETE` após a criação e o ajuste de logs, com 8 recursos gerenciados pelo stack.
- API Gateway HTTP API: `uniamerica-backend-dev-http-api`.
- Lambda: `uniamerica-backend-dev-api`, Node.js 24, 128 MB e timeout de 10 segundos.
- DynamoDB: `uniamerica-backend-dev-todos`, estado `ACTIVE` e cobrança `PAY_PER_REQUEST`.
- CloudWatch: logs da API e da Lambda com retenção de 7 dias.

URL temporária da API:

`https://qsobfeveei.execute-api.us-east-1.amazonaws.com`

O endpoint padrão do API Gateway permanece habilitado somente enquanto o domínio está pendente. Na Task 5 ele deverá ser substituído pelo domínio personalizado e desabilitado.

## Validações realizadas

- `GET /todos`: passou.
- `POST /todos`: passou.
- `PATCH /todos/{id}`: passou.
- `DELETE /todos/{id}`: passou.
- CORS para `http://localhost:3000`: passou.
- Origem não autorizada: não recebeu `Access-Control-Allow-Origin`.
- Tabela após o teste: 0 itens; a tarefa temporária foi removida.
- URL própria da função Lambda: não configurada.
- Logs de acesso da API: stream criado.
- Logs de execução da Lambda: stream criado.

Resultado do smoke test: `PASS`.

## Controles aplicados

- A Lambda acessa somente a tabela criada pelo stack.
- A role permite apenas `Scan`, `PutItem`, `UpdateItem` e `DeleteItem` nessa tabela.
- A API limita a taxa padrão a 10 requisições por segundo, com burst de 20.
- O DynamoDB usa criptografia em repouso gerenciada pela AWS por padrão.
- Os recursos possuem tags de projeto e ambiente.

## Como repetir

```powershell
cd backend
sam build
sam deploy
.\scripts\smoke-test.ps1 -ApiUrl 'https://qsobfeveei.execute-api.us-east-1.amazonaws.com'
```
