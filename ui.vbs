Set sh = CreateObject("WScript.Shell")

WScript.Sleep 3000
sh.AppActivate "Enter Password"
sh.SendKeys "!Mamoute901{ENTER}"
WScript.Sleep 4000

sh.AppActivate "EXODUS"
WScript.Sleep 1500

sh.SendKeys "%w"
sh.SendKeys "%s"
sh.SendKeys "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
