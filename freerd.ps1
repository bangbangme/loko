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

    # Connect to RDP server using wfreerdp with output redirection
    Write-Host "Connecting to $server..."
    & $xfreerdpPath /u:$username /p:$password /v:$server /dynamic-resolution /tls:seclevel:0 /cert:ignore > $logPath 2>&1

    # Check if the RDP connection was successful
    if ($LASTEXITCODE -eq 0) {
        Write-Host "RDP connection closed successfully."
    } else {
        Write-Host "RDP connection failed with exit code $LASTEXITCODE. Check log at $logPath for details." -ForegroundColor Red
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
