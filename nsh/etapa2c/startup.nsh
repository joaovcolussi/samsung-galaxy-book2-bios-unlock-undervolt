@echo -off
echo "=== BIOS mod ETAPA 2c: undervolt -50 mV P-core/IA + Ring gravado na BIOS (aprovada pelo usuario) ==="
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

echo "1/4 Leitura pre-SO (mailbox OC com OC Feature=1) + backup..."
biosmod.efi > e2c_info_antes.txt
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes_e2c.dmp
setup_var.efi CpuSetup:0x1D9 CpuSetup:0x10E CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE CpuSetup:0x347(2) CpuSetup:0x34A(2) > e2c_antes.txt

echo "2/4 Conferindo pre-requisitos (OC Feature=1, OC Lock=0)..."
setup_var.efi CpuSetup:0x1D9
if %lasterror% ne 0 then
  echo "erro leitura" > e2c_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 P-core/IA offset 50 mV negativo + Ring 50 mV negativo..."
setup_var.efi --write_on_demand CpuSetup:0x1E0(2)=0x0032 CpuSetup:0x1E2=0x01 CpuSetup:0x1EC(2)=0x0032 CpuSetup:0x1EE=0x01
if %lasterror% ne 0 then
  echo "erro gravacao offset" > e2c_ERRO.txt
endif

echo "4/4 Releitura..."
setup_var.efi CpuSetup:0x1D9 CpuSetup:0x10E CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE CpuSetup:0x347(2) CpuSetup:0x34A(2) > e2c_depois.txt
type e2c_depois.txt
echo "gravacao concluida" > e2c_ok.txt
echo "Reiniciando em 10 s. No GRUB, escolha o WINDOWS."
stall 10000000
reset
