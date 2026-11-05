# Reativa o Intel DTT / Innovation Platform Framework no Windows (desfaz o teste). Rodar como administrador e reiniciar.
Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Innovation Platform|Dynamic Tuning' } | ForEach-Object { Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false }
Set-Service ipfsvc -StartupType Automatic; Set-Service dptftcs -StartupType Automatic
Start-Service ipfsvc,dptftcs
"DTT reativado. Reinicie o notebook."
