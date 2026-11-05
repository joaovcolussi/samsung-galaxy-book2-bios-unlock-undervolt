# Arma uma etapa da FASE D. Rodar como admin. Depois e so reiniciar.
#   -Etapa D1b : automatico. Shell: faseD_menu listar + sinal + sonda -> Windows. Nada aberto, nada gravado.
#   -Etapa D2  : interativo. Shell: sinal -> PARA no Shell; o usuario digita faseD_menu.efi 2712, sai com ESC+Discard, 'reset'.
# No Windows a tarefa BIOSmod_FaseD_<Etapa> recolhe os .txt e restaura o startup.nsh somente leitura.
param([Parameter(Mandatory)][ValidateSet('D1b','D2')][string]$Etapa)
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $T = 'D:\BIOS_Otimizacao\testes'
$nsh = "$K\faseD_$($Etapa.ToLower())\startup.nsh"
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\faseD_sonda.efi","$K\faseD_menu.efi" S:\EFI\biosmod\ -Force
Copy-Item $nsh S:\EFI\biosmod\startup.nsh -Force
Get-ChildItem S:\EFI\biosmod\faseD_*.efi | Get-FileHash | ft @{n='ESP';e={Split-Path $_.Path -Leaf}},Hash -AutoSize | Out-Host
Get-Content S:\EFI\biosmod\startup.nsh | Select-String 'FASE D' | Out-Host
mountvol S: /D
Remove-Item "$T\faseD_$($Etapa)_CONCLUIDO.txt" -ErrorAction SilentlyContinue
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File $T\scripts\teste_faseD.ps1 -Etapa $Etapa"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName "BIOSmod_FaseD_$Etapa" -Action $a -Trigger $tr -Principal $p -Force | Out-Null
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO (Fase D - $Etapa). Shell: $fw"
