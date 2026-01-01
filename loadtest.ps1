param(
  [int]$BookId = 1,
  [int]$Requests = 50
)

# Ports des 3 instances book-service
$Ports = @(8081, 8083, 8084)

Write-Host "== Load test =="
Write-Host "BookId=$BookId Requests=$Requests"
Write-Host "Ports=$($Ports -join ',')"
Write-Host ""

$jobs = @()

for ($i = 1; $i -le $Requests; $i++) {

  $port = $Ports[$i % $Ports.Count]
  $url  = "http://localhost:$port/api/books/$BookId/borrow"

  $jobs += Start-Job -ScriptBlock {
    param($Url, $Port)

    try {
      $response = Invoke-WebRequest -Uri $Url -Method POST -UseBasicParsing
      [PSCustomObject]@{
        Port   = $Port
        Status = $response.StatusCode
        Body   = $response.Content
      }
    }
    catch {
      if ($_.Exception.Response) {
        $status = $_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body   = $reader.ReadToEnd()

        [PSCustomObject]@{
          Port   = $Port
          Status = $status
          Body   = $body
        }
      }
      else {
        [PSCustomObject]@{
          Port   = $Port
          Status = -1
          Body   = $_.Exception.Message
        }
      }
    }

  } -ArgumentList $url, $port
}

# Récupération des résultats
$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

# Statistiques
$success  = ($results | Where-Object { $_.Status -eq 200 }).Count
$conflict = ($results | Where-Object { $_.Status -eq 409 }).Count
$other    = $Requests - $success - $conflict

Write-Host "== Résultats =="
Write-Host "Success (200):  $success"
Write-Host "Conflict (409): $conflict"
Write-Host "Other:          $other"
