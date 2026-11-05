# FASE D - D1: recolhe a leitura pre-SO (sonda + listar) e restaura o startup.nsh somente leitura. Nao grava nada na BIOS.
$ErrorActionPreference = 'Continue'
$T = 'D:\BIOS_Otimizacao\testes'; $O = "$T\faseD_D1"; New-Item -ItemType Directory -Force $O | Out-Null
$log = "$O\log.txt"; function L($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }
L "inicio"
Start-Sleep 20
mountvol S: /S; Start-Sleep 2
Copy-Item S:\EFI\biosmod\fD_*.txt $O -Force -ErrorAction SilentlyContinue
Copy-Item 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh' S:\EFI\biosmod\startup.nsh -Force
Remove-Item S:\EFI\biosmod\fD_*.txt -ErrorAction SilentlyContinue
$h1 = (Get-FileHash S:\EFI\biosmod\startup.nsh).Hash; $h2 = (Get-FileHash 'D:\BIOS_Otimizacao\biosmod\esp\EFI\biosmod\startup.nsh').Hash
mountvol S: /D
L "arquivos copiados: $((Get-ChildItem $O\fD_*.txt | % Name) -join ', ')"
L "startup.nsh restaurado (somente leitura): $($h1 -eq $h2)"
Set-Content "$T\faseD_D1_CONCLUIDO.txt" "D1 concluido $(Get-Date)"
Unregister-ScheduledTask -TaskName 'BIOSmod_FaseD_D1' -Confirm:$false
L "fim"
