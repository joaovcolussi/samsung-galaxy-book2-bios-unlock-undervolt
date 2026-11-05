# ETAPA 2d: confere IA AC Loadline 1,60 mOhm vindo da BIOS (boot normal, com Hyper-V) e mede estabilidade/ganho.
$ErrorActionPreference = 'Continue'
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"; $U="$T\etapa2d_teste"
New-Item -ItemType Directory -Force $U | Out-Null
Start-Transcript -Path "$T\19_etapa2d_log.txt" -Append
function Fim($msg) {
  "--- Erros WHEA (instabilidade de tensao aparece aqui) desde o boot:"
  $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$boot} -ErrorAction SilentlyContinue | select TimeCreated,Id,Message | fl
  "FIM: $msg  $(Get-Date)"
  Set-Content "$T\19_CONCLUIDO.txt" "Etapa2d: $msg  $(Get-Date)"
  Unregister-ScheduledTask -TaskName 'BIOSmod_TesteEtapa2d' -Confirm:$false
  Stop-Transcript; exit
}
if (Test-Path "$U\iniciado.txt") {
  "=== RETOMADA apos reinicio inesperado (provavel instabilidade com AC LL 1,60)"
  Get-ChildItem $U\fase_* | % { "$($_.Name): $(Get-Content $_)" }
  "Eventos de desligamento inesperado (41/6008) e BugCheck (1001):"
  Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008,1001; StartTime=(Get-Date).AddHours(-2)} -ErrorAction SilentlyContinue | select TimeCreated,Id,Message | fl
  Fim "interrompido -> reverter com setup_var CpuSetup:0x132(2)=0x118 (ou F2 -> F9)"
}
Set-Content "$U\iniciado.txt" (Get-Date)
"Inicio: $(Get-Date)"; Start-Sleep 90

"--- Logs da gravacao da Etapa 2d (UEFI Shell)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\etapa2d_gravacao" | Out-Null
Copy-Item S:\EFI\biosmod\e2d_*.txt, S:\EFI\biosmod\CpuSetup_antes_e2d.dmp "$T\etapa2d_gravacao\" -Force -ErrorAction SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force   # volta ao modo somente leitura
Remove-Item S:\EFI\biosmod\e2d_*.txt -ErrorAction SilentlyContinue
mountvol S: /D
foreach ($f in 'e2d_antes.txt','e2d_depois.txt','e2d_ok.txt','e2d_ERRO.txt','e2d_info_antes.txt') {
  $p = "$T\etapa2d_gravacao\$f"; "== $f"; if (Test-Path $p) { Get-Content $p -Encoding Unicode } else { "(nao existe)" } }
"--- Hypervisor neste boot: " + (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
"Tomada: " + (Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline
if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
"--- Offsets lidos pelo HWiNFO (offsets devem ser 0; o ganho aparece no VID sob carga)"
& python -I -c "import sys; sys.path.insert(0,r'$SC'); import hwsm; [print(l,'=',round(v*1000,1),'mV') for s,l,u,v,*_ in hwsm.snap() if 'Offset' in l]"
"--- PL (esperado 25/51)"
& python -I "$SC\watch_pl.py" $SC 2

$fases = @(
  @('equilibrado_multi','381b4222-f694-41f0-9685-ff5bb260df2e',$null,300,60),
  @('desempenho_single','899c4747-730a-4234-b3e1-785f488ea79b','1',120,30),
  @('desempenho_multi','899c4747-730a-4234-b3e1-785f488ea79b',$null,300,60))
$n=20
foreach ($f in $fases) {
  "=== Fase $($f[0])  $(Get-Date)"
  powercfg /setactive $f[1]; $env:OPENBLAS_NUM_THREADS = $f[2]
  Set-Content "$U\fase_$($f[0])_inicio.txt" (Get-Date)
  & python -I "$SC\stress_log.py" $f[3] $f[4] ("$T\{0:D2}_etapa2d_{1}.csv" -f $n, $f[0]); $n++
  Set-Content "$U\fase_$($f[0])_ok.txt" (Get-Date)
}
$env:OPENBLAS_NUM_THREADS = $null
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
Fim "todas as fases concluidas com AC LL 1,60"
