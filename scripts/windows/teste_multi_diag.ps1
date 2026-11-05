# Diagnostico da queda aos 120 s no multi Equilibrado: stress 300 s (CSV 44) + uso por nucleo (CSV 44_cores) + top processos.
$T='D:\BIOS_Otimizacao\testes'; $SC="$T\scripts"
Start-Transcript -Path "$T\44_multi_diag_log.txt" -Append
"Inicio $(Get-Date)"
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e; Start-Sleep 10
$job = Start-Job { Get-Counter '\Processor Information(*)\% Processor Time','\Processor Information(*)\% Processor Performance' -SampleInterval 2 -MaxSamples 190 |
  % { $ts=$_.Timestamp; $_.CounterSamples | % { [pscustomobject]@{t=$ts.ToString('HH:mm:ss'); inst=$_.InstanceName; ctr=($_.Path -split '\')[-1]; v=[math]::Round($_.CookedValue,1)} } } |
  Export-Csv "$using:T\44_multi_diag_cores.csv" -NoTypeInformation }
$job2 = Start-Job { 1..19 | % { Start-Sleep 20; $a=Get-Process|select Id,Name,CPU; Start-Sleep 2; $b=Get-Process|select Id,Name,CPU
  "{0} {1}" -f (Get-Date -f HH:mm:ss), (($b | % { $x=$_; $y=$a|? Id -eq $x.Id; if($y -and $x.Name -ne 'python'){ [pscustomobject]@{N=$x.Name;C=[math]::Round(($x.CPU-$y.CPU)/2,2)} } } | sort C -desc | select -first 4 | % { "$($_.N)=$($_.C)" }) -join ' ') } }
& python -I "$SC\stress_log.py" 300 60 "$T\44_multi_diag_equilibrado_multi.csv"
Wait-Job $job,$job2 -Timeout 120 | Out-Null
"--- top processos (nucleos) a cada 20 s:"; Receive-Job $job2
Remove-Job $job,$job2 -Force
"FIM $(Get-Date)"; Set-Content "$T\44_CONCLUIDO.txt" "fim $(Get-Date)"
Stop-Transcript
