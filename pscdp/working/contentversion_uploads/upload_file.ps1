Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# $psEditor.GetEditorContext().CurrentFile.Path   

$cwd = $MyInvocation.MyCommand.Path
$cwd = Split-Path -Path $cwd -Parent

Write-Host "testing [$cwd]"

if ( [string]::IsNullOrWhiteSpace($cwd) ) {

    Write-Host "setting cwd..."

    if (-not $PSScriptRoot) {
        if ($psISE -and $psISE.CurrentFile.Path) {
            $ScriptRoot = Split-Path -Parent $psISE.CurrentFile.Path
        } else {
            $ScriptRoot = $PWD.Path
        }
    } else {
        $ScriptRoot = $PSScriptRoot
    }

    $cwd = Split-Path -Path $ScriptRoot
}

if ( [string]::IsNullOrWhiteSpace($cwd) ) {
    throw 'could not set cwd'
}

Write-Host "testing if [$cwd] is a directory..."

if (Test-Path -Path $cwd -PathType container ) {
    Write-Host "... success"
} else {
    throw "$cwd does not exist"
}

Set-Location -LiteralPath $cwd

$files = @( 
    "client_pubnub.html"
    "client_pubnub.helper.js"
    "client_pubnub.js" 
    "client_pubnub.ui.js"
)

for ( $i = 0; $i -lt $files.Length; $i++ ) {
    $fpath = $files[$i] #"client_pubnub.html"

    # $fpath = Join-Path $cwd $fpath

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

    try {
        $response = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $bytes -UseBasicParsing
        $stringContent = [System.Text.Encoding]::UTF8.GetString($response.Content)
        $stringContent | Out-String
    } catch {
        Write-Error $_
    }
}