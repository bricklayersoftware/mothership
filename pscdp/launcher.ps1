Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@

# Find handle by matching PID
$targetPid = $PID
$hwnd = [Win32]::GetForegroundWindow()
$hwnd | Write-Host

# Make PowerShell Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$asyncwindow | ConvertTo-Json | Write-Host
$ret = $asyncwindow::ShowWindowAsync($hwnd, 0)
$ret | ConvertTo-Json | Write-Host

while ($true) {
    Write-Host "Checking status at $(Get-Date)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
