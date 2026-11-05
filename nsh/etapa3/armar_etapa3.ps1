# Arma a ETAPA 3 (admin; aprovada pelo usuario em 04/11 ~19:40). Depois e so reiniciar.
# Boot 1: BootNext -> UEFI Shell -> startup.nsh etapa3 (backup, grava, rele, reset)
# Boot 2: GRUB -> Windows normal -> tarefa BIOSmod_TesteEtapa3 (janela oculta)
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $T = 'D:\BIOS_Otimizacao\testes'
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\etapa3\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
Get-Content S:\EFI\biosmod\startup.nsh | Select-String 'ETAPA 3' | Out-Host
mountvol S: /D
Remove-Item "$T\28_CONCLUIDO.txt" -ErrorAction SilentlyContinue
Remove-Item "$T\etapa3_teste" -Recurse -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $T\scripts\teste_etapa3.ps1"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName 'BIOSmod_TesteEtapa3' -Action $a -Trigger $tr -Principal $p -Force | Out-Null
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO (Etapa 3). Shell: $fw"
