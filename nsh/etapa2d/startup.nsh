@echo -off
echo "=== BIOS mod ETAPA 2d: IA AC Loadline 2,80 -> 1,60 mOhm (DC LL fica 2,80) + offsets 2c de volta a 0 ==="
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

echo "1/4 Leitura pre-SO + backup..."
biosmod.efi > e2d_info_antes.txt
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes_e2d.dmp
setup_var.efi CpuSetup:0x12D CpuSetup:0x132(2) CpuSetup:0x13C(2) CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE > e2d_antes.txt

echo "2/4 Conferindo pre-requisitos (VR Config Enable IA = 1)..."
setup_var.efi CpuSetup:0x12D
if %lasterror% ne 0 then
  echo "erro leitura" > e2d_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 Offsets 2c -> 0 e IA AC Loadline = 160 (1,60 mOhm)..."
setup_var.efi --write_on_demand CpuSetup:0x1E0(2)=0x0000 CpuSetup:0x1E2=0x00 CpuSetup:0x1EC(2)=0x0000 CpuSetup:0x1EE=0x00 CpuSetup:0x132(2)=0x00A0
if %lasterror% ne 0 then
  echo "erro gravacao" > e2d_ERRO.txt
endif

echo "4/4 Releitura..."
setup_var.efi CpuSetup:0x12D CpuSetup:0x132(2) CpuSetup:0x13C(2) CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE > e2d_depois.txt
type e2d_depois.txt
echo "gravacao concluida" > e2d_ok.txt
echo "Reiniciando em 10 s. No GRUB, escolha o WINDOWS."
stall 10000000
reset
