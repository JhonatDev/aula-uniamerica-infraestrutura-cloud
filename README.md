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

## Deploy do back-end

O deploy de desenvolvimento utiliza o perfil AWS `uniamerica-deployer` e a região `us-east-1`:

```powershell
cd backend
sam build
sam deploy
```

Após o deploy, utilize o output `ApiUrl` para testar o CRUD real:

```powershell
.\scripts\smoke-test.ps1 -ApiUrl 'https://ID.execute-api.us-east-1.amazonaws.com'
```

O endpoint `execute-api` é temporário. Ele será desativado depois que o domínio personalizado da API estiver configurado.

## Deploy do front-end redundante

O front-end utiliza CloudFront com dois buckets S3 privados em um grupo de origem com failover. O script gera o build, implanta a infraestrutura, sincroniza os dois buckets e invalida o cache:

```powershell
.\frontend\scripts\deploy.ps1
```

Os outputs do script podem ser usados para validar HTTPS, cabeçalhos de segurança, bloqueio do acesso direto aos buckets e a recuperação de um objeto exclusivo da origem secundária:

```powershell
.\frontend\scripts\smoke-test.ps1 `
  -FrontendUrl 'https://ID.cloudfront.net' `
  -PrimaryBucket 'BUCKET_PRIMARIO' `
  -SecondaryBucket 'BUCKET_SECUNDARIO'
```

O domínio padrão do CloudFront é temporário. Na Task 5 ele será associado ao domínio definitivo e a um certificado ACM.
