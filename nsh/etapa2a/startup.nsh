@echo -off
echo "=== BIOS mod ETAPA 2a: OverClocking Feature + IccMax seguro (aprovada pelo usuario) ==="
if exist fs0:\EFI\biosmod\setup_var.efi then
  fs0:
endif
if exist fs1:\EFI\biosmod\setup_var.efi then
  fs1:
endif
if exist fs2:\EFI\biosmod\setup_var.efi then
  fs2:
endif
if exist fs3:\EFI\biosmod\setup_var.efi then
  fs3:
endif
cd \EFI\biosmod

echo "1/4 Backup (dmpstore) e leitura antes..."
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes_e2a.dmp
setup_var.efi CpuSetup:0x1D9 CpuSetup:0x347(2) CpuSetup:0x346 CpuSetup:0x34A(2) CpuSetup:0x349 CpuSetup:0x187(2) CpuSetup:0x189(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x10E > e2a_antes.txt

echo "2/4 IccMax Override: IA 320 (80 A) / GT 160 (40 A) = mesmos limites de VR atuais..."
setup_var.efi --write_on_demand CpuSetup:0x347(2)=0x0140 CpuSetup:0x34A(2)=0x00A0 CpuSetup:0x346=0x00 CpuSetup:0x349=0x00
if %lasterror% ne 0 then
  echo "ERRO no IccMax -> OverClocking Feature NAO sera ligada. Iniciando Windows."
  echo "erro IccMax" > e2a_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 OverClocking Feature = 1..."
setup_var.efi --write_on_demand CpuSetup:0x1D9=0x01
if %lasterror% ne 0 then
  echo "erro 0x1D9" > e2a_ERRO.txt
endif

echo "4/4 Conferindo (releitura)..."
setup_var.efi CpuSetup:0x1D9 CpuSetup:0x347(2) CpuSetup:0x346 CpuSetup:0x34A(2) CpuSetup:0x349 CpuSetup:0x187(2) CpuSetup:0x189(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x10E > e2a_depois.txt
type e2a_depois.txt
echo "gravacao concluida" > e2a_ok.txt
echo "Reiniciando em 10 s para aplicar. No GRUB, escolha o WINDOWS."
stall 10000000
reset
