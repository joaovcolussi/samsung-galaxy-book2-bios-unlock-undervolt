# Copia do ESP as leituras da ultima ida a BIOS Avancada e compara entrada x saida (+ backups de antes da Etapa 1). Admin.
$D = 'D:\BIOS_Otimizacao\biosmod\bios_avancada'; $O = "$D\leituras\$(Get-Date -f yyyyMMdd_HHmmss)"
New-Item -ItemType Directory -Force $O | Out-Null
mountvol S: /S; Start-Sleep 2
try { Copy-Item S:\EFI\biosavancada\*.dmp, S:\EFI\biosavancada\vars_entrada.txt $O -ErrorAction SilentlyContinue } finally { mountvol S: /D }
"Pasta: $O"
foreach ($n in 'Setup','CpuSetup','SaSetup','PchSetup') {
  $a = "$O\${n}_entrada.dmp"; $b = "$O\${n}_saida.dmp"
  if (!(Test-Path $a) -or !(Test-Path $b)) { "${n}: falta entrada/saida"; continue }
  $x = [IO.File]::ReadAllBytes($a); $y = [IO.File]::ReadAllBytes($b)
  if ($x.Length -ne $y.Length) { "${n}: TAMANHO DIFERENTE ($($x.Length) x $($y.Length))"; continue }
  $d = for ($i=0; $i -lt $x.Length; $i++) { if ($x[$i] -ne $y[$i]) { '0x{0:X}: {1:X2}->{2:X2}' -f $i,$x[$i],$y[$i] } }
  if ($d) { "${n}: MUDOU em $(@($d).Count) byte(s) (offset do arquivo dmpstore, nao da variavel):"; $d } else { "${n}: identico (nada gravado)" }
}
if (Test-Path "$O\vars_entrada.txt") { '--- valores principais na entrada ---'; Get-Content "$O\vars_entrada.txt" }
