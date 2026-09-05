param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^https://')]
  [string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
$baseUrl = $ApiUrl.TrimEnd('/')
$origin = 'http://localhost:3000'
$headers = @{ Origin = $origin }
$createdId = $null

try {
  $listResponse = Invoke-WebRequest -Uri "$baseUrl/todos" -Headers $headers
  if ($listResponse.StatusCode -ne 200) {
    throw "GET /todos retornou $($listResponse.StatusCode)"
  }
  if ($listResponse.Headers['Access-Control-Allow-Origin'] -ne $origin) {
    throw 'A origem esperada não foi retornada no cabeçalho CORS.'
  }

  $createBody = @{ text = "Smoke test $(Get-Date -Format o)" } | ConvertTo-Json
  $created = Invoke-RestMethod -Method Post -Uri "$baseUrl/todos" -Headers $headers -ContentType 'application/json' -Body $createBody
  $createdId = $created.id
  if (-not $createdId -or $created.completed -ne $false) {
    throw 'POST /todos não retornou uma tarefa válida.'
  }

  $updateBody = @{ completed = $true } | ConvertTo-Json
  Invoke-RestMethod -Method Patch -Uri "$baseUrl/todos/$createdId" -Headers $headers -ContentType 'application/json' -Body $updateBody | Out-Null

  Invoke-RestMethod -Method Delete -Uri "$baseUrl/todos/$createdId" -Headers $headers | Out-Null
  $createdId = $null

  [PSCustomObject]@{
    Status = 'PASS'
    ApiUrl = $baseUrl
    Tests = @('GET /todos', 'CORS', 'POST /todos', 'PATCH /todos/{id}', 'DELETE /todos/{id}')
  } | ConvertTo-Json -Depth 3
} finally {
  if ($createdId) {
    try {
      Invoke-RestMethod -Method Delete -Uri "$baseUrl/todos/$createdId" -Headers $headers | Out-Null
    } catch {
      Write-Warning "Não foi possível remover a tarefa temporária $createdId"
    }
  }
}
