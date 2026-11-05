@echo -off
echo "=== BIOS mod ETAPA 1: GRAVACAO (aprovada pelo usuario) ==="
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

echo "1/4 Backup das variaveis (dmpstore)..."
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes.dmp
dmpstore Setup -guid EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9 -s Setup_antes.dmp
setup_var.efi CpuSetup:0x10E CpuSetup:0x13 CpuSetup:0x17(4) CpuSetup:0x1E(4) CpuSetup:0x5B(4) CpuSetup:0x5F(4) Setup:0x6D2 > e1_antes.txt

echo "2/4 Gravando CpuSetup (OC Lock, Boot perf, PL1 25 W, PL2 51 W)..."
setup_var.efi --write_on_demand CpuSetup:0x10E=0x00 CpuSetup:0x13=0x02 CpuSetup:0x17(4)=0x61A8 CpuSetup:0x5B(4)=0x61A8 CpuSetup:0x1E(4)=0xC738 CpuSetup:0x5F(4)=0xC738
if %lasterror% ne 0 then
  echo "ERRO na gravacao do CpuSetup -> nada mais sera gravado. Iniciando Windows."
  echo "erro CpuSetup" > e1_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 Gravando Setup (DTT desligado)..."
setup_var.efi --write_on_demand Setup:0x6D2=0x00
if %lasterror% ne 0 then
  echo "erro Setup" > e1_ERRO.txt
endif

echo "4/4 Conferindo (releitura)..."
setup_var.efi CpuSetup:0x10E CpuSetup:0x13 CpuSetup:0x17(4) CpuSetup:0x1E(4) CpuSetup:0x5B(4) CpuSetup:0x5F(4) Setup:0x6D2 > e1_depois.txt
type e1_depois.txt
echo "gravacao concluida" > e1_ok.txt
echo "Reiniciando em 10 s para aplicar. No GRUB, escolha o WINDOWS."
stall 10000000
reset
