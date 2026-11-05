# Arma a ETAPA 3c GT AC LL 1,85 mOhm (admin; aprovada pelo usuario em 04/11 ~20:10). Depois e so reiniciar.
# Boot 1: BootNext -> UEFI Shell -> startup.nsh etapa3c (backup, grava, rele, reset)
# Boot 2: GRUB -> Windows normal -> tarefa BIOSmod_TesteEtapa3c (janela oculta)
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $T = 'D:\BIOS_Otimizacao\testes'
if (-not (Test-Path "$T\32_CONCLUIDO.txt")) { throw 'Etapa 3b ainda nao terminou' }
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\etapa3c\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
if (-not (Select-String -Path S:\EFI\biosmod\startup.nsh -Pattern 'ETAPA 3c' -Quiet)) { mountvol S: /D; throw 'nsh errado no ESP' }
if (-not (Test-Path S:\EFI\biosmod\setup_var.efi)) { mountvol S: /D; throw 'setup_var.efi ausente no ESP' }
"nsh 3c no ESP OK: " + (Get-FileHash S:\EFI\biosmod\startup.nsh).Hash
mountvol S: /D
Remove-Item "$T\36_CONCLUIDO.txt" -ErrorAction SilentlyContinue
Remove-Item "$T\etapa3c_teste" -Recurse -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $T\scripts\teste_etapa3c.ps1"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName 'BIOSmod_TesteEtapa3c' -Action $a -Trigger $tr -Principal $p -Force | Out-Null
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO (Etapa 3c). Shell: $fw"
