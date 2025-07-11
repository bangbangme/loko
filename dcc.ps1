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
        
        $dialogElement.SetFocus()
        Start-Sleep -Milliseconds 250

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
        
        Start-Sleep -Milliseconds 1000
        continue
    }

    $mainWindowCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "TscShellContainerClass")
    $mainWindow = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $mainWindowCondition)
    if ($mainWindow) {
        Log "Main RDP window found. Assuming connection is successful."
        break
    }

    Start-Sleep -Milliseconds 500
}

if ($promptsHandled -gt 0) {
    Log "Finished handling RDP prompts."
} else {
    Log "No RDP prompts appeared or handled within the timeout period."
}


# --- Hide mstsc.exe windows after prompts ---
if ($promptsHandled -gt 0) {
    Log "Proceeding to hide mstsc windows..."

    $processCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id
    )
    $allMstscWindows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children, $processCondition
    )
    
    Log "Found $($allMstscWindows.Count) mstsc windows to hide"

    foreach ($window in $allMstscWindows) {
        if ($window.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$null)) {
            $windowPattern = $window.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern)
            $windowPattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Minimized)
        }
    }
    Log "All mstsc windows hidden"
} else {
    Log "Skipping window hiding because no prompts were confirmed"
}

Log "Script complete. Logs written to $logFile"
