# ETAPA 3c: confere GT AC LL 1,85 (0x00B9) vindo da BIOS e testa a GPU (comparar com 35_etapa3b_gpu = 2,00 em Alto desempenho).
$ErrorActionPreference = 'Continue'
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"; $U="$T\etapa3c_teste"
New-Item -ItemType Directory -Force $U | Out-Null
Start-Transcript -Path "$T\36_etapa3c_log.txt" -Append
function Modo { (Get-ItemProperty HKLM:\SOFTWARE\Samsung\SamsungSettings\ModulePerformance).Value }
function Eventos {
  $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
  "--- WHEA desde o boot:"
  Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id,Message | fl
  "--- Display 4101 (driver de video reiniciado) desde o boot:"
  Get-WinEvent -FilterHashtable @{LogName='System'; Id=4101; StartTime=$boot} -EA SilentlyContinue | select TimeCreated,Id,Message | fl
  Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Windows Error Reporting'; StartTime=$boot} -EA SilentlyContinue | ? Message -match 'LiveKernelEvent' | select TimeCreated,Message | fl
}
function Fim($msg) {
  Eventos; "FIM: $msg  $(Get-Date)"
  Set-Content "$T\36_CONCLUIDO.txt" "Etapa3c: $msg  $(Get-Date)"
  Unregister-ScheduledTask -TaskName 'BIOSmod_TesteEtapa3c' -Confirm:$false
  Stop-Transcript; exit
}
if (Test-Path "$U\iniciado.txt") {
  "=== RETOMADA apos reinicio inesperado"
  Get-ChildItem $U\fase_* | % { "$($_.Name): $(Get-Content $_)" }
  Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008,1001; StartTime=(Get-Date).AddHours(-2)} -EA SilentlyContinue | select TimeCreated,Id,Message | fl
  Fim "interrompido -> reverter: setup_var CpuSetup:0x134(2)=0x00C8 (2,00)"
}
Set-Content "$U\iniciado.txt" (Get-Date)
"Inicio: $(Get-Date)"; Start-Sleep 90

"--- Logs da gravacao (UEFI Shell)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\etapa3c_gravacao" | Out-Null
Copy-Item S:\EFI\biosmod\e3c_*.txt, S:\EFI\biosmod\*_antes_e3c.dmp "$T\etapa3c_gravacao\" -Force -EA SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force   # volta ao modo somente leitura
Remove-Item S:\EFI\biosmod\e3c_*.txt -EA SilentlyContinue
mountvol S: /D
foreach ($f in 'e3c_antes.txt','e3c_depois.txt','e3c_ok.txt','e3c_ERRO.txt') {
  $p = "$T\etapa3c_gravacao\$f"; "== $f"; if (Test-Path $p) { Get-Content $p -Encoding Unicode } else { "(nao existe)" } }
"--- Samsung modo=$(Modo) (3=Alto desempenho)  Tomada=$((Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline)"
if (-not (Get-Process HWiNFO64 -EA SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; Start-Sleep 5
"=== Fase gpu (WebGL 1500 it, 300 s, Equilibrado)  $(Get-Date)  modo=$(Modo)"
Set-Content "$U\fase_gpu_inicio.txt" (Get-Date)
& python -I "$SC\gpu_log.py" $SC 300 "$T\37_etapa3c_gpu.csv" 1500
Set-Content "$U\fase_gpu_ok.txt" (Get-Date)
Fim "concluido (Etapa 3c)  modo=$(Modo)"
