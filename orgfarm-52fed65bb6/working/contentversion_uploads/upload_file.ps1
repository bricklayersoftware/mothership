Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

$cwd = Split-Path -Path $psEditor.GetEditorContext().CurrentFile.Path   
Write-Information $cwd

Set-Location -LiteralPath $cwd

$files = @( 
    "client_pubnub.html"
    "client_pubnub.helper.js"
    "client_pubnub.js" 
)

for ( $i = 0; $i -lt $files.Length; $i++ ) {
    $fpath = $files[$i] #"client_pubnub.html"

    Write-Host "uploading $fpath"

    if ( ! ( Test-Path -Path $fpath -PathType Leaf ) ) {
        throw "$fpath does not exist"
    }

    $uri = "https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/upload.php?filename=$fpath"

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
}