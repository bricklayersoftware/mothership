# https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/StorageVault/client_pubnub

$PublishKey = "pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66" # not used when consuming messages
$SubscribeKey = "sub-c-62ba6c3d-b786-4be3-a033-e472ab227774"
$Channel = "clientid_88992233_JS_client"
$UUID     = "powershell_client_" + (New-Guid).Guid.Substring(0,8) # Required uniquely generated ID
$BaseUrl  = "ps.pndsn.com"

function Transform-PSCustomObject($obj) {
    $ht = @{}

    try {
        $obj.psobject.Properties | ForEach-Object {
            $ht[$_.Name] = $_.Value
        }
    } catch {
        $ht = $null
    }
    
    return $ht;
}

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

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client  = [System.Net.Http.HttpClient]::new($handler)

    # PubNub server hold is max 310s. Set client timeout higher (e.g., 320 seconds)
    $client.Timeout = [System.TimeSpan]::FromSeconds(320) 
    $requestTask = $client.GetAsync($receiveUrl)

    while (-not $requestTask.IsCompleted) {
        Write-Host "." -NoNewline
        Start-Sleep -Milliseconds 250
    }

    Write-Host "" # New line

    if ($requestTask.IsFaulted) {
        Write-Error "Request encountered an unhandled exception: $($requestTask.Exception.InnerException.Message)"
        $client.Dispose()
        exit
    }

    # 4. Extract the HttpResponseMessage Result
    $response = $requestTask.Result

    if ($response.IsSuccessStatusCode) {
        Write-Host "Response received! Status: $($response.StatusCode). Reading stream into byte array..." -ForegroundColor Green
        
        # 5. Retrieve content stream asynchronously to read into raw bytes
        $contentStreamTask = $response.Content.ReadAsStreamAsync()
        
        while (-not $contentStreamTask.IsCompleted) {
            Start-Sleep -Milliseconds 50
        }
        
        $stream = $contentStreamTask.Result
        $memoryStream = [System.IO.MemoryStream]::new()
        
        # Stream bytes out safely 
        $stream.CopyTo($memoryStream)
        [byte[]]$byteArray = $memoryStream.ToArray()
        
        # Clean up stream objects
        $memoryStream.Dispose()
        $stream.Dispose()

        # Output verification
        Write-Host "Successfully read ($($byteArray.Length) bytes) into `$byteArray." -ForegroundColor Yellow
        
        $jsonPayload = [System.Text.Encoding]::UTF8.GetString($byteArray)
        Write-Output $jsonPayload

        try {
            $jsonObj = $jsonPayload | ConvertFrom-Json
            $response = Transform-PSCustomObject $jsonObj
        } catch {

        }
        
    } else {
        Write-Error "Server returned HTTP status code: $($response.StatusCode)"
    }

    $client.Dispose()

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
