# Teste automatico apos reboot com DTT desativado no Windows (roda 1x via Tarefa Agendada e se remove)
$ErrorActionPreference = 'Continue'
$T = 'D:\BIOS_Otimizacao\testes'; $SC = "$T\scripts"
Start-Transcript -Path "$T\05_pos_reboot_log.txt" -Force
"Inicio: $(Get-Date)"
Start-Sleep 120
"--- Resultados do UEFI Shell (biosmod.efi / setup_var)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\uefi_leitura" | Out-Null
Copy-Item S:\EFI\biosmod\*.txt "$T\uefi_leitura\" -Force -ErrorAction SilentlyContinue
mountvol S: /D
foreach ($f in 'info.txt','vars.txt') { if (Test-Path "$T\uefi_leitura\$f") { Get-Content "$T\uefi_leitura\$f" -Encoding Unicode } else { "$f nao encontrado (shell nao rodou?)" } }
"--- Estado do DTT"
Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Innovation Platform|Dynamic Tuning' } | Format-Table FriendlyName,Status -AutoSize | Out-String
Get-Service ipfsvc,dptftcs | Format-Table Name,Status,StartType -AutoSize | Out-String
"Tomada: " + (Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline
"Modo Samsung (3=Alto desempenho,2=Otimizado): " + (Get-ItemProperty HKLM:\SOFTWARE\Samsung\SamsungSettings\ModulePerformance).Value
if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE' }
Start-Sleep 40
"--- Limites logo apos boot (BIOS: 20/44 esperado se nada reescreveu)"
& python -I "$SC\watch_pl.py" $SC 5
$plans = @(@('desempenho','899c4747-730a-4234-b3e1-785f488ea79b'), @('equilibrado','381b4222-f694-41f0-9685-ff5bb260df2e'))
$n = 6
foreach ($p in $plans) {
  powercfg /setactive $p[1]; "=== Plano $($p[0]) ativo $(Get-Date)"; Start-Sleep 30
  $env:OPENBLAS_NUM_THREADS = $null
  "--- Multi-core 300 s"
  & python -I "$SC\stress_log.py" 300 60 ("$T\{0:D2}_dttoff_{1}_multi.csv" -f $n, $p[0]); $n++
  $env:OPENBLAS_NUM_THREADS = '1'
  "--- Single-thread 90 s"
  & python -I "$SC\stress_log.py" 90 30 ("$T\{0:D2}_dttoff_{1}_single.csv" -f $n, $p[0]); $n++
  $env:OPENBLAS_NUM_THREADS = $null
}
powercfg /setactive 899c4747-730a-4234-b3e1-785f488ea79b
"--- Limites ao final"
& python -I "$SC\watch_pl.py" $SC 3
"FIM: $(Get-Date)"
Set-Content "$T\05_CONCLUIDO.txt" "Teste pos-reboot concluido em $(Get-Date)"
Unregister-ScheduledTask -TaskName 'BIOSmod_TestePosReboot' -Confirm:$false
Stop-Transcript
