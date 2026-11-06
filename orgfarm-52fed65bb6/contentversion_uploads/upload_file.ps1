Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$cwd = Split-Path -Path $psEditor.GetEditorContext().CurrentFile.Path   
Write-Information $cwd

Set-Location -LiteralPath $cwd

$fpath = "client_pubnub.html"
$uri = "https://orgfarm-bd12a2161b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/upload.php?filename=$fpath"

$fpath = Join-Path $cwd $fpath
if ( ! ( Test-Path -Path $fpath ) ) {
    Write-Error "$fpath does not exist"
    exit
}

$bytes = [System.IO.File]::ReadAllBytes($fpath)

$headers = @{
    "Content-Type" = "application/octet-stream"
}

$response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $bytes -UseBasicParsing
$stringContent = [System.Text.Encoding]::UTF8.GetString($response.Content)
$stringContent | Out-String