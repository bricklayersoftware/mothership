$scriptPath = ( Join-Path $PSScriptRoot "pscdp.relay.ps1" )
$base64String = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($scriptPath))
$base64String | Out-File ( Join-Path $PSScriptRoot "pscdp.relay.ps1.base64" )

$fileText = Get-Content -Path ( Join-Path $PSScriptRoot "pscdp.relay.ps1.base64" ) -Raw

$scriptText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($fileText))
$stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($scriptText))

(Get-FileHash -InputStream $stream -Algorithm MD5).Hash | Write-Host

$scriptBlock = [scriptblock]::Create($scriptText)

& $scriptBlock