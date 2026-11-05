# POS METAL LIQUIDO: mesmo protocolo da 3b (CPU: 38/39 vs 33/34; GPU 300 s: 40 vs 37_etapa3c, ambos GT 1,85).
# Confere tambem se a NVRAM da BIOS sobreviveu a desmontagem (PL 25/51) e se o modo Samsung esta em 3.
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"
function Modo { (Get-ItemProperty HKLM:\SOFTWARE\Samsung\SamsungSettings\ModulePerformance).Value }
Start-Transcript -Path "$T\38_pos_metal_log.txt" -Append
"Inicio: $(Get-Date)  Samsung modo=$(Modo)  Tomada=$((Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline)  Boot=$((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)"
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | ? { $_.CommandLine -like '*gpustress_*' } | % { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
if (-not (Get-Process HWiNFO64 -EA SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
Start-Sleep 20
"--- Carga de fundo antes de comecar (GPU deve estar ~0%):"
& python -I "$SC\bg_check.py"
"--- PL (esperado 25/51 = NVRAM intacta)"
& python -I "$SC\watch_pl.py" $SC 2
$fases = @(
  @('desempenho_single','899c4747-730a-4234-b3e1-785f488ea79b','1',120,30,38),
  @('equilibrado_multi','381b4222-f694-41f0-9685-ff5bb260df2e',$null,300,60,39))
foreach ($f in $fases) {
  powercfg /setactive $f[1]; Start-Sleep 5
  "=== Fase $($f[0])  $(Get-Date)  Samsung modo=$(Modo)"
  $env:OPENBLAS_NUM_THREADS = $f[2]
  & python -I "$SC\stress_log.py" $f[3] $f[4] ("$T\{0:D2}_pos_metal_{1}.csv" -f $f[5], $f[0])
}
$env:OPENBLAS_NUM_THREADS = $null
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; Start-Sleep 5
"=== Fase gpu  $(Get-Date)  Samsung modo=$(Modo)"
& python -I "$SC\gpu_log.py" $SC 300 "$T\40_pos_metal_gpu.csv" 1500
"--- WHEA / Display 4101 desde o boot:"
$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id | ft
Get-WinEvent -FilterHashtable @{LogName='System'; Id=4101; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id | ft
"FIM $(Get-Date)  modo=$(Modo)"
Set-Content "$T\38_CONCLUIDO.txt" "Pos metal fim $(Get-Date)"
Stop-Transcript
