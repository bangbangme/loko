# --- CONFIGURATION ---
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"
$tempDir = "$env:TEMP\freerdp"
$freerdpZipUrl = "https://github.com/FreeRDP/FreeRDP/releases/download/2.11.6/FreeRDP-x64.zip"
$zipPath = "$tempDir\freerdp.zip"
$exePath = "$tempDir\FreeRDP\wfreerdp.exe"

# --- Create Temp Directory ---
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

# --- Download FreeRDP ---
Invoke-WebRequest -Uri $freerdpZipUrl -OutFile $zipPath

# --- Extract ---
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempDir)

# --- Auto-Login: Create CMDKEY entry ---
cmdkey /generic:TERMSRV/$server /user:$username /pass:$password

# --- Construct RDP command ---
$freerdpArgs = "/v:$server /u:$username /p:$password /clipboard /cert-ignore /f"

# --- Launch RDP silently ---
Start-Process -WindowStyle Hidden -FilePath "$exePath" -ArgumentList $freerdpArgs
