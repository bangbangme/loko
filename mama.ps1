# --- CONFIGURATION ---
$server   = "rdp.rewebly.com"
$username = "corp\Administrator"
$password = "!Mamoute901901a"

# --- RDP FILE CONTENT ---
$rdpContent = @"
redirectclipboard:i:1
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
devicestoredirect:s:*
drivestoredirect:s:*
redirectdrives:i:1
session bpp:i:32
prompt for credentials on client:i:0
span monitors:i:0
use multimon:i:0
remoteapplicationmode:i:1
server port:i:3389
allow font smoothing:i:1
videoplaybackmode:i:1
audiocapturemode:i:1
gatewayusagemethod:i:0
gatewayprofileusagemethod:i:1
gatewaycredentialssource:i:0
full address:s:$server
alternate shell:s:||PowerShell_ISE
remoteapplicationprogram:s:||PowerShell_ISE
remoteapplicationname:s:Windows PowerShell ISE (x86)
remoteapplicationcmdline:s:
workspace id:s:$server
use redirection server name:i:1
loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.DefaultCollection
alternate full address:s:$server
authentication level:i:2
enablecredsspsupport:i:0
username:s:$username
"@

# --- Save temp RDP file ---
$tempRdpPath = "$env:TEMP\remoteapp_powershell.rdp"
$rdpContent | Out-File -FilePath $tempRdpPath -Encoding ASCII

# --- Create a credential cache so mstsc doesn’t prompt ---
cmdkey /generic:$server /user:$username /pass:$password | Out-Null

# --- Launch RemoteApp silently (minimized) ---
Start-Process "mstsc.exe" -ArgumentList $tempRdpPath -WindowStyle Minimized

Write-Host "RemoteApp session launching for $username@$server ..."
