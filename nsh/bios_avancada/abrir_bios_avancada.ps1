# Proximo boot (uma vez) vai direto para a BIOS Avancada. Rodar como administrador.
$g = (Get-Content 'D:\BIOS_Otimizacao\biosmod\bios_avancada\bios_avancada_guid.txt').Trim()
bcdedit /set '{fwbootmgr}' bootsequence $g
Write-Host 'Reiniciando em 10 s direto para a BIOS Avancada... (Ctrl+C cancela; depois: shutdown /a)'
shutdown /r /t 10
Start-Sleep 3
