# To-Do App — infraestrutura cloud

Aplicação React e Express utilizada como base para uma arquitetura serverless na AWS.

## Ambientes

- **Produção:** front-end estático, AWS Lambda, API Gateway e DynamoDB. A infraestrutura cloud será declarada e implantada nas próximas etapas do projeto.
- **Desenvolvimento:** o front-end usa `REACT_APP_API_URL` para localizar a API. Copie `frontend/.env.example` para `frontend/.env` quando precisar alterar a URL local.
- **Docker legado:** os arquivos Docker/MongoDB existentes pertencem à versão anterior da aplicação. Eles não representam a arquitetura de produção atual, que utiliza DynamoDB.

## Validação local

```powershell
cd backend
npm ci
npm test
npm run check

cd ..\frontend
npm ci
$env:CI = 'true'
npm test -- --watchAll=false
npm run build
```

O template serverless pode ser validado com:

```powershell
sam validate --lint --template-file backend/template.yaml
```
