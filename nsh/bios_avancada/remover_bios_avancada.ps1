# Remove a entrada "BIOS Avancada" e a pasta \EFI\biosavancada\ do ESP. Rodar como administrador.
$gFile = 'D:\BIOS_Otimizacao\biosmod\bios_avancada\bios_avancada_guid.txt'
if (Test-Path $gFile) { $g = (Get-Content $gFile).Trim(); bcdedit /delete $g; Remove-Item $gFile; "Entrada $g removida" }
mountvol S: /S; Start-Sleep 1
if (Test-Path S:\EFI\biosavancada) { Remove-Item S:\EFI\biosavancada -Recurse -Force; 'Pasta removida do ESP' }
mountvol S: /D
