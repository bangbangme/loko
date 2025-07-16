# Path for the temporary monitor script
$monitorPath = "$env:TEMP\clipboard_monitor.ps1"

# Actual clipboard monitor code
$monitorScript = @'
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

Write-Host "Clipboard monitor started. Close this window to stop."

while ($true) {
    Start-Sleep -Milliseconds 500
    try {
        $clipText = [Windows.Clipboard]::GetText()

        if ($clipText -and $clipText -match "hi") {
            $newText = $clipText -replace "hi", "bye"
            [Windows.Clipboard]::SetText($newText)
            Write-Host "Changed clipboard: $newText"
        }
    } catch {
        # Ignore errors
    }
}
'@

# Write the script to a temp file
Set-Content -Path $monitorPath -Value $monitorScript -Encoding UTF8

# Start a new PowerShell window running the monitor
Start-Process powershell -ArgumentList "-NoExit", "-File `"$monitorPath`""
