# --- CONFIGURATION ---
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"
$temp = "$env:TEMP\freerdp"
$freerdpExe = "$temp\wfreerdp.exe"
$downloadUrl = "https://ci.freerdp.com/job/freerdp-nightly-windows/lastBuild/arch=win64,label=vs2017/artifact/install/bin/wfreerdp.exe"

# --- Create temp folder ---
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
New-Item -ItemType Directory -Path $temp | Out-Null

# --- Download FreeRDP ---
Invoke-WebRequest -Uri $downloadUrl -OutFile $freerdpExe -UseBasicParsing

# --- Store credentials for auto-login ---
cmdkey /generic:"TERMSRV/$server" /user:$username /pass:$password

# --- Arguments: clipboard sync, ignore cert, fullscreen ---
$arguments = "/v:$server /u:$username /p:$password /clipboard /cert-ignore /f"

# --- Run FreeRDP in foreground, show output ---
Write-Host "`n[INFO] Launching FreeRDP..."
& $freerdpExe $arguments
Write-Host "`n[INFO] FreeRDP process exited. You can check above for any errors or connection logs."
