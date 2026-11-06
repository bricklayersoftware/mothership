# https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub

$PublishKey = "pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66" # not used when consuming messages
$SubscribeKey = "sub-c-62ba6c3d-b786-4be3-a033-e472ab227774"
$Channel = "clientid_88992233_JS_client"
$UUID     = "powershell_client_" + (New-Guid).Guid.Substring(0,8) # Required uniquely generated ID
$BaseUrl  = "ps.pndsn.com"

function Get-Uri {
    param([string]$TimeToken)

    if ( [string]::IsNullOrEmpty($TimeToken) ) {
        $TimeToken = "0"
    }

    $treceiveUrl = "https://${BaseUrl}/v2/subscribe/${SubscribeKey}/${Channel}/0/0?uuid=${UUID}&tt=${TimeToken}"

    return $treceiveUrl
}

$timetoken = 0

while ($true) {
    Write-Host "new iteration..."

    $receiveUrl = Get-Uri -TimeToken $timetoken

    Write-Host "pinging $receiveUrl"

    # blocks until new message arrives
    $response = Invoke-RestMethod -Uri $receiveUrl -Method Get -TimeoutSec 310

    $timetoken = $response.t.t

    if ($response.m.Count -gt 0) {
        foreach ($msg in $response.m) {
            $json = $msg.d | ConvertTo-Json -Compress
            Write-Host "New Message Received: $($msg.d | ConvertTo-Json -Compress)"
        }
    }

    Write-Host "timetoken: $timetoken"

    Start-Sleep -Milliseconds 1000
}
