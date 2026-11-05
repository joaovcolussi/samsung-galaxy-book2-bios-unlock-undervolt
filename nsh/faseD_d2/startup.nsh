@echo -off
echo "=== FASE D - D2: menu AMI aberto SEM salvar ==="
if exist fs0:\EFI\biosmod\faseD_menu.efi then
  fs0:
endif
if exist fs1:\EFI\biosmod\faseD_menu.efi then
  fs1:
endif
if exist fs2:\EFI\biosmod\faseD_menu.efi then
  fs2:
endif
if exist fs3:\EFI\biosmod\faseD_menu.efi then
  fs3:
endif
cd \EFI\biosmod
faseD_menu.efi sinal > fD2_sinal.txt
echo "D2 pronto" > fD2_ok.txt
echo " "
echo "Digite:   faseD_menu.efi 2712      (Advanced AMI)"
echo "Outras:   2711 Main  2714 Chipset  2715 Security  2716 Boot  2717 Save&Exit"
echo "SAIR SEM GRAVAR: ESC ate sair e escolher Discard/No. NAO aperte F10/F9/F4."
echo "No final digite:  reset    (cai no GRUB -> escolha Windows)"
