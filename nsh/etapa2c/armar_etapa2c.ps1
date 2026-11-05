# Arma a ETAPA 2c (rodar como admin, SO depois da aprovacao do usuario). Depois e so reiniciar.
# Boot 1: BootNext -> UEFI Shell -> startup.nsh 2c (leitura pre-SO, backup, offset -50 mV IA+Ring, releitura, reset)
# Boot 2: GRUB -> Windows NORMAL (com Hyper-V: o offset vem da BIOS) -> tarefa BIOSmod_TesteEtapa2c
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $T = 'D:\BIOS_Otimizacao\testes'
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\etapa2c\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
Get-Content S:\EFI\biosmod\startup.nsh | Select-String 'ETAPA 2c' | Out-Host
mountvol S: /D
Remove-Item "$T\15_CONCLUIDO.txt","$T\etapa2c_teste\iniciado.txt" -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File $T\scripts\teste_etapa2c.ps1"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName 'BIOSmod_TesteEtapa2c' -Action $a -Trigger $tr -Principal $p -Force | Out-Null
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO (Etapa 2c). Shell: $fw"
