# ☁️ CONFIGURATION
$server = "rdp.rewebly.com"
$username = "Administrator"
$password = "!Mamoute901901a"
$temp = "$env:TEMP\freerdp"
$downloadUrl = "https://ci.freerdp.com/job/freerdp-nightly-windows/lastBuild/arch=win64,label=vs2017/artifact/install/bin/wfreerdp.exe"

# 🎯 PREPARE TEMP FOLDER
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
New-Item -ItemType Directory -Path $temp | Out-Null
$exe = Join-Path $temp "wfreerdp.exe"

# ⬇️ DOWNLOAD PORTABLE BINARY
Invoke-WebRequest -Uri $downloadUrl -OutFile $exe -UseBasicParsing

# 🔑 AUTO-LOGIN VIA CMDKEY
cmdkey /generic:"TERMSRV/$server" /user:$username /pass:$password

# ⚙️ BUILD ARGS: fullscreen, clipboard sync, ignore cert errors
$args = "/v:$server /u:$username /p:$password /clipboard /cert-ignore /f"

# 🚀 LAUNCH SILENTLY
$si = New-Object System.Diagnostics.ProcessStartInfo
$si.FileName = $exe
$si.Arguments = $args
$si.WindowStyle = "Hidden"
$si.UseShellExecute = $false

$proc = [System.Diagnostics.Process]::Start($si)

# 🧼 OPTIONAL: wait & cleanup
Start-Sleep -Seconds 5
# $proc.WaitForExit()
# Remove-Item $temp -Recurse -Force
