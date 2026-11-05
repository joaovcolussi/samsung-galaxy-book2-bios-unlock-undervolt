#!/usr/bin/env bash
# =====================================================================
#  Investigacao do CARREGADOR (USB-PD) do Galaxy Book2 550XED - SOMENTE LEITURA
#  Nao grava nada: nem BIOS, nem EC, nem disco C:. So le o sysfs do kernel,
#  le a RAM do EC (ec_sys com write_support=0) e le MSRs/RAPL durante 45 s de carga.
#  Uso:  sudo bash /boot/efi/ler_carregador.sh
# =====================================================================
set -uo pipefail
PARTUUID="4acfa9e9-252e-4496-b964-57a777f23b9b"   # D: (HD WD 1TB)
DEV="/dev/disk/by-partuuid/$PARTUUID"; MNT="/mnt/windows_d"
verde()   { printf '\033[1;32m%s\033[0m\n' "$*"; }
amarelo() { printf '\033[1;33m%s\033[0m\n' "$*"; }
[ "$EUID" -eq 0 ] || { echo "Rode com sudo:  sudo bash $0"; exit 1; }

mkdir -p "$MNT"
if ! mountpoint -q "$MNT"; then
  mount -t ntfs3 "$DEV" "$MNT" 2>/dev/null || mount -t ntfs-3g "$DEV" "$MNT" || { echo "Nao montei o D:"; exit 1; }
fi
OUT="$MNT/BIOS_Otimizacao/testes/carregador_kali_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"; verde "Resultados em: $OUT"

modprobe msr 2>/dev/null; modprobe ucsi_acpi 2>/dev/null; modprobe typec_ucsi 2>/dev/null
modprobe ec_sys write_support=0 2>/dev/null
mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug 2>/dev/null

coleta() {   # $1 = nome da fase
  local D="$OUT/$1"; mkdir -p "$D"
  {
    echo "== $(date)  kernel $(uname -r)"
    echo "== typec"
    for p in /sys/class/typec/*; do
      [ -e "$p" ] || continue; echo "--- $p"
      for a in "$p"/*; do [ -f "$a" ] && printf '%s = %s\n' "${a##*/}" "$(cat "$a" 2>/dev/null | tr '\n' ' ')"; done
    done
    echo "== usb_power_delivery (PDOs: source-capabilities = o que o CARREGADOR oferece; sink = o que o notebook aceita)"
    find /sys/class/usb_power_delivery/ -L -maxdepth 4 -type f 2>/dev/null | sort | while read -r f; do
      printf '%s = %s\n' "$f" "$(cat "$f" 2>/dev/null | tr '\n' ' ')"; done
    echo "== power_supply"
    for s in /sys/class/power_supply/*; do echo "--- $s"; cat "$s/uevent" 2>/dev/null; done
    echo "== limite de carga (driver samsung-galaxybook)"
    ls -la /sys/class/power_supply/BAT*/charge_control_* 2>/dev/null; cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null
    lsmod | grep -i -E 'ucsi|typec|galaxybook|ec_sys'
  } > "$D/sysfs.txt" 2>&1
  [ -r /sys/kernel/debug/ec/ec0/io ] && xxd /sys/kernel/debug/ec/ec0/io > "$D/ec_ram.txt" 2>&1
  dmesg | grep -i -E 'ucsi|typec|usb_pd|power_supply|pd ' | tail -80 > "$D/dmesg_pd.txt"

  amarelo "[$1] 45 s de carga em todos os nucleos (medindo potencia)..."
  python3 - "$D/carga.csv" <<'PY'
import os, sys, time, struct, glob, multiprocessing as mp
def rd(cpu, reg):
    try:
        fd = os.open(f'/dev/cpu/{cpu}/msr', os.O_RDONLY); v = struct.unpack('<Q', os.pread(fd, 8, reg))[0]; os.close(fd); return v
    except Exception: return None
def e(path):
    try: return int(open(path).read())
    except Exception: return None
zones = {}
for z in glob.glob('/sys/class/powercap/intel-rapl:*'):
    if z.count(':') == 1: zones[open(z + '/name').read().strip()] = z + '/energy_uj'
def burn():
    x = 1.0
    while True: x = x * 1.0000001 + 0.5
procs = [mp.Process(target=burn, daemon=True) for _ in range(os.cpu_count())]
out = open(sys.argv[1], 'w'); names = sorted(zones)
out.write('t,' + ','.join(f'{n}_W' for n in names) + ',msr610,msr65C,msr64F,msr615,ec_note\n')
prev = {n: e(zones[n]) for n in names}; t0 = time.time()
for p in procs: p.start()
for i in range(46):
    time.sleep(1)
    cur = {n: e(zones[n]) for n in names}
    w = [((cur[n] - prev[n]) / 1e6) if (cur[n] is not None and prev[n] is not None and cur[n] >= prev[n]) else '' for n in names]
    prev = cur
    m = [rd(0, r) for r in (0x610, 0x65C, 0x64F, 0x615)]
    out.write(f'{i},' + ','.join(f'{x:.2f}' if x != '' else '' for x in w) + ',' + ','.join(hex(x) if x is not None else '' for x in m) + ',\n'); out.flush()
    if i % 5 == 0: print(i, 's', dict(zip(names, [round(x, 1) if x != '' else x for x in w])))
for p in procs: p.terminate()
PY
  cat /sys/class/power_supply/BAT*/uevent > "$D/bateria_depois.txt" 2>/dev/null
  verde "[$1] coletado."
}

echo
amarelo "FASE 1: deixe tudo como esta agora (do jeito que voce usa no dia a dia)."
read -r -p "Aperte Enter para comecar a fase 1..." _
coleta fase1_como_esta

echo
amarelo "FASE 2: ligue o carregador DIRETO na USB-C do notebook (sem o adaptador de video/hub)."
amarelo "        Se ja estava direto, use a OUTRA porta USB-C."
read -r -p "Aperte Enter quando estiver ligado (ou digite p e Enter para pular)... " r
[ "$r" = "p" ] || { sleep 8; coleta fase2_direto; }

echo
amarelo "FASE 3 (opcional): se tiver OUTRO carregador USB-C de 65 W ou mais, ligue-o direto agora."
read -r -p "Aperte Enter quando estiver ligado (ou p e Enter para pular)... " r
[ "$r" = "p" ] || { sleep 8; coleta fase3_outro_carregador; }

echo
amarelo "FASE 4: DESLIGUE o carregador (rodar na bateria)."
read -r -p "Aperte Enter quando estiver na bateria (ou p e Enter para pular)... " r
[ "$r" = "p" ] || { sleep 8; coleta fase4_bateria; }

sync
verde "PRONTO. Pode religar o carregador e voltar ao Windows (Reiniciar)."
verde "O Claude le tudo em: $OUT"
