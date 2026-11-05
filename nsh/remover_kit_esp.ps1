# Remove a entrada de boot temporaria "BIOSmod UEFI Shell" e os arquivos do kit no ESP do Windows. Rodar como administrador.
$g = Get-Content "$PSScriptRoot\bcd_entry_guid.txt" -ErrorAction SilentlyContinue
if ($g) { bcdedit /delete $g; "Entrada $g removida" }
mountvol S: /S; Start-Sleep 1
if (Test-Path S:\EFI\biosmod) { Remove-Item S:\EFI\biosmod -Recurse -Force; "Arquivos removidos do ESP" }
mountvol S: /D
