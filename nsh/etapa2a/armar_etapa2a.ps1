# Arma a ETAPA 2a (rodar como admin, SO depois da aprovacao do usuario). Depois e so reiniciar.
# Boot 1: BootNext -> UEFI Shell -> startup.nsh da Etapa 2a (backup, IccMax 80/40 A, OC Feature=1, releitura, reset)
# Boot 2: GRUB -> Windows -> bootmgr usa a entrada unica sem Hyper-V -> tarefa BIOSmod_TesteEtapa2b
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'
$T = 'D:\BIOS_Otimizacao\testes'

# 1) startup.nsh de gravacao no ESP
mountvol S: /S; Start-Sleep 2
Copy-Item "$K\etapa2a\startup.nsh" S:\EFI\biosmod\startup.nsh -Force
Get-Content S:\EFI\biosmod\startup.nsh | Select-String 'ETAPA 2a' | Out-Host
mountvol S: /D

# 2) entrada BCD unica sem Hyper-V (o teste se encarrega de apagar)
$out = bcdedit /copy '{default}' /d 'Windows - teste sem Hyper-V (BIOSmod 2b)'
$g = [regex]::Match($out, '\{[0-9a-fA-F-]{36}\}').Value
if (-not $g) { throw "falha ao criar entrada BCD: $out" }
bcdedit /set $g hypervisorlaunchtype off | Out-Host
bcdedit /bootsequence $g | Out-Host
Set-Content "$K\bcd_nohv_guid.txt" $g

# 3) tarefa de teste no proximo logon
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File $T\scripts\teste_etapa2b_uv.ps1"
$tr = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$p = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest -LogonType Interactive
Register-ScheduledTask -TaskName 'BIOSmod_TesteEtapa2b' -Action $a -Trigger $tr -Principal $p -Force | Out-Null

# 4) proximo boot (uma vez) no UEFI Shell
$fw = (Get-Content "$K\bcd_entry_guid.txt").Trim()
bcdedit /set '{fwbootmgr}' bootsequence $fw | Out-Host
"ARMADO. Entrada sem Hyper-V: $g  | Shell: $fw"
