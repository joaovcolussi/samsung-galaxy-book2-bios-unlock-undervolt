# Arma a FASE D - D1 (somente leitura). Rodar como admin. Depois e so reiniciar.
# Boot 1: BootNext -> UEFI Shell -> startup.nsh D1 (biosmod + faseD_sonda + faseD_menu listar) -> Windows
# Windows: tarefa BIOSmod_FaseD_D1 recolhe os .txt e restaura o startup.nsh somente leitura.
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $T = 'D:\BIOS_Otimizacao\testes'
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\faseD_sonda.efi","$K\faseD_menu.efi" S:\EFI\biosmod\ -Force
Copy-Item "$K\faseD_d1\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
Get-ChildItem S:\EFI\biosmod\faseD_*.efi | Get-FileHash | ft @{n='ESP';e={Split-Path $_.Path -Leaf}},Hash -AutoSize | Out-Host
Get-Content S:\EFI\biosmod\startup.nsh | Select-String 'FASE D|faseD' | Out-Host
mountvol S: /D
Remove-Item "$T\faseD_D1_CONCLUIDO.txt" -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File $T\scripts\teste_faseD_d1.ps1"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName 'BIOSmod_FaseD_D1' -Action $a -Trigger $tr -Principal $p -Force | Out-Null
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO (Fase D - D1, somente leitura). Shell: $fw"
