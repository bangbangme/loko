# Ensure TLS 1.2 is used for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Silently install NuGet provider if missing
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
}

# Trust PowerShell Gallery so no prompts
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install VirtualDesktop module silently if missing
if (-not (Get-Module -ListAvailable -Name VirtualDesktop)) {
    Install-Module VirtualDesktop -Force -Scope CurrentUser
}

# Import VirtualDesktop module
Import-Module VirtualDesktop

Write-Host "✅ NuGet provider & VirtualDesktop module installed and loaded."

# --- Now VirtualDesktop usage ---

# Create a new virtual desktop
$newDesk = New-Desktop
Write-Host "✅ Created new virtual desktop: $($newDesk.Name)"

# Launch mstsc.exe for RDP
$proc = Start-Process mstsc.exe -ArgumentList "/v:rdp.rewebly.com" -PassThru

# Wait for mstsc window to appear
Start-Sleep -Seconds 3

# Move mstsc window to the new virtual desktop
($proc | Get-Process | ForEach-Object {$_.MainWindowHandle}) | Move-Window $newDesk

Write-Host "✅ Moved mstsc.exe window to a different virtual desktop!"
