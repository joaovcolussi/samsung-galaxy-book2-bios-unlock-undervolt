@echo -off
echo "=============================================================="
echo "  BIOS AVANCADA - menu AMI completo (Galaxy Book2 P11RGK.050)"
echo "=============================================================="
if exist fs0:\EFI\biosavancada\faseD_menu.efi then
  fs0:
endif
if exist fs1:\EFI\biosavancada\faseD_menu.efi then
  fs1:
endif
if exist fs2:\EFI\biosavancada\faseD_menu.efi then
  fs2:
endif
if exist fs3:\EFI\biosavancada\faseD_menu.efi then
  fs3:
endif
cd \EFI\biosavancada
echo "Copia somente leitura das variaveis (entrada)..."
for %v in Setup_entrada.dmp CpuSetup_entrada.dmp SaSetup_entrada.dmp PchSetup_entrada.dmp Setup_saida.dmp CpuSetup_saida.dmp SaSetup_saida.dmp PchSetup_saida.dmp
  if exist %v then
    rm -q %v
  endif
endfor
dmpstore Setup -guid EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9 -s Setup_entrada.dmp
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_entrada.dmp
dmpstore SaSetup -guid 72C5E28C-7783-43A1-8767-FAD73FCCAFA4 -s SaSetup_entrada.dmp
dmpstore PchSetup -guid 4570B7F1-ADE8-4943-8DC3-406472842384 -s PchSetup_entrada.dmp
setup_var.efi CpuSetup:0x10E CpuSetup:0x1D9 CpuSetup:0x13 CpuSetup:0x17(4) CpuSetup:0x5B(4) CpuSetup:0x1E(4) CpuSetup:0x5F(4) CpuSetup:0x347(2) CpuSetup:0x34A(2) CpuSetup:0x132(2) CpuSetup:0x13C(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE Setup:0x6D2 > vars_entrada.txt
echo " "
echo "ATENCAO: F10 = GRAVA as mudancas. ESC + Discard/No = sai SEM gravar."
echo "Nao use F9 (volta TUDO ao padrao: desfaz PL 25/51 W, undervolt LL 1,40, DTT off)."
echo " "
echo "1/2: abrindo ADVANCED (2712)..."
faseD_menu.efi 2712
echo " "
echo "2/2: proximo = CHIPSET (2714). Tecla qualquer abre | q = ir para o prompt"
pause
faseD_menu.efi 2714
echo " "
echo "Copia somente leitura das variaveis (saida)..."
dmpstore Setup -guid EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9 -s Setup_saida.dmp
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_saida.dmp
dmpstore SaSetup -guid 72C5E28C-7783-43A1-8767-FAD73FCCAFA4 -s SaSetup_saida.dmp
dmpstore PchSetup -guid 4570B7F1-ADE8-4943-8DC3-406472842384 -s PchSetup_saida.dmp
echo " "
echo "Fim. Tecla qualquer = reiniciar | q = ficar no prompt"
echo "No prompt: faseD_menu.efi 2711 Main / 2712 Advanced / 2714 Chipset /"
echo "           2715 Security / 2716 Boot / 2717 Save&Exit ;  'reset' reinicia"
pause
reset
