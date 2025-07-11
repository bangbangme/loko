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

# --- Load Required Assemblies ---
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

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

# --- Handle RDP Prompts with UI Automation & SendKeys ---
$startTime = Get-Date
$timeout = New-TimeSpan -Seconds 30
$promptsHandled = 0 # Count prompts to avoid loops

Log "Waiting up to $($timeout.TotalSeconds) seconds for RDP prompts..."

while (((Get-Date) - $startTime) -lt $timeout -and $promptsHandled -lt 2) {
    $rootElement = [System.Windows.Automation.AutomationElement]::RootElement
    
    # --- Find the dialog window robustly ---
    $dialogElement = $null
    $frenchTitle = "Connexion Bureau " + [char]0xE0 + " distance" # Build string to avoid encoding issues

    $classCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ClassNameProperty, "#32770"
    )
    $potentialDialogs = $rootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $classCondition)

    foreach($dialog in $potentialDialogs) {
        $name = $dialog.Current.Name
        if ($name -eq "Remote Desktop Connection" -or
            $name -eq "Remote Desktop Connection security warning" -or
            $name -eq $frenchTitle) {
                $dialogElement = $dialog
                break
            }
    }

    if ($dialogElement) {
        $windowName = $dialogElement.Current.Name
        Log "Found RDP dialog: '$windowName'"
        
        # Forcefully bring window to the foreground
        $nativeHwnd = New-Object IntPtr($dialogElement.Current.NativeWindowHandle)
        $Win32Type::SetForegroundWindow($nativeHwnd) | Out-Null
        Start-Sleep -Milliseconds 50 # Reduced for speed

        if ($promptsHandled -eq 0) {
            Log "Handling first prompt..."
            if ($windowName -eq "Remote Desktop Connection security warning") {
                Log "Sending ALT+N to English security warning..."
                [System.Windows.Forms.SendKeys]::SendWait("%n")
                $promptsHandled++
            }
            elseif ($windowName -eq $frenchTitle) {
                Log "Sending ALT+C to French dialog..."
                [System.Windows.Forms.SendKeys]::SendWait("%c")
                $promptsHandled++
            }
        }
        elseif ($promptsHandled -eq 1) {
            Log "Handling second prompt..."
            if ($windowName -eq "Remote Desktop Connection") {
                Log "Sending ALT+Y to English connection dialog..."
                [System.Windows.Forms.SendKeys]::SendWait("%y")
                $promptsHandled++
            }
            elseif ($windowName -eq $frenchTitle) {
                Log "Sending ALT+O to French dialog..."
                [System.Windows.Forms.SendKeys]::SendWait("%o")
                $promptsHandled++
            }
        }
        
        # Use a longer, more reliable delay after the first prompt to allow the second to load
        if ($promptsHandled -eq 1) {
            Log "First prompt handled. Waiting for second prompt to initialize..."
            Start-Sleep -Milliseconds 400
        } else {
            Start-Sleep -Milliseconds 100
        }
        continue
    }

    $mainWindowCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "TscShellContainerClass")
    $mainWindow = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $mainWindowCondition)
    if ($mainWindow) {
        Log "Main RDP window found. Assuming connection is successful."
        break
    }

    Start-Sleep -Milliseconds 50 # Reduced for speed
}

if ($promptsHandled -gt 0) {
    Log "Finished handling RDP prompts."
} else {
    Log "No RDP prompts appeared or handled within the timeout period."
}


# --- Hide all mstsc.exe windows ---
$Win32TypeName = "Win32Enum_$(Get-Random)"
$Win32Type = @(Add-Type -PassThru -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class $Win32TypeName {
        // Win32 API Constants
        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_TOOLWINDOW = 0x80;
        private const int WS_EX_APPWINDOW = 0x40000;
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private const uint SWP_NOZORDER = 0x0004;
        private const uint SWP_NOACTIVATE = 0x0010;
        private static readonly IntPtr HWND_MESSAGE = new IntPtr(-3);

        // Delegate for EnumWindows
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        // P/Invoke Signatures
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")]
        public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        // Helper function to hide the window aggressively
        public static void HideWindowAggressively(IntPtr hwnd)
        {
            // 1. Hide from taskbar
            int exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            SetWindowLong(hwnd, GWL_EXSTYLE, (exStyle | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW);

            // 2. Re-parent to the system's message-only window
            SetParent(hwnd, HWND_MESSAGE);
            
            // 3. Move it way off-screen
            SetWindowPos(hwnd, IntPtr.Zero, -32000, -32000, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

            // 4. Finally, hide it
            ShowWindowAsync(hwnd, 0); // 0 = SW_HIDE
        }
    }
"@)[0]

$mstscId = $proc.Id
$handles = @()

$EnumWindowsProc = $Win32Type.GetNestedType('EnumWindowsProc')
$callback = {
    param($hWnd, $lParam)
    $out = 0
    $Win32Type::GetWindowThreadProcessId($hWnd, [ref]$out) | Out-Null
    if ($out -eq $mstscId) { $script:handles += $hWnd }
    return $true
} -as $EnumWindowsProc

$Win32Type::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

Log "Found $($handles.Count) mstsc windows to hide aggressively."
foreach ($hwnd in $handles) {
    $Win32Type::HideWindowAggressively($hwnd)
}
Log "All mstsc windows have been hidden."

# --- Optional: Remove credentials after use ---
# Start-Sleep -Seconds 5
# cmdkey /delete:TERMSRV/$server
