@echo -off
echo "=== FASE D - D1b: sinal SetupEnter + listagem (NADA e gravado nem aberto) ==="
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
faseD_menu.efi listar > fD1b_listar.txt
faseD_menu.efi sinal > fD1b_sinal.txt
faseD_sonda.efi > fD1b_sonda_depois.txt
echo "D1b concluido" > fD1b_ok.txt
echo "Iniciando Windows..."
\EFI\Microsoft\Boot\bootmgfw.efi
