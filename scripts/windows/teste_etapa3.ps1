# ETAPA 3: confere logo delay 0 / EE Turbo off / GT AC LL 2,00 vindos da BIOS e mede estabilidade/ganho.
$ErrorActionPreference = 'Continue'
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"; $U="$T\etapa3_teste"
New-Item -ItemType Directory -Force $U | Out-Null
Start-Transcript -Path "$T\28_etapa3_log.txt" -Append
function Eventos {
  $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  "--- WHEA desde o boot:"
  Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$boot} -ErrorAction SilentlyContinue | select TimeCreated,Id,Message | fl
  "--- Driver de video reiniciado (Display 4101 / LiveKernelEvent 141) desde o boot:"
  Get-WinEvent -FilterHashtable @{LogName='System'; Id=4101; StartTime=$boot} -ErrorAction SilentlyContinue | select TimeCreated,Id,Message | fl
  Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Windows Error Reporting'; StartTime=$boot} -ErrorAction SilentlyContinue | ? Message -match 'LiveKernelEvent' | select TimeCreated,Message | fl
}
function Fim($msg) {
  Eventos
  "FIM: $msg  $(Get-Date)"
  Set-Content "$T\28_CONCLUIDO.txt" "Etapa3: $msg  $(Get-Date)"
  Unregister-ScheduledTask -TaskName 'BIOSmod_TesteEtapa3' -Confirm:$false
  Stop-Transcript; exit
}
if (Test-Path "$U\iniciado.txt") {
  "=== RETOMADA apos reinicio inesperado"
  Get-ChildItem $U\fase_* | % { "$($_.Name): $(Get-Content $_)" }
  Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008,1001; StartTime=(Get-Date).AddHours(-2)} -ErrorAction SilentlyContinue | select TimeCreated,Id,Message | fl
  Fim "interrompido -> reverter GT LL: setup_var CpuSetup:0x134(2)=0x00F0 (2,40) ou 0x0140 (fabrica) (EE Turbo: CpuSetup:0x1D5=1)"
}
Set-Content "$U\iniciado.txt" (Get-Date)
"Inicio: $(Get-Date)"; Start-Sleep 90

"--- Logs da gravacao (UEFI Shell)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\etapa3_gravacao" | Out-Null
Copy-Item S:\EFI\biosmod\e3_*.txt, S:\EFI\biosmod\*_antes_e3.dmp "$T\etapa3_gravacao\" -Force -ErrorAction SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force   # volta ao modo somente leitura
Remove-Item S:\EFI\biosmod\e3_*.txt -ErrorAction SilentlyContinue
mountvol S: /D
foreach ($f in 'e3_antes.txt','e3_depois.txt','e3_ok.txt','e3_ERRO.txt') {
  $p = "$T\etapa3_gravacao\$f"; "== $f"; if (Test-Path $p) { Get-Content $p -Encoding Unicode } else { "(nao existe)" } }
"--- Hypervisor: " + (Get-CimInstance Win32_ComputerSystem).HypervisorPresent + "  Tomada: " + (Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline
if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
"--- PL (esperado 25/51)"
& python -I "$SC\watch_pl.py" $SC 2

$fases = @(
  @('desempenho_single','899c4747-730a-4234-b3e1-785f488ea79b','1',120,30,29),
  @('equilibrado_multi','381b4222-f694-41f0-9685-ff5bb260df2e',$null,300,60,30))
foreach ($f in $fases) {
  "=== Fase $($f[0])  $(Get-Date)"
  powercfg /setactive $f[1]; $env:OPENBLAS_NUM_THREADS = $f[2]
  Set-Content "$U\fase_$($f[0])_inicio.txt" (Get-Date)
  & python -I "$SC\stress_log.py" $f[3] $f[4] ("$T\{0:D2}_etapa3_{1}.csv" -f $f[5], $f[0])
  Set-Content "$U\fase_$($f[0])_ok.txt" (Get-Date)
}
$env:OPENBLAS_NUM_THREADS = $null
"=== Fase gpu (WebGL 1500 it, Equilibrado; comparar com 27_base_gpu_e2e)  $(Get-Date)"
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
Set-Content "$U\fase_gpu_inicio.txt" (Get-Date)
& python -I "$SC\gpu_log.py" $SC 180 "$T\31_etapa3_gpu.csv" 1500
Set-Content "$U\fase_gpu_ok.txt" (Get-Date)
Fim "todas as fases concluidas (Etapa 3)"
