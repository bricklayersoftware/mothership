# https://orgfarm-52fed65bb6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/client_pubnub

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

function Get-Timestamp {
    $ret = Get-Date -Format "HH:mm:ss.fff"
    return $ret
}

class PubNub {
    $PublishKey = "pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66"
    $SubscribeKey = "sub-c-62ba6c3d-b786-4be3-a033-e472ab227774"
    $Channel = "clientid_88992233_JS_client"
    $UUID     = "pscdp.relay.pubnub.ps1"

    $baseUrl  = "ps.pndsn.com"
    
    $msgindex = 0
    $timetoken = 0

    [System.Net.Http.HttpClientHandler]$handler =  $null
    [System.Net.Http.HttpClient]$client = $null

    $isreceive = $false
    $isnewresult = $false
    $response = $null
    $byteArray = $null
    $requestTask = $null

    $pbmessages = [System.Collections.Generic.List[hashtable]]::new()

    [void] Init() {
        $this.handler = [System.Net.Http.HttpClientHandler]::new()
        $this.client  = [System.Net.Http.HttpClient]::new($this.handler)
        $this.client.Timeout = [System.TimeSpan]::FromSeconds(320) 
    }

    [void] Receive() {

        if ( $this.isreceive ) {
            return
        }

        $receiveUrl = $this.GetSubscribeUri()
        $this.requestTask = $this.client.GetAsync($receiveUrl)
        $this.isreceive = $true
    }    

    [string] GetSubscribeUri() {
        if ( [string]::IsNullOrEmpty($this.TimeToken) ) {
            $this.TimeToken = "0"
        }

        $treceiveUrl = "https://$($this.BaseUrl)/v2/subscribe/$($this.SubscribeKey)/$($this.Channel)/0/0?uuid=$($this.UUID)&tt=$($this.TimeToken)"

        return $treceiveUrl
    }

    [string] GetPublishUri() {
        $uri = "https://$($this.BaseUrl)/publish/$($this.PublishKey)/$($this.SubscribeKey)/0/$($this.Channel)/0"
        return $uri
    }

    [string] PublishMessage([hashtable]$payload) {

        if ( ! $null -eq $payload -and $payload -is [hashtable] ) {
            $this.msgindex++
            $payload.Add('timestamp', ( Get-Timestamp ) )
            $payload.Add('msgindex',$this.msgindex)

        } else {
            throw "payload must be a valid hashtable"
        }

        $payloadjson = $payload | ConvertTo-Json -Compress
            
        $uri = $this.GetPublishUri()
    
        $this.response = Invoke-RestMethod -Uri $uri -Method Post -Body $payloadjson -ContentType "application/json; charset=UTF-8"

        if ( $null -ne $this.response -and $this.response.GetType().Name -eq "Object[]" -and $this.response.length -ge 2 ) {
            return $this.response[2]
        }

        return $null
    }
    

    [void] ReadResult() {
        if ( ! $this.isreceive ) {
            return
        }

        if ( ! $this.requestTask.IsCompleted ) {
            return
        }

        $this.isreceive = $false

        if ($this.requestTask.IsFaulted) {
            $msg = $($this.requestTask.Exception.InnerException.Message)
            throw "request task is faulted $msg"
        }

        $this.response = $this.requestTask.Result

        $this.isnewresult = $true

        if ( ! $this.response.IsSuccessStatusCode ) {
            Write-Error "Server returned HTTP status code: $($this.response.StatusCode)"
        }

        Write-Host "Response received! Status: $($this.response.StatusCode). Reading stream into byte array..." -ForegroundColor Green
        
        $contentStreamTask = $this.response.Content.ReadAsStreamAsync()
        
        while (-not $contentStreamTask.IsCompleted) {
            Start-Sleep -Milliseconds 50
        }
        
        $stream = $contentStreamTask.Result
        $memoryStream = [System.IO.MemoryStream]::new()
        
        $stream.CopyTo($memoryStream)
        $this.byteArray = $memoryStream.ToArray()
        
        $memoryStream.Dispose()
        $stream.Dispose()
        $this.response.Dispose()

        Write-Host "Successfully read $($this.byteArray.Length) bytes" -ForegroundColor Yellow        
    }

    [hashtable] static ParseResult([byte[]]$byteArray) {
        $jsonPayload = [System.Text.Encoding]::UTF8.GetString($byteArray)
        Write-Output $jsonPayload

        $tresponse = $null

        try {
            $jsonObj = $jsonPayload | ConvertFrom-Json
            $tresponse = Transform-PSCustomObject $jsonObj
        } catch {

        }

        return $tresponse
    }

    [void] ProcessResponse([hashtable]$response) {
        $this.timetoken = $response.t.t

        Write-Host "timetoken: $($this.timetoken)"

        if ($response.m.Count -le 0) {
            return
        }

        Write-Host "response count: $($response.m.Count)"
        
        foreach ($msg in $response.m) {
            $pbmsg = $msg.d | ConvertTo-Json -Compress
            Write-Host "New Message Received: $($pbmsg | ConvertTo-Json -Compress)"
            $pbmsg = Transform-PSCustomObject($msg.d)
            $this.pbmessages.Add($pbmsg)
        }
    }

    [void] Iterate() {
        Write-Host "starting new iteration..."

        $this.Receive()
        $this.ReadResult()

        if ( ! $this.isnewresult ) {
            return
        }

        $ht = [PubNub]::ParseResult($this.byteArray)
        $this.isnewresult = $false
        $this.byteArray = [byte[]]$null
        
        $this.ProcessResponse($ht)
    }

}

$pb = [PubNub]::new()
$pb.Init()
$pb.Receive()

while ( $true ) {
    $pb.Iterate()

    $pbmsg = @{
        builtincmd="SendBroadcast";
        cmdid=(Get-Random -Minimum 10000000 -Maximum 100000000);
        destination="BROADCAST";
        source="pscdp.relay.pubnub.ps1";
        ts=(Get-Timestamp)
    }
    
    $pb.PublishMessage($pbmsg)

    Start-Sleep -Milliseconds 250
}