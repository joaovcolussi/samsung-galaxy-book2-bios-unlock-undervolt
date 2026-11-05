# ETAPA 2b (apos Etapa 2a: OC Feature=1): undervolt em tempo de execucao via ThrottleStop, boot unico SEM Hyper-V.
# Roda 1x no logon (tarefa BIOSmod_TesteEtapa2). Se travar no meio, na proxima execucao so relata o passo que falhou.
$ErrorActionPreference = 'Continue'
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"; $U="$T\etapa2b_undervolt"
$TS="$env:LOCALAPPDATA\Microsoft\WinGet\Packages\TechPowerUp.ThrottleStop_Microsoft.Winget.Source_8wekyb3d8bbwe"
$TSINI="$TS\ThrottleStop.ini"
New-Item -ItemType Directory -Force $U | Out-Null
Start-Transcript -Path "$T\14_etapa2b_uv_log.txt" -Append
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h,int id);
[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
[DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,System.Text.StringBuilder s,int n); }
'@
function Fim($msg) {
  "FIM: $msg  $(Get-Date)"
  Stop-Process -Name ThrottleStop -Force -ErrorAction SilentlyContinue
  & python -I "$SC\ts_fivr.py" $TSINI 0
  $g = Get-Content 'D:\BIOS_Otimizacao\biosmod\bcd_nohv_guid.txt' -ErrorAction SilentlyContinue
  if ($g) { bcdedit /delete $g /f }
  Set-Content "$T\14_CONCLUIDO.txt" "Etapa2 teste: $msg  $(Get-Date)"
  Unregister-ScheduledTask -TaskName 'BIOSmod_TesteEtapa2b' -Confirm:$false
  Stop-Transcript; exit
}
function Offs { & python -I -c "import sys; sys.path.insert(0,r'$SC'); import hwsm; [print(l,'=',round(v*1000,1),'mV') for s,l,u,v,*_ in hwsm.snap() if 'Offset' in l and 'Voltage' in l]" }
function IAoff { [double](& python -I -c "import sys; sys.path.insert(0,r'$SC'); import hwsm; print([round(v*1000,1) for s,l,u,v,*_ in hwsm.snap() if l=='IA Voltage Offset'][0])") }
function StartTS($mv) {
  Stop-Process -Name ThrottleStop -Force -ErrorAction SilentlyContinue; Start-Sleep 2
  & python -I "$SC\ts_fivr.py" $TSINI $mv
  Start-Process "$TS\ThrottleStop.exe" -WindowStyle Minimized; Start-Sleep 10
  $h=(Get-Process ThrottleStop).MainWindowHandle; $b=[W]::GetDlgItem($h,1007)
  $sb=New-Object System.Text.StringBuilder 64; [W]::GetWindowText($b,$sb,64)|Out-Null
  if ($sb.ToString() -eq 'Turn On') { [W]::SendMessage($b,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)|Out-Null }
  Start-Sleep 8
}

# ---- protecao contra travamento: se ja havia comecado, relatar e encerrar
if (Test-Path "$U\iniciado.txt") {
  "=== RETOMADA apos reinicio inesperado"; Get-ChildItem $U\passo_* | % { "$($_.Name): $(Get-Content $_)" }
  Fim "interrompido (provavel instabilidade no ultimo passo 'inicio' sem 'ok')"
}
Set-Content "$U\iniciado.txt" (Get-Date)
"Inicio: $(Get-Date)"; Start-Sleep 90

"--- Logs da gravacao da Etapa 2a (UEFI Shell)"
mountvol S: /S; Start-Sleep 2
New-Item -ItemType Directory -Force "$T\etapa2a_gravacao" | Out-Null
Copy-Item S:\EFI\biosmod\e2a_*.txt, S:\EFI\biosmod\CpuSetup_antes_e2a.dmp "$T\etapa2a_gravacao\" -Force -ErrorAction SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force   # volta ao modo somente leitura
mountvol S: /D
foreach ($f in 'e2a_antes.txt','e2a_depois.txt','e2a_ok.txt','e2a_ERRO.txt') {
  $p = "$T\etapa2a_gravacao\$f"; "== $f"; if (Test-Path $p) { Get-Content $p -Encoding Unicode } else { "(nao existe)" } }
"--- Hypervisor neste boot: " + (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
"VBS status: " + (Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus
"Tomada: " + (Get-CimInstance -Namespace root/wmi BatteryStatus).PowerOnline
if (-not (Get-Process HWiNFO64 -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # Equilibrado (melhor resultado na Etapa 1)
"--- PL apos boot (esperado 25/51)"
& python -I "$SC\watch_pl.py" $SC 3

"--- Referencia 0 mV (120 s)"
& python -I "$SC\stress_log.py" 120 20 "$U\uv_000mV.csv"

"--- FIVR com ThrottleStop em 0 mV (deve mostrar leitura, nao 'Not Available')"
StartTS 0; Offs
$ok = 0
foreach ($mv in -50,-75,-100) {
  "=== Passo $mv mV  $(Get-Date)"
  StartTS $mv; Offs
  $a = IAoff
  if ([math]::Abs($a - $mv) -gt 3) { "NAO APLICOU: IA offset lido = $a mV (esperado $mv)"; break }
  Set-Content "$U\passo_$(-$mv)_inicio.txt" (Get-Date)
  & python -I "$SC\stress_log.py" 120 20 ("$U\uv_{0:D3}mV.csv" -f (-$mv))
  Set-Content "$U\passo_$(-$mv)_ok.txt" (Get-Date)
  $ok = $mv
}
"Ultimo passo estavel (120 s FMA): $ok mV"
Fim "maior offset estavel no teste curto = $ok mV"
