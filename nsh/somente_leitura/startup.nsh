@echo -off
echo "=== BIOS mod: leitura automatica (NADA e gravado) ==="
if exist fs0:\EFI\biosmod\biosmod.efi then
  fs0:
endif
if exist fs1:\EFI\biosmod\biosmod.efi then
  fs1:
endif
if exist fs2:\EFI\biosmod\biosmod.efi then
  fs2:
endif
if exist fs3:\EFI\biosmod\biosmod.efi then
  fs3:
endif
cd \EFI\biosmod
biosmod.efi > info.txt
setup_var.efi CpuSetup:0x10E CpuSetup:0x1D9 CpuSetup:0x43 CpuSetup:0x30 CpuSetup:0x13 CpuSetup:0x16 CpuSetup:0x17(4) CpuSetup:0x1B CpuSetup:0x1C CpuSetup:0x1D CpuSetup:0x1E(4) CpuSetup:0x5B(4) CpuSetup:0x5F(4) CpuSetup:0x44 CpuSetup:0x45 CpuSetup:0x227 CpuSetup:0x22 CpuSetup:0x23(4) CpuSetup:0x29 CpuSetup:0x2A CpuSetup:0x2B(4) CpuSetup:0x31 CpuSetup:0x37 CpuSetup:0x7F CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x315(2) CpuSetup:0x31D CpuSetup:0x334 CpuSetup:0x335 CpuSetup:0x2E3 Setup:0x6D2 > vars.txt
echo "leitura concluida" > ok.txt
echo "Iniciando Windows..."
\EFI\Microsoft\Boot\bootmgfw.efi
