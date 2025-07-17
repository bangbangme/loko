param(
    [switch]$MonitorInstance
)

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

function Start-ClipboardMonitor {
    Write-Host "Clipboard monitor started. Close this window to stop."

    while ($true) {
        Start-Sleep -Milliseconds 500
        try {
            $clipText = [Windows.Clipboard]::GetText()

            # ✅ Properly quoted match
            if ($clipText -and ($clipText -match "hi")) {
                # ✅ Skip code-like text to prevent self-modification
                if ($clipText -match "while|\{|\}|\(|\)|function|cmdlet") {
                    continue
                }

                $newText = $clipText -replace "hi", "bye"
                [Windows.Clipboard]::SetText($newText)
                Write-Host "Changed clipboard: $newText"
            }
        } catch {
            # Ignore errors like non-text clipboard
        }
    }
}

function Start-Watchdog {
    param (
        [string]$ScriptPath
    )

    while ($true) {
        # Launch a NEW PowerShell process running THIS SAME script as monitor instance
        $proc = Start-Process powershell -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$ScriptPath`" -MonitorInstance" -PassThru

        # Wait until it closes
        Wait-Process -Id $proc.Id

        Write-Host "Monitor closed! Restarting in 2 seconds..."
        Start-Sleep -Seconds 2
    }
}

# ✅ Resolve the current script path
$ScriptPath = $MyInvocation.MyCommand.Path

# ✅ Decide mode: watchdog OR monitor instance
if ($MonitorInstance) {
    Start-ClipboardMonitor
} else {
    Start-Watchdog -ScriptPath $ScriptPath
}
