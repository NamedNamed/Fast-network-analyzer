@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Fast network analyzer v1.00 (By: NamedNamed)

net session >nul 2>&1
if errorlevel 1 (
    echo [!] No administrator rights - some checks are limited.
) else (
    echo [i] Administrator rights: yes.
)
echo.
echo By: NamedNamed
echo.
echo ============================================
echo        Fast network analyser v1.00
echo        %date% %time%
echo ============================================
echo.

echo [1/8] Network interfaces and gateway
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "$up = Get-NetAdapter | Where-Object Status -eq 'Up';" ^
  "if(-not $up){ Write-Host 'NO ACTIVE ADAPTERS' -ForegroundColor Red; exit }" ^
  "foreach($a in $up){" ^
  "  $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1;" ^
  "  $gw = (Get-NetRoute -InterfaceIndex $a.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop;" ^
  "  Write-Host ('  ' + $a.Name + ' [' + $a.InterfaceDescription + ']') -ForegroundColor Cyan;" ^
  "  if($ip){ Write-Host ('    IPv4: ' + $ip.IPAddress + '/' + $ip.PrefixLength) } else { Write-Host '    IPv4: none' -ForegroundColor Yellow };" ^
  "  if($gw){ Write-Host ('    Gateway: ' + $gw) } else { Write-Host '    Gateway: none' -ForegroundColor Yellow };" ^
  "  $dns = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses;" ^
  "  if($dns){ Write-Host ('    DNS:  ' + ($dns -join ', ')) } else { Write-Host '    DNS:  none' -ForegroundColor Yellow };" ^
  "}"
echo.

echo [2/8] Basic connectivity (ICMP)
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "$p = New-Object System.Net.NetworkInformation.Ping;" ^
  "function DoPing($t,$to=1000){" ^
  "  try { $r = $p.Send($t,$to); if($r.Status -eq 'Success'){ [int]$r.RoundtripTime } else { $null } }" ^
  "  catch { $null }" ^
  "}" ^
  "function P($name,$target){" ^
  "  $r1 = DoPing $target; $r2 = DoPing $target;" ^
  "  $ok = @($r1,$r2) | Where-Object { $_ -ne $null };" ^
  "  if($ok.Count -gt 0){" ^
  "    $avg = [math]::Round((($ok | Measure-Object -Average).Average),1);" ^
  "    Write-Host ('  [OK]   ' + $name + ' (' + $target + '): ' + $avg + ' ms') -ForegroundColor Green;" ^
  "  } else {" ^
  "    Write-Host ('  [BAD]  ' + $name + ' (' + $target + '): no response') -ForegroundColor Red;" ^
  "  }" ^
  "}" ^
  "$gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1).NextHop;" ^
  "if($gw){ P 'Gateway' $gw } else { Write-Host '  [WARN] Gateway not determined' -ForegroundColor Yellow };" ^
  "P 'Google DNS' '8.8.8.8';" ^
  "P 'Cloudflare' '1.1.1.1';" ^
  "P 'Quad9'      '9.9.9.9';" ^
  "$p.Dispose();"
echo.

echo [3/8] DNS resolution
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "$targets = @('youtube.com','google.com','gmail.com','store.steampowered.com','steamcommunity.com');" ^
  "foreach($t in $targets){" ^
  "  $sw = [Diagnostics.Stopwatch]::StartNew();" ^
  "  try {" ^
  "    $r = Resolve-DnsName -Name $t -Type A -ErrorAction Stop | Where-Object {$_.Type -eq 'A'} | Select-Object -First 1;" ^
  "    $sw.Stop();" ^
  "    if($r -and $r.IPAddress){" ^
  "      Write-Host ('  [OK]   ' + $t + ' -> ' + $r.IPAddress + ' (' + $sw.ElapsedMilliseconds + ' ms)') -ForegroundColor Green;" ^
  "    } else {" ^
  "      Write-Host ('  [BAD]  ' + $t + ' -> no A record') -ForegroundColor Red;" ^
  "    }" ^
  "  } catch {" ^
  "    $sw.Stop();" ^
  "    Write-Host ('  [BAD]  ' + $t + ' -> error') -ForegroundColor Red;" ^
  "  }" ^
  "}" ^
  "$cfg = Get-DnsClientGlobalSetting;" ^
  "Write-Host ('  [INFO] Suffixes: ' + (($cfg.SuffixSearchList -join ', ') -replace '^$','none'))"
echo.

echo [4/8] TCP connection to popular ports
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "function T($label,$host_,$port){" ^
  "  $c = New-Object Net.Sockets.TcpClient;" ^
  "  $sw = [Diagnostics.Stopwatch]::StartNew();" ^
  "  try {" ^
  "    $ar = $c.BeginConnect($host_,$port,$null,$null);" ^
  "    if($ar.AsyncWaitHandle.WaitOne(3000)){" ^
  "      $c.EndConnect($ar); $sw.Stop();" ^
  "      Write-Host ('  [OK]   ' + $label + ' -> ' + $host_ + ':' + $port + ' (' + $sw.ElapsedMilliseconds + ' ms)') -ForegroundColor Green;" ^
  "    } else {" ^
  "      $sw.Stop();" ^
  "      Write-Host ('  [BAD]  ' + $label + ' -> ' + $host_ + ':' + $port + ' timeout') -ForegroundColor Red;" ^
  "    }" ^
  "  } catch {" ^
  "    $sw.Stop();" ^
  "    Write-Host ('  [BAD]  ' + $label + ' -> ' + $host_ + ':' + $port + ' closed/error') -ForegroundColor Red;" ^
  "  } finally { $c.Close() }" ^
  "}" ^
  "T 'HTTPS (Google)  ' '8.8.8.8'       443;" ^
  "T 'HTTPS (Steam)   ' 'store.steampowered.com' 443;" ^
  "T 'DNS   (Google)  ' '8.8.8.8'       53;" ^
  "T 'SMTP  (Google)  ' '74.125.131.27' 25;"
echo.

echo [5/8] HTTP/HTTPS availability
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;" ^
  "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true };" ^
  "$urls = @('https://youtube.com','https://google.com','https://store.steampowered.com','https://steamcommunity.com');" ^
  "foreach($u in $urls){" ^
  "  $sw = [Diagnostics.Stopwatch]::StartNew();" ^
  "  try {" ^
  "    $req = [System.Net.WebRequest]::Create($u);" ^
  "    $req.Method = 'HEAD';" ^
  "    $req.Timeout = 5000;" ^
  "    $req.UserAgent = 'Mozilla/5.0';" ^
  "    $resp = $req.GetResponse();" ^
  "    $code = [int]$resp.StatusCode;" ^
  "    $resp.Close();" ^
  "    $sw.Stop();" ^
  "    if($code -gt 0){" ^
  "      Write-Host ('  [OK]   ' + $u + ' -> HTTP ' + $code + ' (' + $sw.ElapsedMilliseconds + ' ms)') -ForegroundColor Green;" ^
  "    } else {" ^
  "      Write-Host ('  [BAD]  ' + $u + ' -> no response') -ForegroundColor Red;" ^
  "    }" ^
  "  } catch [System.Net.WebException] {" ^
  "    $sw.Stop();" ^
  "    $ex = $_.Exception;" ^
  "    if($ex.Response) {" ^
  "      $code = [int]$ex.Response.StatusCode;" ^
  "      Write-Host ('  [OK]   ' + $u + ' -> HTTP ' + $code + ' (' + $sw.ElapsedMilliseconds + ' ms)') -ForegroundColor Green;" ^
  "    } else {" ^
  "      Write-Host ('  [BAD]  ' + $u + ' -> no response') -ForegroundColor Red;" ^
  "    }" ^
  "  } catch {" ^
  "    $sw.Stop();" ^
  "    Write-Host ('  [BAD]  ' + $u + ' -> no response') -ForegroundColor Red;" ^
  "  }" ^
  "}"
echo.

echo [6/8] Traceroute to 8.8.8.8 (first 5 hops)
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try {" ^
  "  $process = New-Object System.Diagnostics.Process;" ^
  "  $process.StartInfo.FileName = 'tracert.exe';" ^
  "  $process.StartInfo.Arguments = '-d -h 5 -w 500 8.8.8.8';" ^
  "  $process.StartInfo.UseShellExecute = $false;" ^
  "  $process.StartInfo.RedirectStandardOutput = $true;" ^
  "  $process.StartInfo.RedirectStandardError = $true;" ^
  "  $process.StartInfo.CreateNoWindow = $true;" ^
  "  $process.Start() | Out-Null;" ^
  "  $output = $process.StandardOutput.ReadToEnd();" ^
  "  $process.WaitForExit();" ^
  "  Write-Host $output;" ^
  "  Write-Host '  [INFO] traceroute completed' -ForegroundColor Cyan;" ^
  "} catch { Write-Host ('  [BAD]  ' + $_.Exception.Message) -ForegroundColor Red }"
echo.

echo [7/8] Proxy and system settings
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue;" ^
  "if($p.ProxyEnable -eq 1){ Write-Host ('  [WARN] Proxy enabled: ' + $p.ProxyServer) -ForegroundColor Yellow } else { Write-Host '  [OK]   Proxy: disabled' -ForegroundColor Green };" ^
  "if($p.AutoConfigURL){ Write-Host ('  [WARN] PAC: ' + $p.AutoConfigURL) -ForegroundColor Yellow } else { Write-Host '  [OK]   PAC: none' -ForegroundColor Green };" ^
  "$w = Get-NetFirewallProfile | Select-Object Name,Enabled;" ^
  "foreach($f in $w){ $st = if($f.Enabled){'on'}else{'off'}; Write-Host ('  [INFO] Firewall ' + $f.Name + ': ' + $st) };" ^
  "$wh = (& netsh winhttp show proxy 2>$null | Out-String);" ^
  "$m = [regex]::Match($wh, '(?im)^\s*Proxy Server\s*:\s*(.+)$');" ^
  "if($m.Success){ $v = $m.Groups[1].Value.Trim(); if($v){ Write-Host ('  [INFO] WinHTTP proxy: ' + $v) } else { Write-Host '  [INFO] WinHTTP proxy: direct' } } else { Write-Host '  [INFO] WinHTTP proxy: n/a' }"
echo.

echo [8/8] Availability / Jitter / Packet Loss
echo --------------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue';" ^
  "function Rating($lost){ if($lost -eq 0){'OK'} elseif($lost -eq 1){'WARNING'} else {'BAD'} }" ^
  "function ColorFor($r){ switch($r){ 'OK' {'Green'} 'WARNING' {'Yellow'} default {'Red'} } }" ^
  "Write-Host '  --- Packet loss & jitter (12 pings to 8.8.8.8) ---';" ^
  "$target='8.8.8.8'; $count=12;" ^
  "$p = New-Object System.Net.NetworkInformation.Ping;" ^
  "$samples = New-Object 'System.Collections.Generic.List[object]';" ^
  "for($i=0;$i -lt $count;$i++){" ^
  "  try { $r = $p.Send($target,1000); if($r.Status -eq 'Success'){ $samples.Add([int]$r.RoundtripTime) } else { $samples.Add($null) } }" ^
  "  catch { $samples.Add($null) }" ^
  "}" ^
  "$p.Dispose();" ^
  "$recv = @($samples | Where-Object { $_ -ne $null }).Count;" ^
  "$lost = $count - $recv;" ^
  "$lossPct = [math]::Round(($lost/$count)*100,2);" ^
  "$rating = Rating $lost;" ^
  "$ok = @($samples | Where-Object { $_ -ne $null });" ^
  "if($ok.Count -gt 0){" ^
  "  $avg=[math]::Round((($ok|Measure-Object -Average).Average),1);" ^
  "  $min=($ok|Measure-Object -Minimum).Minimum;" ^
  "  $max=($ok|Measure-Object -Maximum).Maximum;" ^
  "} else { $avg='n/a'; $min='n/a'; $max='n/a' }" ^
  "$diffs = New-Object 'System.Collections.Generic.List[double]';" ^
  "for($i=1;$i -lt $count;$i++){" ^
  "  if($samples[$i] -ne $null -and $samples[$i-1] -ne $null){ $diffs.Add([math]::Abs($samples[$i]-$samples[$i-1])) }" ^
  "}" ^
  "if($diffs.Count -gt 0){ $jitter=[math]::Round((($diffs|Measure-Object -Average).Average),2) } else { $jitter='n/a' }" ^
  "$face = switch($rating){ 'OK' {'[OK]  '} 'WARNING' {'[WARN]'} default {'[BAD] '} };" ^
  "Write-Host ('  ' + $face + ' sent ' + $count + ', recv ' + $recv + ', lost ' + $lost + ' (' + $lossPct + '%) -> ' + $rating) -ForegroundColor (ColorFor $rating);" ^
  "Write-Host ('  [INFO] RTT min ' + $min + ' / avg ' + $avg + ' / max ' + $max + ' ms');" ^
  "Write-Host ('  [INFO] Jitter ' + $jitter + ' ms (over consecutive successful pairs)');" ^
  "Write-Host '';" ^
  "Write-Host '  --- TCP availability to global CDNs (:443) ---';" ^
  "$cdns = @(" ^
  "  @{n='Google  (gstatic)';   h='gstatic.com';   p=443}," ^
  "  @{n='YouTube (youtube)';   h='youtube.com';   p=443}," ^
  "  @{n='Steam  (steampowered)';h='steampowered.com'; p=443}" ^
  ");" ^
  "foreach($c in $cdns){" ^
  "  $tcp = New-Object Net.Sockets.TcpClient;" ^
  "  $sw = [Diagnostics.Stopwatch]::StartNew();" ^
  "  try {" ^
  "    $ar = $tcp.BeginConnect($c.h,$c.p,$null,$null);" ^
  "    if($ar.AsyncWaitHandle.WaitOne(3000)){" ^
  "      $tcp.EndConnect($ar); $sw.Stop();" ^
  "      Write-Host ('  [OK]   ' + $c.n + ' -> :' + $c.p + ' (' + $sw.ElapsedMilliseconds + ' ms)') -ForegroundColor Green;" ^
  "    } else {" ^
  "      $sw.Stop();" ^
  "      Write-Host ('  [BAD]  ' + $c.n + ' -> :' + $c.p + ' timeout') -ForegroundColor Red;" ^
  "    }" ^
  "  } catch {" ^
  "    $sw.Stop();" ^
  "    Write-Host ('  [BAD]  ' + $c.n + ' -> :' + $c.p + ' closed/error') -ForegroundColor Red;" ^
  "  } finally { $tcp.Close() }" ^
  "}"
echo.

echo ============================================
echo  QUICK SUMMARY
echo ============================================
echo  [OK]   = check passed
echo  [WARN] = works, but suspicious (1 lost packet, proxy, PAC)
echo  [BAD]  = check failed (2+ lost packets, no TCP, no DNS)
echo  [INFO] = informational, not a verdict
echo ============================================
echo.

echo ============================================
echo  HOW TO READ THE RESULTS
echo ============================================
echo  DNS slow/errors but TCP is open - problem with the DNS server
echo  TCP 443 times out, ICMP OK - port blocking/proxy/firewall
echo  HTTP errors while 443 is open - TLS/certificates/proxy
echo  Gateway unreachable - local problem (cable/Wi-Fi/driver)
echo  Packet loss: 0 lost = OK, 1 lost = WARN, 2+ lost = BAD
echo  Jitter above 15 ms - unstable channel
echo  Http 200, 301, 302 - OK
echo  Http 403 - blocked
echo  Http 404 - not found
echo  Http 500 - problem on the server
echo  Some results maybe inaccurate
echo ============================================
echo.
echo  GitHub: https://github.com/NamedNamed
echo.
echo  Analyze complete. click on [X] to exit
echo.

:wait_close
ping -n 3 127.0.0.1 >nul
goto wait_close