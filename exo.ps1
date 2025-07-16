# Find Exodus executable dynamically
$exodusPath = Get-ChildItem -Path "$env:LOCALAPPDATA\exodus" -Recurse -File -Include "Exodus.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

# Check if Exodus was found, use fallback if not
if (-not $exodusPath) {
    $exodusPath = Get-ChildItem -Path "$env:ProgramFiles", "$env:ProgramFiles(x86)" -Recurse -File -Include "Exodus.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# Start Exodus application if path is found
if ($exodusPath) {
    Start-Process -FilePath $exodusPath
} else {
    Write-Host "Exodus.exe not found. Please install Exodus or adjust the script."
    exit
}

# Wait for Exodus to load (login screen)
Start-Sleep -Seconds 2

# Activate the Exodus login window (initial state)
$wshell = New-Object -ComObject WScript.Shell
$wshell.AppActivate("Exodus") # Initial window title before login

# Wait briefly for focus
Start-Sleep -Milliseconds 500

# Enter password and log in
$wshell.SendKeys("!Mamoute901") # Your password
Start-Sleep -Milliseconds 200
$wshell.SendKeys("{ENTER}") # Confirm login
Start-Sleep -Seconds 2 # Wait for main interface to load

# Activate the main Exodus window (post-login title)
$wshell.AppActivate("EXODUS 25.28.4") # Updated title from image

# Wait briefly for focus
Start-Sleep -Milliseconds 1000

# Navigate to the "Wallet" tab
$wshell.SendKeys("{TAB 3}") # Navigate to "Wallet" tab
Start-Sleep -Milliseconds 500

# Simulate Tab button being pressed 9 times in a row to reach "Send" button
$wshell.SendKeys("{TAB 9}") # Navigate to "Send" button
Start-Sleep -Milliseconds 200
$wshell.SendKeys("{ENTER}") # Open the Send interface
Start-Sleep -Milliseconds 200

# Enter recipient Bitcoin address
$wshell.SendKeys("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa") # Recipient address
Start-Sleep -Milliseconds 200
$wshell.SendKeys("{TAB 2}") # Move to amount field (adjust if needed)
Start-Sleep -Milliseconds 200

# Enter amount
$wshell.SendKeys("0.3") # Amount in BTC
Start-Sleep -Milliseconds 200
$wshell.SendKeys("{TAB 2}") # Move to confirm/send button (adjust if needed)
Start-Sleep -Milliseconds 200
