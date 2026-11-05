@echo -off
echo "=== BIOS mod ETAPA 3c: GT AC Loadline 2,00 -> 1,85 mOhm (0x00B9) ==="
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

echo "1/4 Backup..."
dmpstore CpuSetup -guid B08F97FF-E6E8-4193-A997-5E9E9B0ADB32 -s CpuSetup_antes_e3c.dmp
dmpstore Setup -guid EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9 -s Setup_antes_e3c.dmp
setup_var.efi Setup:0xC4F Setup:0xC50(4) CpuSetup:0x1D5 CpuSetup:0x12E CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x132(2) CpuSetup:0x13C(2) > e3c_antes.txt

echo "2/4 Conferindo pre-requisito (VR Config Enable GT = 1)..."
setup_var.efi CpuSetup:0x12E
if %lasterror% ne 0 then
  echo "erro leitura" > e3c_ERRO.txt
  \EFI\Microsoft\Boot\bootmgfw.efi
endif

echo "3/4 Gravando..."
setup_var.efi --write_on_demand CpuSetup:0x134(2)=0x00B9
if %lasterror% ne 0 then
  echo "erro gravacao CpuSetup" > e3c_ERRO.txt
endif

echo "4/4 Releitura..."
setup_var.efi Setup:0xC4F Setup:0xC50(4) CpuSetup:0x1D5 CpuSetup:0x12E CpuSetup:0x134(2) CpuSetup:0x13E(2) CpuSetup:0x132(2) CpuSetup:0x13C(2) > e3c_depois.txt
type e3c_depois.txt
echo "gravacao concluida" > e3c_ok.txt
echo "Reiniciando em 10 s. No GRUB, escolha o WINDOWS."
stall 10000000
reset
