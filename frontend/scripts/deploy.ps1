param(
  [ValidatePattern('^https://[^/]+$')]
  [string]$ApiUrl = 'https://nlpabqd73c.execute-api.sa-east-1.amazonaws.com',
  [string]$StackName = 'uniamerica-frontend-dev',
  [string]$Region = 'sa-east-1',
  [string]$Profile = 'uniamerica-deployer'
)

$ErrorActionPreference = 'Stop'
$frontendDir = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $frontendDir 'template.yaml'
$buildDir = Join-Path $frontendDir 'build'
$probePath = Join-Path $frontendDir 'failover-probe.txt'
$previousApiUrl = $env:REACT_APP_API_URL
$previousSourceMap = $env:GENERATE_SOURCEMAP

function Assert-LastCommand([string]$Message) {
  if ($LASTEXITCODE -ne 0) {
    throw $Message
  }
}

function Get-StackOutput($Stack, [string]$Key) {
  return ($Stack.Outputs | Where-Object OutputKey -eq $Key).OutputValue
}

try {
  Push-Location $frontendDir
  $env:REACT_APP_API_URL = $ApiUrl
  $env:GENERATE_SOURCEMAP = 'false'
  npm ci
  Assert-LastCommand 'Falha ao instalar as dependencias do front-end.'
  npm run build
  Assert-LastCommand 'Falha ao gerar o build de producao do front-end.'
} finally {
  Pop-Location
  if ($null -eq $previousApiUrl) {
    Remove-Item Env:REACT_APP_API_URL -ErrorAction SilentlyContinue
  } else {
    $env:REACT_APP_API_URL = $previousApiUrl
  }
  if ($null -eq $previousSourceMap) {
    Remove-Item Env:GENERATE_SOURCEMAP -ErrorAction SilentlyContinue
  } else {
    $env:GENERATE_SOURCEMAP = $previousSourceMap
  }
}

aws cloudformation deploy `
  --template-file $templatePath `
  --stack-name $StackName `
  --parameter-overrides "EnvironmentName=dev" "ApiOrigin=$ApiUrl" `
  --tags "Project=uniamerica" "Environment=dev" `
  --no-fail-on-empty-changeset `
  --profile $Profile `
  --region $Region
Assert-LastCommand 'Falha ao implantar a infraestrutura do front-end.'

$stack = aws cloudformation describe-stacks `
  --stack-name $StackName `
  --profile $Profile `
  --region $Region `
  --output json | ConvertFrom-Json
Assert-LastCommand 'Falha ao consultar os outputs do stack do front-end.'

$stack = $stack.Stacks[0]
$distributionId = Get-StackOutput $stack 'DistributionId'
$frontendUrl = Get-StackOutput $stack 'FrontendUrl'
$primaryBucket = Get-StackOutput $stack 'PrimaryBucketName'
$secondaryBucket = Get-StackOutput $stack 'SecondaryBucketName'

foreach ($bucket in @($primaryBucket, $secondaryBucket)) {
  aws s3 sync $buildDir "s3://$bucket" `
    --delete `
    --cache-control 'public,max-age=300' `
    --profile $Profile `
    --region $Region
  Assert-LastCommand "Falha ao sincronizar o build com $bucket."

  aws s3 cp (Join-Path $buildDir 'index.html') "s3://$bucket/index.html" `
    --cache-control 'no-cache,no-store,must-revalidate' `
    --content-type 'text/html' `
    --profile $Profile `
    --region $Region
  Assert-LastCommand "Falha ao atualizar o index.html em $bucket."
}

aws s3 rm "s3://$primaryBucket/failover-probe.txt" `
  --profile $Profile `
  --region $Region | Out-Null

aws s3 cp $probePath "s3://$secondaryBucket/failover-probe.txt" `
  --cache-control 'no-cache,no-store,must-revalidate' `
  --content-type 'text/plain' `
  --profile $Profile `
  --region $Region
Assert-LastCommand 'Falha ao publicar o marcador de failover no bucket secundario.'

$invalidation = aws cloudfront create-invalidation `
  --distribution-id $distributionId `
  --paths '/*' `
  --profile $Profile `
  --output json | ConvertFrom-Json
Assert-LastCommand 'Falha ao criar a invalidacao do CloudFront.'

aws cloudfront wait invalidation-completed `
  --distribution-id $distributionId `
  --id $invalidation.Invalidation.Id `
  --profile $Profile
Assert-LastCommand 'A invalidacao do CloudFront nao foi concluida.'

[PSCustomObject]@{
  Status = 'DEPLOYED'
  FrontendUrl = $frontendUrl
  DistributionId = $distributionId
  PrimaryBucket = $primaryBucket
  SecondaryBucket = $secondaryBucket
  ApiUrl = $ApiUrl
} | ConvertTo-Json
