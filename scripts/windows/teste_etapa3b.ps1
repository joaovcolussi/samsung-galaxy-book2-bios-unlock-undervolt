# ETAPA 3b: repete as fases da Etapa 3 com Samsung Settings em "Alto desempenho" (3).
# Motivo: a 1a rodada (CSVs 29/30/31) rodou em "Otimizado" (2) -> CPU limitada por frequencia (~12 W).
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"
function Modo { (Get-ItemProperty HKLM:\SOFTWARE\Samsung\SamsungSettings\ModulePerformance).Value }
Start-Transcript -Path "$T\32_etapa3b_log.txt" -Append
while (-not (Test-Path "$T\28_CONCLUIDO.txt")) { Start-Sleep 5 }
"Inicio: $(Get-Date)  Samsung modo=$(Modo)  Tomada=$((Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline)"
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | ? { $_.CommandLine -like '*gpustress_*' } | % { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep 20
"--- Carga de fundo antes de comecar (GPU deve estar ~0%):"
& python -I -c "import sys; sys.path.insert(0, r'$SC'); import hwsm; [print(' ', l, round(v,1), u) for s,l,u,v,*_ in hwsm.snap() if l in ('GPU Total Usage','IGPU Power','CPU Package Power','Total CPU Usage')]"
$fases = @(
  @('desempenho_single','899c4747-730a-4234-b3e1-785f488ea79b','1',120,30,33),
  @('equilibrado_multi','381b4222-f694-41f0-9685-ff5bb260df2e',$null,300,60,34))
foreach ($f in $fases) {
  powercfg /setactive $f[1]; Start-Sleep 5
  "=== Fase $($f[0])  $(Get-Date)  Samsung modo apos trocar plano=$(Modo)"
  $env:OPENBLAS_NUM_THREADS = $f[2]
  & python -I "$SC\stress_log.py" $f[3] $f[4] ("$T\{0:D2}_etapa3b_{1}.csv" -f $f[5], $f[0])
  "    modo no fim=$(Modo)"
}
$env:OPENBLAS_NUM_THREADS = $null
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; Start-Sleep 5
"=== Fase gpu  $(Get-Date)  Samsung modo=$(Modo)"
& python -I "$SC\gpu_log.py" $SC 180 "$T\35_etapa3b_gpu.csv" 1500
"--- WHEA / Display 4101 desde o boot:"
$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id | ft
Get-WinEvent -FilterHashtable @{LogName='System'; Id=4101; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id | ft
"FIM $(Get-Date)  modo=$(Modo)"
Set-Content "$T\32_CONCLUIDO.txt" "Etapa3b fim $(Get-Date)"
Stop-Transcript
