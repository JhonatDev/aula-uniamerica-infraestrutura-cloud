# Entrega — Jhonatan & Amigos

Esta página reúne somente os três itens solicitados no enunciado.

## 1. Infraestrutura funcionando

- Aplicação: <https://todo.jhonatanamigos.site>
- API: <https://api.jhonatanamigos.site/todos>
- Provedor: AWS
- Região principal: São Paulo (`sa-east-1`)
- Arquitetura: CloudFront + dois buckets S3 privados + API Gateway + Lambda +
  DynamoDB

Validação final em 07/09/2026: front-end e API responderam `HTTP 200`; os stacks
`uniamerica-frontend-dev` e `uniamerica-backend-dev` estavam em
`UPDATE_COMPLETE`, e a função Lambda estava `Active` com a última atualização
concluída com sucesso.

## 2. Diagrama

[Abrir o diagrama técnico da arquitetura](DIAGRAMA_ARQUITETURA.md)

O diagrama mostra domínio, DNS, proxy reverso, front-end, redundância, back-end,
banco, certificados, portas, protocolos e fluxos permitidos/bloqueados.

## 3. Documentação curta

[Abrir a documentação da infraestrutura](DOCUMENTACAO_INFRAESTRUTURA.md)

A documentação explica os serviços escolhidos, segurança, redundância, proxy
reverso, DNS/domínios e regras de acesso.

## Material comprobatório

Os testes, logs e capturas que sustentam os três itens estão disponíveis em
[`evidencias/`](evidencias/). O resumo final dos sete testes obrigatórios está em
[`evidencias/TASK_7_TESTES_E_EVIDENCIAS.md`](evidencias/TASK_7_TESTES_E_EVIDENCIAS.md).
