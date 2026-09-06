param(
  [string]$FrontendUrl = 'https://todo.jhonatanamigos.site',
  [string]$DistributionId = 'E3ZD17QF6K5UP',
  [string]$ApiId = 'nlpabqd73c',
  [string]$ApiUrl = 'https://api.jhonatanamigos.site',
  [string]$FrontendStack = 'uniamerica-frontend-dev',
  [string]$BackendStack = 'uniamerica-backend-dev',
  [string]$FunctionName = 'uniamerica-backend-dev-api',
  [string]$TableName = 'uniamerica-backend-dev-todos',
  [string]$PrimaryBucket = 'uniamerica-frontend-dev-primarybucket-gnektgyralct',
  [string]$SecondaryBucket = 'uniamerica-frontend-dev-secondarybucket-tsma7wlhra5h',
  [string]$Profile = 'uniamerica-deployer',
  [string]$Region = 'sa-east-1'
)

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-AwsJson([string[]]$Arguments) {
  $output = & aws @Arguments --profile $Profile --region $Region --output json
  if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI falhou: aws $($Arguments -join ' ')"
  }
  return ($output | Out-String | ConvertFrom-Json)
}

function Add-Result([string]$Control, [string]$Status, [string]$Detail) {
  $results.Add([PSCustomObject]@{
    Control = $Control
    Status = $Status
    Detail = $Detail
  })
}

$frontendStackState = (Invoke-AwsJson @('cloudformation', 'describe-stacks', '--stack-name', $FrontendStack)).Stacks[0].StackStatus
$backendStackState = (Invoke-AwsJson @('cloudformation', 'describe-stacks', '--stack-name', $BackendStack)).Stacks[0].StackStatus
Add-Result 'CloudFormation front-end' $(if ($frontendStackState -like '*_COMPLETE') { 'PASS' } else { 'FAIL' }) $frontendStackState
Add-Result 'CloudFormation back-end' $(if ($backendStackState -like '*_COMPLETE') { 'PASS' } else { 'FAIL' }) $backendStackState

foreach ($bucket in @($PrimaryBucket, $SecondaryBucket)) {
  $block = (Invoke-AwsJson @('s3api', 'get-public-access-block', '--bucket', $bucket)).PublicAccessBlockConfiguration
  $allBlocked = $block.BlockPublicAcls -and $block.BlockPublicPolicy -and $block.IgnorePublicAcls -and $block.RestrictPublicBuckets
  Add-Result "S3 Block Public Access: $bucket" $(if ($allBlocked) { 'PASS' } else { 'FAIL' }) 'Quatro controles devem estar habilitados.'

  $policyStatus = (Invoke-AwsJson @('s3api', 'get-bucket-policy-status', '--bucket', $bucket)).PolicyStatus.IsPublic
  Add-Result "S3 policy nao publica: $bucket" $(if (-not $policyStatus) { 'PASS' } else { 'FAIL' }) "IsPublic=$policyStatus"

  $policyText = (Invoke-AwsJson @('s3api', 'get-bucket-policy', '--bucket', $bucket)).Policy
  $policy = $policyText | ConvertFrom-Json
  $secureTransportDeny = $policy.Statement | Where-Object {
    $_.Effect -eq 'Deny' -and
    $_.Action -contains 's3:*' -and
    $_.Condition.Bool.'aws:SecureTransport' -eq 'false'
  }
  Add-Result "S3 exige HTTPS: $bucket" $(if ($secureTransportDeny) { 'PASS' } else { 'FAIL' }) 'Deny para aws:SecureTransport=false.'

  $versioning = (Invoke-AwsJson @('s3api', 'get-bucket-versioning', '--bucket', $bucket)).Status
  Add-Result "S3 versionamento: $bucket" $(if ($versioning -eq 'Enabled') { 'PASS' } else { 'FAIL' }) $versioning

  $encryption = (Invoke-AwsJson @('s3api', 'get-bucket-encryption', '--bucket', $bucket)).ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm
  Add-Result "S3 criptografia: $bucket" $(if ($encryption) { 'PASS' } else { 'FAIL' }) $encryption

  $objects = (Invoke-AwsJson @('s3api', 'list-objects-v2', '--bucket', $bucket)).Contents
  $sourceMaps = @($objects | Where-Object Key -like '*.map')
  Add-Result "S3 sem source maps: $bucket" $(if ($sourceMaps.Count -eq 0) { 'PASS' } else { 'FAIL' }) "$($sourceMaps.Count) arquivo(s) .map"
}

$distribution = (Invoke-AwsJson @('cloudfront', 'get-distribution', '--id', $DistributionId)).Distribution
$distributionConfig = $distribution.DistributionConfig
Add-Result 'CloudFront implantado' $(if ($distribution.Status -eq 'Deployed' -and $distributionConfig.Enabled) { 'PASS' } else { 'FAIL' }) "$($distribution.Status), enabled=$($distributionConfig.Enabled)"
Add-Result 'CloudFront duas origens' $(if ($distributionConfig.Origins.Quantity -eq 2 -and $distributionConfig.OriginGroups.Quantity -eq 1) { 'PASS' } else { 'FAIL' }) "origins=$($distributionConfig.Origins.Quantity), groups=$($distributionConfig.OriginGroups.Quantity)"
Add-Result 'CloudFront OAC' $(if (@($distributionConfig.Origins.Items | Where-Object { -not $_.OriginAccessControlId }).Count -eq 0) { 'PASS' } else { 'FAIL' }) 'Todas as origens devem usar OAC.'
Add-Result 'CloudFront redireciona para HTTPS' $(if ($distributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy -eq 'redirect-to-https') { 'PASS' } else { 'FAIL' }) $distributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy
$frontendHost = ([Uri]$FrontendUrl).DnsSafeHost
$distributionAliases = @($distributionConfig.Aliases.Items)
Add-Result 'CloudFront dominio personalizado' $(if ($distributionAliases -contains $frontendHost) { 'PASS' } else { 'FAIL' }) ($distributionAliases -join ', ')
$customViewerCertificate = -not $distributionConfig.ViewerCertificate.CloudFrontDefaultCertificate -and [bool]$distributionConfig.ViewerCertificate.ACMCertificateArn
Add-Result 'CloudFront certificado ACM personalizado' $(if ($customViewerCertificate) { 'PASS' } else { 'FAIL' }) $distributionConfig.ViewerCertificate.ACMCertificateArn

$frontendResponse = Invoke-WebRequest -Uri $FrontendUrl
$headers = $frontendResponse.Headers
foreach ($requiredHeader in @('Content-Security-Policy', 'Strict-Transport-Security', 'X-Content-Type-Options', 'X-Frame-Options', 'Permissions-Policy', 'Cross-Origin-Opener-Policy')) {
  Add-Result "Header $requiredHeader" $(if ($headers[$requiredHeader]) { 'PASS' } else { 'FAIL' }) ([string]$headers[$requiredHeader])
}

$api = Invoke-AwsJson @('apigatewayv2', 'get-api', '--api-id', $ApiId)
$origins = @($api.CorsConfiguration.AllowOrigins)
Add-Result 'API CORS sem wildcard' $(if ($origins -notcontains '*') { 'PASS' } else { 'FAIL' }) ($origins -join ', ')
Add-Result 'API permite o CloudFront' $(if ($origins -contains $FrontendUrl) { 'PASS' } else { 'FAIL' }) ($origins -join ', ')
Add-Result 'API endpoint padrao desabilitado' $(if ($api.DisableExecuteApiEndpoint) { 'PASS' } else { 'FAIL' }) "DisableExecuteApiEndpoint=$($api.DisableExecuteApiEndpoint)"
$apiHost = ([Uri]$ApiUrl).DnsSafeHost
$apiDomain = Invoke-AwsJson @('apigatewayv2', 'get-domain-name', '--domain-name', $apiHost)
$apiMappings = (Invoke-AwsJson @('apigatewayv2', 'get-api-mappings', '--domain-name', $apiHost)).Items
$apiMapped = @($apiMappings | Where-Object ApiId -eq $ApiId).Count -gt 0
Add-Result 'API dominio personalizado' $(if ($apiDomain.DomainName -eq $apiHost -and $apiMapped) { 'PASS' } else { 'FAIL' }) "domain=$($apiDomain.DomainName), mapped=$apiMapped"

$stage = Invoke-AwsJson @('apigatewayv2', 'get-stage', '--api-id', $ApiId, '--stage-name', '$default')
$throttled = $stage.DefaultRouteSettings.ThrottlingRateLimit -gt 0 -and $stage.DefaultRouteSettings.ThrottlingBurstLimit -gt 0
Add-Result 'API throttling' $(if ($throttled) { 'PASS' } else { 'FAIL' }) "rate=$($stage.DefaultRouteSettings.ThrottlingRateLimit), burst=$($stage.DefaultRouteSettings.ThrottlingBurstLimit)"

$null = & aws lambda get-function-url-config --function-name $FunctionName --profile $Profile --region $Region --output json 2>$null
$hasFunctionUrl = $LASTEXITCODE -eq 0
Add-Result 'Lambda sem Function URL' $(if (-not $hasFunctionUrl) { 'PASS' } else { 'FAIL' }) "configured=$hasFunctionUrl"

$function = Invoke-AwsJson @('lambda', 'get-function-configuration', '--function-name', $FunctionName)
$environmentKeys = @($function.Environment.Variables.PSObject.Properties.Name | Sort-Object)
$expectedEnvironmentKeys = @('CORS_ALLOWED_ORIGINS', 'DYNAMODB_TABLE_NAME')
$unexpectedEnvironmentKeys = @(Compare-Object $expectedEnvironmentKeys $environmentKeys)
Add-Result 'Lambda sem segredos no ambiente' $(if ($unexpectedEnvironmentKeys.Count -eq 0) { 'PASS' } else { 'FAIL' }) ($environmentKeys -join ', ')

$roleName = (Invoke-AwsJson @('cloudformation', 'describe-stack-resource', '--stack-name', $BackendStack, '--logical-resource-id', 'TodoApiFunctionRole')).StackResourceDetail.PhysicalResourceId
$inlinePolicyName = (Invoke-AwsJson @('iam', 'list-role-policies', '--role-name', $roleName)).PolicyNames[0]
$rolePolicy = (Invoke-AwsJson @('iam', 'get-role-policy', '--role-name', $roleName, '--policy-name', $inlinePolicyName)).PolicyDocument
$dynamoStatement = $rolePolicy.Statement | Where-Object { $_.Resource -like "*:table/$TableName" }
$expectedDynamoActions = @('dynamodb:DeleteItem', 'dynamodb:PutItem', 'dynamodb:Scan', 'dynamodb:UpdateItem')
$actualDynamoActions = @($dynamoStatement.Action | Sort-Object)
$unexpectedDynamoActions = @(Compare-Object $expectedDynamoActions $actualDynamoActions)
$leastPrivilege = $dynamoStatement.Effect -eq 'Allow' -and $unexpectedDynamoActions.Count -eq 0
Add-Result 'IAM minimo privilegio no DynamoDB' $(if ($leastPrivilege) { 'PASS' } else { 'FAIL' }) ($actualDynamoActions -join ', ')

$attachedPolicies = (Invoke-AwsJson @('iam', 'list-attached-role-policies', '--role-name', $roleName)).AttachedPolicies.PolicyName
$basicExecutionOnly = @($attachedPolicies).Count -eq 1 -and $attachedPolicies -contains 'AWSLambdaBasicExecutionRole'
Add-Result 'IAM Lambda somente logs basicos' $(if ($basicExecutionOnly) { 'PASS' } else { 'FAIL' }) (@($attachedPolicies) -join ', ')

$table = (Invoke-AwsJson @('dynamodb', 'describe-table', '--table-name', $TableName)).Table
Add-Result 'DynamoDB ativo e on-demand' $(if ($table.TableStatus -eq 'ACTIVE' -and $table.BillingModeSummary.BillingMode -eq 'PAY_PER_REQUEST') { 'PASS' } else { 'FAIL' }) "$($table.TableStatus), $($table.BillingModeSummary.BillingMode)"
$backup = (Invoke-AwsJson @('dynamodb', 'describe-continuous-backups', '--table-name', $TableName)).ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus
Add-Result 'DynamoDB recuperacao point-in-time' $(if ($backup -eq 'ENABLED') { 'PASS' } else { 'WARN' }) 'Opcional; possui custo adicional.'

foreach ($logGroup in @('/aws/apigateway/uniamerica-backend-dev', '/aws/lambda/uniamerica-backend-dev-api')) {
  $group = (Invoke-AwsJson @('logs', 'describe-log-groups', '--log-group-name-prefix', $logGroup)).logGroups | Where-Object logGroupName -eq $logGroup
  Add-Result "CloudWatch retencao: $logGroup" $(if ($group.retentionInDays -eq 7) { 'PASS' } else { 'FAIL' }) "$($group.retentionInDays) dias"
}

$analyzers = (Invoke-AwsJson @('accessanalyzer', 'list-analyzers', '--type', 'ACCOUNT')).analyzers
Add-Result 'IAM Access Analyzer' $(if ($analyzers.Count -gt 0) { 'PASS' } else { 'WARN' }) 'Nenhum analyzer de acesso externo encontrado; habilitacao e opcional.'
Add-Result 'MFA da conta root' 'MANUAL' 'A role de deploy nao possui permissao para consultar o resumo global do IAM; verificar no console.'

$failures = @($results | Where-Object Status -eq 'FAIL')
[PSCustomObject]@{
  Status = if ($failures.Count -eq 0) { 'PASS_WITH_WARNINGS' } else { 'FAIL' }
  Passed = @($results | Where-Object Status -eq 'PASS').Count
  Warnings = @($results | Where-Object Status -eq 'WARN').Count
  ManualChecks = @($results | Where-Object Status -eq 'MANUAL').Count
  Failed = $failures.Count
  Results = $results
} | ConvertTo-Json -Depth 6

if ($failures.Count -gt 0) {
  exit 1
}
