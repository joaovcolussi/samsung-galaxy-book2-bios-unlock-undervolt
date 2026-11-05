@echo -off
echo "=== BIOS mod ETAPA 2e: IA AC Loadline 1,60 -> 1,40 mOhm (DC LL fica 2,80) ==="
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
biosmod.efi > e2e_info_antes.txt
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes_e2e.dmp
setup_var.efi CpuSetup:0x12D CpuSetup:0x132(2) CpuSetup:0x13C(2) CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE > e2e_antes.txt

echo "2/4 Conferindo pre-requisitos (VR Config Enable IA = 1)..."
setup_var.efi CpuSetup:0x12D
if %lasterror% ne 0 then
  echo "erro leitura" > e2e_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 IA AC Loadline = 140 (1,40 mOhm), offsets seguem 0..."
setup_var.efi --write_on_demand CpuSetup:0x1E0(2)=0x0000 CpuSetup:0x1E2=0x00 CpuSetup:0x1EC(2)=0x0000 CpuSetup:0x1EE=0x00 CpuSetup:0x132(2)=0x008C
if %lasterror% ne 0 then
  echo "erro gravacao" > e2e_ERRO.txt
endif

echo "4/4 Releitura..."
setup_var.efi CpuSetup:0x12D CpuSetup:0x132(2) CpuSetup:0x13C(2) CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x1E0(2) CpuSetup:0x1E2 CpuSetup:0x1EC(2) CpuSetup:0x1EE > e2e_depois.txt
type e2e_depois.txt
echo "gravacao concluida" > e2e_ok.txt
echo "Reiniciando em 10 s. No GRUB, escolha o WINDOWS."
stall 10000000
reset
