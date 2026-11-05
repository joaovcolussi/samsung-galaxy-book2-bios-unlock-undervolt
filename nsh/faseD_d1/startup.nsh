@echo -off
echo "=== FASE D - D1: leitura automatica (NADA e gravado nem aberto) ==="
if exist fs0:\EFI\biosmod\faseD_sonda.efi then
  fs0:
endif
if exist fs1:\EFI\biosmod\faseD_sonda.efi then
  fs1:
endif
if exist fs2:\EFI\biosmod\faseD_sonda.efi then
  fs2:
endif
if exist fs3:\EFI\biosmod\faseD_sonda.efi then
  fs3:
endif
cd \EFI\biosmod
biosmod.efi > fD_info.txt
faseD_sonda.efi > fD_sonda.txt
faseD_menu.efi listar > fD_listar.txt
echo "D1 concluido" > fD_ok.txt
echo "Iniciando Windows..."
\EFI\Microsoft\Boot\bootmgfw.efi
