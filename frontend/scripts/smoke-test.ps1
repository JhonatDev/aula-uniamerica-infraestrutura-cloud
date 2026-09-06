param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^https://')]
  [string]$FrontendUrl,
  [Parameter(Mandatory = $true)]
  [string]$PrimaryBucket,
  [Parameter(Mandatory = $true)]
  [string]$SecondaryBucket,
  [ValidatePattern('^https://[^/]+$')]
  [string]$ApiUrl = 'https://api.jhonatanamigos.site',
  [string]$Region = 'sa-east-1'
)

$ErrorActionPreference = 'Stop'
$baseUrl = $FrontendUrl.TrimEnd('/')
$response = Invoke-WebRequest -Uri $baseUrl

if ($response.StatusCode -ne 200 -or $response.Content -notmatch '<div id="root"></div>') {
  throw 'O front-end nao retornou o documento React esperado.'
}

$requiredHeaders = @{
  'Content-Security-Policy' = "connect-src 'self' $ApiUrl"
  'Strict-Transport-Security' = 'max-age=31536000'
  'X-Content-Type-Options' = 'nosniff'
  'X-Frame-Options' = 'DENY'
  'Permissions-Policy' = 'camera=(), geolocation=(), microphone=()'
  'Cross-Origin-Opener-Policy' = 'same-origin'
}

foreach ($header in $requiredHeaders.GetEnumerator()) {
  $value = [string]$response.Headers[$header.Key]
  if ($value -notlike "*$($header.Value)*") {
    throw "Cabecalho $($header.Key) ausente ou invalido: $value"
  }
}

$probe = Invoke-WebRequest -Uri "$baseUrl/failover-probe.txt"
if ($probe.StatusCode -ne 200 -or $probe.Content.Trim() -ne 'secondary-origin-ok') {
  throw 'O CloudFront nao recuperou o marcador do bucket secundario.'
}

$directStatuses = @{}
foreach ($bucket in @($PrimaryBucket, $SecondaryBucket)) {
  $directUrl = "https://$bucket.s3.$Region.amazonaws.com/index.html"
  try {
    $directResponse = Invoke-WebRequest -Uri $directUrl
    $directStatuses[$bucket] = $directResponse.StatusCode
  } catch {
    $directStatuses[$bucket] = [int]$_.Exception.Response.StatusCode
  }

  if ($directStatuses[$bucket] -ne 403) {
    throw "O bucket $bucket respondeu diretamente com status $($directStatuses[$bucket])."
  }
}

[PSCustomObject]@{
  Status = 'PASS'
  FrontendStatus = $response.StatusCode
  Https = $baseUrl.StartsWith('https://')
  SecurityHeaders = 'PASS'
  SecondaryOriginFailover = 'PASS'
  DirectBucketAccess = $directStatuses
} | ConvertTo-Json -Depth 3
