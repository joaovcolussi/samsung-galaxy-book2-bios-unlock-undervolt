#!/usr/bin/env bash
# =====================================================================
#  Backup SOMENTE LEITURA da BIOS do Samsung Galaxy Book2 (550XED, P11RGK)
#  Nao grava nada no chip. Le duas vezes e compara para garantir copia boa.
#  Uso:  sudo bash /mnt/windows_d/BIOS_Otimizacao/kali_backup_bios.sh
# =====================================================================
set -uo pipefail

PARTUUID="4acfa9e9-252e-4496-b964-57a777f23b9b"   # particao D: do Windows (HD WD 1TB)
DEV="/dev/disk/by-partuuid/$PARTUUID"
MNT="/mnt/windows_d"
OUT="$MNT/BIOS_Otimizacao/backups"

vermelho() { printf '\033[1;31m%s\033[0m\n' "$*"; }
verde()    { printf '\033[1;32m%s\033[0m\n' "$*"; }
amarelo()  { printf '\033[1;33m%s\033[0m\n' "$*"; }

[ "$EUID" -eq 0 ] || { vermelho "Rode com sudo:  sudo bash $0"; exit 1; }

# --- 1. Montar o D: (NUNCA o C:, que esta marcado para reparo) ---
if [ ! -e "$DEV" ]; then
  vermelho "Particao D: nao encontrada. Discos disponiveis:"; lsblk -f; exit 1
fi
mkdir -p "$MNT"
if ! mountpoint -q "$MNT"; then
  mount -t ntfs3 "$DEV" "$MNT" 2>/dev/null || mount -t ntfs-3g "$DEV" "$MNT" || {
    vermelho "Nao consegui montar o D:. Se aparecer 'hibernated'/'unclean', ligue o Windows e use Reiniciar (nao Desligar)."; exit 1; }
fi
mkdir -p "$OUT"
cd "$OUT" || exit 1
LOG="$OUT/flashrom_$(date +%Y%m%d_%H%M%S).log"
verde "D: montado em $MNT. Log: $LOG"

# --- 2. Instalar flashrom se necessario ---
if ! command -v flashrom >/dev/null; then
  amarelo "Instalando flashrom..."
  apt-get update -qq && apt-get install -y flashrom >>"$LOG" 2>&1 || { vermelho "Falha ao instalar flashrom"; exit 1; }
fi
flashrom --version | head -1 | tee -a "$LOG"

# --- 3. Info do sistema para o log ---
{ echo "=== uname ==="; uname -a; echo "=== cmdline ==="; cat /proc/cmdline
  echo "=== dmidecode ==="; dmidecode -s system-product-name; dmidecode -s bios-version; dmidecode -s bios-release-date
  echo "=== lockdown ==="; cat /sys/kernel/security/lockdown 2>/dev/null || echo "n/d"; } >>"$LOG" 2>&1

ler() {  # $1 = prefixo do arquivo, $2.. = argumentos extras do flashrom
  local nome="$1"; shift
  amarelo "Leitura 1/2 ($nome)..."
  flashrom -p internal "$@" -r "${nome}_1.bin" >>"$LOG" 2>&1 || return 1
  amarelo "Leitura 2/2 ($nome)..."
  flashrom -p internal "$@" -r "${nome}_2.bin" >>"$LOG" 2>&1 || return 1
  local h1 h2; h1=$(sha256sum "${nome}_1.bin" | cut -d' ' -f1); h2=$(sha256sum "${nome}_2.bin" | cut -d' ' -f1)
  echo "$nome sha256: $h1 / $h2" | tee -a "$LOG"
  if [ "$h1" = "$h2" ]; then
    mv "${nome}_1.bin" "${nome}.bin"; rm -f "${nome}_2.bin"
    sha256sum "${nome}.bin" > "${nome}.bin.sha256"
    verde "OK: ${nome}.bin ($(stat -c%s "${nome}.bin") bytes) - duas leituras identicas."
    return 0
  else
    vermelho "As duas leituras de $nome diferem! Nao confie nelas."; return 2
  fi
}

# --- 4. Tenta o chip inteiro; se o ME bloquear, le so a regiao BIOS ---
if ler "bios_chip_completo"; then
  RES="completo"
elif ler "bios_regiao_bios" --ifd -i bios; then
  RES="regiao_bios"
else
  RES="falhou"
fi

if [ "$RES" = "falhou" ]; then
  vermelho "Leitura falhou. Ultimas linhas do log:"; tail -n 15 "$LOG"
  if grep -qiE 'mmap|/dev/mem|Operation not permitted|iomem' "$LOG"; then
    amarelo ""
    amarelo "O kernel bloqueou o acesso a memoria. Solucao (vale so para 1 boot):"
    amarelo " 1. Reinicie; no menu do GRUB, com 'Kali' selecionado, aperte a tecla e"
    amarelo " 2. Na linha que comeca com 'linux', adicione no final:  iomem=relaxed"
    amarelo " 3. Aperte F10 para iniciar e rode de novo:  sudo bash /boot/efi/backup_bios.sh"
  fi
  sync; exit 1
fi

sync
verde "=============================================================="
verde " BACKUP CONCLUIDO ($RES). Arquivos em: $OUT"
verde " No Windows ficam em: D:\\BIOS_Otimizacao\\backups"
verde " Guarde tambem uma copia em pendrive/nuvem."
verde "=============================================================="
ls -la "$OUT"
