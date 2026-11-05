# Instala a entrada de boot fixa "BIOS Avancada" (UEFI Shell -> faseD_menu.efi 2712/2714). Rodar como administrador.
# Nada e gravado na NVRAM de Setup; so cria Boot#### no FIM da ordem (nunca boota sozinha) e arquivos em \EFI\biosavancada\.
$ErrorActionPreference = 'Stop'
$K = 'D:\BIOS_Otimizacao\biosmod'; $D = "$K\bios_avancada"
$menuHash = 'BEA57939C576261B208751A57D44E845092969231CE29A14B836910D927766B2'
if ((Get-FileHash "$K\faseD_menu.efi").Hash -ne $menuHash) { throw 'faseD_menu.efi nao e a v2 validada' }
mountvol S: /S; Start-Sleep 2
try {
  New-Item -ItemType Directory -Force S:\EFI\biosavancada | Out-Null
  Copy-Item "$K\esp\EFI\biosmod\shellx64.efi", "$K\esp\EFI\biosmod\setup_var.efi", "$K\faseD_menu.efi", "$D\startup.nsh" S:\EFI\biosavancada\ -Force
  Get-ChildItem S:\EFI\biosavancada | Get-FileHash | ft @{n='ESP';e={Split-Path $_.Path -Leaf}},Hash -AutoSize | Out-Host
  if ((Get-FileHash S:\EFI\biosavancada\faseD_menu.efi).Hash -ne $menuHash) { throw 'copia do faseD_menu.efi no ESP nao confere' }
} finally { mountvol S: /D }
$gFile = "$D\bios_avancada_guid.txt"
if (Test-Path $gFile) { $g = (Get-Content $gFile).Trim(); "Entrada ja existe: $g" }
else {
  $out = bcdedit /copy '{bootmgr}' /d 'BIOS Avancada (menu AMI)'
  $g = [regex]::Match(($out -join ' '), '\{[0-9a-fA-F-]{36}\}').Value
  if (-not $g) { throw "bcdedit /copy falhou: $out" }
  bcdedit /set $g path '\EFI\biosavancada\shellx64.efi' | Out-Host
  bcdedit /set '{fwbootmgr}' displayorder $g /addlast | Out-Host
  Set-Content $gFile $g
}
bcdedit /enum $g | Out-Host
bcdedit /enum '{fwbootmgr}' | Out-Host
"INSTALADO. GUID $g"
