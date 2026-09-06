# Evidências — Task 6: aplicação e auditoria de segurança

Data da validação: 06/09/2026

Resultado automatizado: `PASS_WITH_WARNINGS`

- Controles aprovados: 34
- Falhas: 0
- Alertas planejados: 3
- Controle manual: concluído (MFA por passkey e 0 access keys da conta root)
- Drift do stack de back-end: `IN_SYNC`
- Drift do stack de front-end: `IN_SYNC`

## Hardening aplicado

- Block Public Access habilitado nos quatro controles dos dois buckets.
- Políticas S3 não públicas e limitadas à distribuição CloudFront.
- Negação explícita de qualquer acesso S3 com `aws:SecureTransport=false`.
- Origin Access Control com assinatura SigV4 nos dois buckets.
- Criptografia SSE-S3 e versionamento habilitados.
- Build de produção sem publicação de source maps.
- CloudFront redirecionando HTTP para HTTPS.
- CSP, HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Permissions-Policy` e `Cross-Origin-Opener-Policy` ativos.
- CORS sem wildcard e limitado a `localhost` e à distribuição CloudFront atual.
- API Gateway com throttling de 10 requisições por segundo e burst de 20.
- Lambda sem Function URL.
- Variáveis de ambiente da Lambda sem credenciais ou segredos.
- Role da Lambda limitada às quatro ações DynamoDB usadas pela aplicação e à tabela do projeto.
- Logs da API e Lambda com retenção de 7 dias.
- Diferença de formato no ARN do log group corrigida para eliminar falso drift.

## Alertas aceitos temporariamente

1. O endpoint padrão `execute-api` permanece habilitado até a configuração do domínio personalizado na Task 5.
2. A recuperação point-in-time do DynamoDB está desabilitada porque é opcional e adiciona custo.
3. O IAM Access Analyzer da conta não está habilitado; é uma melhoria opcional de governança.

WAF, Security Hub e AWS Config não foram ativados para evitar serviços pagos desnecessários para esta atividade acadêmica.

## Verificações manuais

No console AWS:

- [x] MFA da conta root habilitado com passkey, confirmado no console em 06/09/2026.
- [x] Conta root sem access keys, confirmado no console em 06/09/2026 e registrado em `screenshots/task-6-root-zero-access-keys.png`.

A role de deploy não recebeu permissão global de IAM apenas para produzir essa evidência. Isso preserva o princípio de mínimo privilégio.

Após a entrega, a access key temporária do usuário `uniamerica-cli` deve ser desativada e excluída.

## Como repetir

```powershell
.\scripts\audit-security.ps1
```

O resultado esperado antes da Task 5 é `PASS_WITH_WARNINGS`, sem controles `FAIL`.
