// save as ui.js
var shell = new ActiveXObject("WScript.Shell");

// bring Exodus to focus
shell.AppActivate("EXODUS");
WScript.Sleep(500);

// send password
shell.SendKeys("!Mamoute901{ENTER}");
WScript.Sleep(2000);

// click Wallet (SendKeys fallback)
shell.SendKeys("%w"); // alt+W
shell.SendKeys("%s"); // alt+S
