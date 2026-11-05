# Teste automatico apos a gravacao da ETAPA 1 (roda 1x via Tarefa Agendada e se remove)
$ErrorActionPreference = 'Continue'
$T = 'D:\BIOS_Otimizacao\testes'; $SC = "$T\scripts"; $K = 'D:\BIOS_Otimizacao\biosmod'
Start-Transcript -Path "$T\10_pos_etapa1_log.txt" -Force
"Inicio: $(Get-Date)"
Start-Sleep 120
"--- Logs da gravacao (UEFI Shell)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\etapa1_gravacao" | Out-Null
Copy-Item S:\EFI\biosmod\e1_*.txt, S:\EFI\biosmod\*_antes.dmp "$T\etapa1_gravacao\" -Force -ErrorAction SilentlyContinue
# volta o startup.nsh para o modo SOMENTE LEITURA (o boot no shell so acontece com BootNext, mas por garantia)
Copy-Item "$K\esp\EFI\biosmod\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
mountvol S: /D
foreach ($f in 'e1_antes.txt','e1_depois.txt','e1_ok.txt','e1_ERRO.txt') {
  $p = "$T\etapa1_gravacao\$f"; "== $f"; if (Test-Path $p) { Get-Content $p -Encoding Unicode } else { "(nao existe)" } }
"--- Dispositivos DTT (com 0x6D2=0 devem sumir)"
Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'Innovation Platform|Dynamic Tuning' } | Format-Table FriendlyName,Status -AutoSize | Out-String
"Tomada: " + (Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline
if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE' }
Start-Sleep 40
"--- Limites logo apos boot (esperado 25/51)"
& python -I "$SC\watch_pl.py" $SC 5
$plans = @(@('desempenho','899c4747-730a-4234-b3e1-785f488ea79b'), @('equilibrado','381b4222-f694-41f0-9685-ff5bb260df2e'))
$n = 11
foreach ($p in $plans) {
  powercfg /setactive $p[1]; "=== Plano $($p[0]) ativo $(Get-Date)"; Start-Sleep 30
  "--- Multi-core 300 s"
  & python -I "$SC\stress_log.py" 300 60 ("$T\{0:D2}_etapa1_{1}_multi.csv" -f $n, $p[0]); $n++
}
powercfg /setactive 899c4747-730a-4234-b3e1-785f488ea79b
"--- Limites ao final"
& python -I "$SC\watch_pl.py" $SC 3
"FIM: $(Get-Date)"
Set-Content "$T\10_CONCLUIDO.txt" "Teste pos-etapa1 concluido em $(Get-Date)"
Unregister-ScheduledTask -TaskName 'BIOSmod_TesteEtapa1' -Confirm:$false
Stop-Transcript
