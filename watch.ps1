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
    while ($true) {
        # Launch a NEW PowerShell process running THIS SAME script
        $proc = Start-Process powershell -ArgumentList "-NoExit -Command `"& { $(Get-Content -Raw $PSCommandPath) }`"" -PassThru

        # Wait until it closes
        Wait-Process -Id $proc.Id

        Write-Host "Monitor closed! Restarting in 2 seconds..."
        Start-Sleep -Seconds 2
    }
}

# ✅ If running as a monitor instance
if ($env:WATCHDOG -eq "1") {
    Start-ClipboardMonitor
} else {
    # ✅ Otherwise, start the watchdog, which will spawn the monitor
    $env:WATCHDOG = "1"
    Start-Watchdog
}
