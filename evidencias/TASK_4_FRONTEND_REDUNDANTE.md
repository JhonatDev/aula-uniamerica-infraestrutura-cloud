# Evidências — Task 4: front-end serverless redundante

Data da validação: 05/09/2026

Região do stack: `us-east-1`

Stack: `uniamerica-frontend-dev`

## Recursos implantados

- CloudFront: distribuição `E2PJ9V9PC81U9J`, estado `Deployed`.
- URL temporária: `https://dnup1s3c9bqg8.cloudfront.net`.
- Origem primária: `uniamerica-frontend-dev-primarybucket-yr3uevmgy1fr`.
- Origem secundária: `uniamerica-frontend-dev-secondarybucket-gxcwsmznvxvx`.
- Origin Access Control com assinatura SigV4 obrigatória.
- Cache policy e response headers policy próprias do stack.

## Redundância

- Duas origens S3 configuradas em um origin group do CloudFront.
- Origem primária consultada primeiro e secundária usada automaticamente no failover.
- Failover configurado para os códigos `403`, `404`, `500`, `502`, `503` e `504`.
- O arquivo `failover-probe.txt` existe somente na origem secundária.
- A recuperação desse arquivo pelo domínio CloudFront retornou `200` e `secondary-origin-ok`.

Resultado do teste de failover: `PASS`.

## Segurança e integração

- Acesso ao front-end somente por HTTPS, com redirecionamento de HTTP.
- Buckets com Block Public Access integralmente habilitado.
- Acesso direto ao `index.html` dos dois buckets retornou `403`.
- Objetos criptografados em repouso com SSE-S3 (`AES256`).
- Versionamento habilitado nos dois buckets.
- Cabeçalhos CSP, HSTS, `X-Content-Type-Options` e `X-Frame-Options` validados.
- Bundle React contém a URL HTTPS da API implantada.
- API autoriza especificamente `localhost` e a origem CloudFront; não utiliza wildcard.
- Preflight CORS para `POST` a partir do CloudFront retornou `204` com origem, métodos e cabeçalhos esperados.

Resultado do smoke test: `PASS`.

## Como repetir

```powershell
.\frontend\scripts\deploy.ps1

.\frontend\scripts\smoke-test.ps1 `
  -FrontendUrl 'https://dnup1s3c9bqg8.cloudfront.net' `
  -PrimaryBucket 'uniamerica-frontend-dev-primarybucket-yr3uevmgy1fr' `
  -SecondaryBucket 'uniamerica-frontend-dev-secondarybucket-gxcwsmznvxvx'
```

O domínio `cloudfront.net` é temporário. A Task 5 deverá associar o domínio definitivo, instalar o certificado ACM e atualizar o CORS/CSP.
