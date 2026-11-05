# Re-teste limpo do multi-core pos-metal (CSV 39b vs 34). Samsung Device Care contaminou o 39.
# Se o iveDeviceCareEngine ainda gastar CPU: para o servico so durante o teste e religa no fim.
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"
Start-Transcript -Path "$T\39b_pos_metal_multi_log.txt" -Append
"Inicio: $(Get-Date)  Samsung modo=$((Get-ItemProperty HKLM:\SOFTWARE\Samsung\SamsungSettings\ModulePerformance).Value)"
if (-not (Get-Process HWiNFO64 -EA SilentlyContinue)) { Start-Process 'C:\Program Files\HWiNFO64\HWiNFO64.EXE'; Start-Sleep 30 }
$p = Get-Process iveDeviceCareEngine -EA SilentlyContinue
$parou = $false
if ($p) {
  $c0 = $p.CPU; Start-Sleep 10; $c1 = (Get-Process -Id $p.Id -EA SilentlyContinue).CPU
  $uso = [math]::Round(($c1 - $c0) / 10, 2)
  "DeviceCare: $uso nucleos medios em 10 s"
  if ($uso -gt 0.05) {
    Stop-Service 'Samsung Device Care Service' -Force -EA SilentlyContinue
    Get-Process iveDeviceCareEngine -EA SilentlyContinue | Stop-Process -Force
    $parou = $true; "DeviceCare PARADO para o teste"
  }
} else { "DeviceCare nao esta rodando" }
Start-Sleep 15
"--- Top CPU antes da carga:"
$a = Get-Process | select Id,Name,CPU; Start-Sleep 5; $b = Get-Process | select Id,Name,CPU
$b | % { $x = $_; $y = $a | ? Id -eq $x.Id; if ($y) { [pscustomobject]@{Name=$x.Name; Nucleos=[math]::Round(($x.CPU-$y.CPU)/5,2)} } } | sort Nucleos -desc | select -first 5 | ft -auto
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; Start-Sleep 5
$env:OPENBLAS_NUM_THREADS = $null
& python -I "$SC\stress_log.py" 300 60 "$T\39b_pos_metal_equilibrado_multi.csv"
if ($parou) { Start-Service 'Samsung Device Care Service' -EA SilentlyContinue; "DeviceCare religado" }
"FIM $(Get-Date)"
Set-Content "$T\39b_CONCLUIDO.txt" "fim $(Get-Date)"
Stop-Transcript
