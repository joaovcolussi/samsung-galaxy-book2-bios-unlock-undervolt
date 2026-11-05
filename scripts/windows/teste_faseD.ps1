# FASE D (D1b/D2): recolhe os .txt do ESP e restaura o startup.nsh somente leitura. Nao grava nada na BIOS.
param([Parameter(Mandatory)][ValidateSet('D1b','D2')][string]$Etapa)
$ErrorActionPreference = 'Continue'
$T = 'D:\BIOS_Otimizacao\testes'; $O = "$T\faseD_$Etapa"; New-Item -ItemType Directory -Force $O | Out-Null
$pre = if ($Etapa -eq 'D1b') { 'fD1b_' } else { 'fD2_' }
$log = "$O\log.txt"; function L($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }
L "inicio"
Start-Sleep 20
mountvol S: /S; Start-Sleep 2
Copy-Item "S:\EFI\biosmod\$pre*.txt" $O -Force -ErrorAction SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force
Remove-Item "S:\EFI\biosmod\$pre*.txt" -ErrorAction SilentlyContinue
$h1 = (Get-FileHash S:\EFI\biosmod\startup.nsh).Hash; $h2 = (Get-FileHash 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh').Hash
mountvol S: /D
L "arquivos copiados: $((Get-ChildItem "$O\$pre*.txt" | % Name) -join ', ')"
L "startup.nsh restaurado (somente leitura): $($h1 -eq $h2)"
Set-Content "$T\faseD_$($Etapa)_CONCLUIDO.txt" "$Etapa concluido $(Get-Date)"
Unregister-ScheduledTask -TaskName "BIOSmod_FaseD_$Etapa" -Confirm:$false
L "fim"
