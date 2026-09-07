# Documentação curta — infraestrutura serverless

**Projeto:** To-Do App

**Grupo:** Jhonatan & Amigos

**Região principal:** São Paulo (`sa-east-1`)

**Front-end:** <https://todo.jhonatanamigos.site>

**API:** <https://api.jhonatanamigos.site>

## Serviços utilizados e motivos

| Serviço | Uso | Motivo da escolha |
| --- | --- | --- |
| Amazon CloudFront | CDN e proxy reverso do front-end | Entrega global por HTTPS, cache, distribuição de acesso e failover entre origens |
| Amazon S3 | Duas origens privadas do build React | Hospedagem estática serverless, durável e sem servidor exposto |
| Amazon API Gateway HTTP API | Domínio e proxy reverso do back-end | Único ponto público da API, com HTTPS, CORS, limites de taxa e encaminhamento à Lambda |
| AWS Lambda | Execução do back-end Express | Computação serverless sob demanda, sem EC2 ou servidor permanente |
| Amazon DynamoDB | Banco de dados da aplicação | Banco gerenciado/serverless com cobrança sob demanda |
| AWS Certificate Manager | Certificados TLS | HTTPS nos dois domínios com renovação automática enquanto os registros de validação forem preservados |
| Amazon CloudWatch | Logs da API e da função | Evidência, diagnóstico e retenção controlada por 7 dias |
| AWS CloudFormation/SAM | Infraestrutura como código | Implantação reproduzível e auditoria de mudanças |

## Funcionamento e proxy reverso

No front-end, o usuário acessa `todo.jhonatanamigos.site`. A GoDaddy resolve o
registro para o CloudFront, que recebe a conexão HTTPS e encaminha a requisição ao
grupo de origens S3 privadas. Assim, o endereço S3 não é apresentado ao usuário.

No back-end, o React chama `api.jhonatanamigos.site`. O DNS resolve esse nome para
o domínio regional do API Gateway. O API Gateway atua como proxy reverso e invoca
a Lambda; a função usa o AWS SDK para acessar somente a tabela DynamoDB do projeto.
A Lambda não possui Function URL e o endpoint padrão `execute-api` está desativado.

Esta arquitetura não possui um servidor EC2 ligado continuamente. CloudFront, S3,
API Gateway, Lambda e DynamoDB são serviços gerenciados/serverless; a Lambda é
acionada sob demanda quando chega uma requisição à API.

## Segurança

- Todo tráfego público permitido utiliza HTTPS na porta 443.
- Os dois buckets usam Block Public Access, criptografia SSE-S3, versionamento e
  Origin Access Control. Somente a distribuição CloudFront pode ler os objetos.
- O front-end envia uma Content Security Policy que permite conexão apenas com a
  API definitiva, além da própria origem.
- O CORS da API permite `https://todo.jhonatanamigos.site` e o endereço local usado
  no desenvolvimento; não existe origem wildcard.
- O API Gateway limita a taxa padrão a 10 requisições por segundo, com burst 20.
- A Lambda não tem endpoint público próprio e sua role contém somente as quatro
  ações DynamoDB usadas pelo CRUD na tabela do projeto.
- O DynamoDB não aceita acesso anônimo; as operações exigem IAM e assinatura
  SigV4. A criptografia em repouso é mantida pelo serviço.
- A conta root possui MFA por passkey e não possui access keys.

Em resumo, são permitidos apenas os fluxos navegador→CloudFront,
CloudFront→S3, navegador/front-end→API Gateway, API Gateway→Lambda e
Lambda→DynamoDB. Acesso público direto a S3, Lambda e DynamoDB é bloqueado.

## Redundância do front-end

O mesmo build React fica em dois buckets S3 privados, ambos na região de São
Paulo. Eles compõem um grupo de origens do CloudFront. A origem primária é usada
normalmente; para respostas `403`, `404`, `500`, `502`, `503` ou `504`, o
CloudFront tenta automaticamente a origem secundária. Além disso, o próprio
CloudFront distribui as requisições por sua rede global de pontos de presença.

O failover foi comprovado com um arquivo existente somente no bucket secundário:
a requisição feita pelo CloudFront retornou `200` e `secondary-origin-ok`.

## Domínio, DNS e certificados

A zona DNS continua administrada na GoDaddy. Foram configurados:

| Nome | Tipo | Destino |
| --- | --- | --- |
| `todo.jhonatanamigos.site` | CNAME | `d7f24mswvc1ee.cloudfront.net` |
| `api.jhonatanamigos.site` | CNAME | `d-u53to2rwpg.execute-api.sa-east-1.amazonaws.com` |

O certificado do front-end está `ISSUED` no ACM de `us-east-1`, localização
obrigatória para certificados associados ao CloudFront. O certificado da API está
`ISSUED` em `sa-east-1`, a mesma região do API Gateway. Os demais recursos da
aplicação permanecem em São Paulo.

O prefixo `todo` foi escolhido para identificar claramente o front-end e evitar
substituir o site provisório configurado no domínio raiz. O enunciado aceita domínio
ou subdomínio próprio, portanto esse endereço atende ao requisito. O prefixo não
indica branch Git ou ambiente de desenvolvimento.

## Testes e resultado

Os sete testes pedidos no enunciado foram executados:

1. front-end pelo domínio próprio: `PASS` (`200`);
2. API pelo domínio próprio: `PASS` (`200`);
3. front-end acessando o back-end: `PASS`;
4. back-end persistindo no DynamoDB: `PASS`;
5. acesso direto ao back-end bloqueado: `PASS`;
6. acesso direto ao banco sem autenticação bloqueado: `PASS`;
7. failover do front-end para a origem secundária: `PASS`.

A auditoria automatizada registrou 38 controles aprovados, nenhuma falha e dois
avisos opcionais relacionados a serviços que poderiam adicionar custo. Os detalhes,
logs e capturas estão em [`evidencias/`](evidencias/).

O diagrama da arquitetura está em
[`DIAGRAMA_ARQUITETURA.md`](DIAGRAMA_ARQUITETURA.md).

## Implantação e relação com as branches

Não existe pipeline CI/CD neste repositório. Fazer merge de `dev` em `master` não
altera automaticamente a AWS e não troca o ambiente em execução. O ambiente atual
usa os stacks `uniamerica-frontend-dev` e `uniamerica-backend-dev` porque esses
nomes e o parâmetro `EnvironmentName=dev` estão definidos nos scripts de deploy.

A branch `master` será apenas a versão estável do código entregue. Para implantar
outro ambiente denominado `prod`, seria necessário executar um deploy separado com
nomes de stack, parâmetros e domínios próprios. Isso não é necessário para comprovar
os requisitos desta atividade, pois a infraestrutura atual já está funcionando.
