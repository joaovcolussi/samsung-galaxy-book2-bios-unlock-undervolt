/*
 * biosmod.efi - diagnostico SOMENTE LEITURA para o BIOS mod do Galaxy Book2 (i7-1255U / Alder Lake-P)
 * Le MSRs e MMIO (MCHBAR) antes do sistema operacional e imprime um relatorio.
 * Nao escreve em nenhuma variavel UEFI nem no flash. A unica escrita e no MSR 0x150 (OC mailbox)
 * com comandos de LEITURA (0x10 = read voltage/frequency settings), que nao alteram nada.
 *
 * Uso no UEFI Shell:  biosmod.efi > fs0:\biosmod\info.txt
 * Compilar: build.cmd (MSVC, sem CRT)
 */
#include <intrin.h>

typedef unsigned long long UINT64;
typedef unsigned int       UINT32;
typedef unsigned short     UINT16;
typedef unsigned char      UINT8;
typedef unsigned short     CHAR16;
typedef UINT64             UINTN;
typedef UINT64             EFI_STATUS;
typedef void              *EFI_HANDLE;

typedef struct { UINT64 Signature; UINT32 Revision, HeaderSize, CRC32, Reserved; } EFI_TABLE_HEADER;
typedef struct _SIMPLE_TEXT_OUT {
    void *Reset;
    EFI_STATUS (*OutputString)(struct _SIMPLE_TEXT_OUT *This, CHAR16 *Str);
} SIMPLE_TEXT_OUT;
typedef struct {
    EFI_TABLE_HEADER Hdr;
    CHAR16 *FirmwareVendor; UINT32 FirmwareRevision;
    EFI_HANDLE ConsoleInHandle; void *ConIn;
    EFI_HANDLE ConsoleOutHandle; SIMPLE_TEXT_OUT *ConOut;
} EFI_SYSTEM_TABLE;

#pragma function(memset)
void *memset(void *d, int c, UINTN n) { UINT8 *p = (UINT8 *)d; while (n--) *p++ = (UINT8)c; return d; }

static SIMPLE_TEXT_OUT *Out;

static void puts16(const char *s) {
    CHAR16 buf[256]; UINTN i = 0;
    while (*s) {
        if (*s == '\n') { buf[i++] = '\r'; }
        buf[i++] = (CHAR16)(UINT8)*s++;
        if (i >= 250) { buf[i] = 0; Out->OutputString(Out, buf); i = 0; }
    }
    buf[i] = 0; Out->OutputString(Out, buf);
}
static void hex(UINT64 v, int digits) {
    char b[20]; int i; b[0] = '0'; b[1] = 'x';
    for (i = 0; i < digits; i++) { int n = (int)((v >> ((digits - 1 - i) * 4)) & 0xF); b[2 + i] = (char)(n < 10 ? '0' + n : 'A' + n - 10); }
    b[2 + digits] = 0; puts16(b);
}
static void dec(UINT64 v) {
    char b[24]; int i = 22; b[23] = 0;
    if (v == 0) { puts16("0"); return; }
    while (v && i >= 0) { b[i--] = (char)('0' + v % 10); v /= 10; }
    puts16(&b[i + 1]);
}
/* imprime valor em milesimos como x.yyy */
static void milli(UINT64 m) { dec(m / 1000); puts16("."); UINT64 f = m % 1000; if (f < 100) puts16("0"); if (f < 10) puts16("0"); dec(f); }
static void bit(const char *name, UINT64 v, int b) { puts16("    "); puts16(name); puts16(((v >> b) & 1) ? " = 1\n" : " = 0\n"); }

static UINT64 rd(UINT32 msr, const char *name) {
    UINT64 v = __readmsr(msr);
    puts16("MSR "); hex(msr, 3); puts16(" "); puts16(name); puts16(" = "); hex(v, 16); puts16("\n");
    return v;
}

static UINT32 PowerUnitDiv = 8;   /* 1/2^PU W */
static UINT32 TimeUnitDiv = 1024; /* 1/2^TU s */

/* decodifica um limite RAPL de 15 bits + enable + clamp + janela, deslocado em 'sh' */
static void rapl(const char *nm, UINT64 v, int sh) {
    UINT64 x = v >> sh;
    UINT64 pw = x & 0x7FFF;
    UINT64 y = (x >> 17) & 0x1F, z = (x >> 22) & 0x3;
    puts16("    "); puts16(nm); puts16(": "); milli(pw * 1000 / PowerUnitDiv); puts16(" W");
    puts16(((x >> 15) & 1) ? "  enable=1" : "  enable=0");
    puts16(((x >> 16) & 1) ? " clamp=1" : " clamp=0");
    /* janela = 2^Y * (1 + Z/4) * unidade */
    UINT64 tw_milli = ((1ULL << y) * (4 + z) * 1000) / (4ULL * TimeUnitDiv);
    puts16("  janela="); milli(tw_milli); puts16(" s\n");
}

static UINT32 pci_rd(UINT32 bus, UINT32 dev, UINT32 fn, UINT32 off) {
    __outdword(0xCF8, 0x80000000u | (bus << 16) | (dev << 11) | (fn << 8) | (off & 0xFC));
    return __indword(0xCFC);
}

/* OC mailbox (MSR 0x150): comando 0x10 = ler configuracao de tensao/frequencia do dominio 'plane' */
static void oc_read(UINT32 plane, const char *nm) {
    UINT64 cmd = 0x8000001000000000ULL | ((UINT64)plane << 40);
    int t;
    __writemsr(0x150, cmd);
    for (t = 0; t < 100000; t++) { if (!(__readmsr(0x150) >> 63)) break; }
    UINT64 r = __readmsr(0x150);
    UINT32 status = (UINT32)((r >> 32) & 0xFF);
    puts16("    plano "); dec(plane); puts16(" ("); puts16(nm); puts16("): resp="); hex(r, 16);
    if ((r >> 63) & 1) { puts16("  [timeout]\n"); return; }
    if (status != 0) { puts16("  status="); hex(status, 2); puts16(" (erro/nao suportado)\n"); return; }
    /* bits 31:21 = offset de tensao em 1/1024 V, complemento de 2 de 11 bits */
    int off = (int)((r >> 21) & 0x7FF);
    if (off & 0x400) off -= 0x800;
    UINT32 ratio = (UINT32)(r & 0xFF);
    puts16("  max_ratio="); dec(ratio);
    puts16("  offset=");
    if (off < 0) { puts16("-"); off = -off; }
    milli((UINT64)off * 1000000 / 1024 / 1000); puts16(" mV\n");
}

EFI_STATUS efi_main(EFI_HANDLE Image, EFI_SYSTEM_TABLE *ST) {
    int r[4]; char brand[49]; int i;
    (void)Image;
    Out = ST->ConOut;

    puts16("==== biosmod.efi v1 - diagnostico (somente leitura) ====\n");

    __cpuid(r, 0x80000002); for (i = 0; i < 4; i++) ((int *)brand)[i] = r[i];
    __cpuid(r, 0x80000003); for (i = 0; i < 4; i++) ((int *)brand)[4 + i] = r[i];
    __cpuid(r, 0x80000004); for (i = 0; i < 4; i++) ((int *)brand)[8 + i] = r[i];
    brand[48] = 0; puts16("CPU: "); puts16(brand); puts16("\n");
    __cpuid(r, 1); puts16("CPUID(1).EAX = "); hex((UINT32)r[0], 8); puts16("\n");
    __writemsr(0x8B, 0); __cpuid(r, 1);
    puts16("Microcode rev = "); hex(__readmsr(0x8B) >> 32, 8); puts16("\n\n");

    puts16("--- Boot Guard ---\n");
    UINT64 bg = rd(0x13A, "BOOT_GUARD_SACM_INFO");
    bit("NEM habilitado (ACM rodou)", bg, 0);
    bit("Measured Boot", bg, 5);
    bit("Verified Boot", bg, 6);
    bit("Revogacao", bg, 7);
    bit("Capacidade Boot Guard (bit32)", bg, 32);
    puts16(((bg >> 6) & 1) ? "  => VERIFIED BOOT ATIVO: flash de BIOS modificada = nao liga.\n"
                           : "  => Verified Boot NAO ativo nos fusiveis.\n");

    puts16("\n--- Travas ---\n");
    UINT64 fr = rd(0x194, "FLEX_RATIO");
    bit("OC Lock (bit20)", fr, 20);
    UINT64 cs = rd(0xE2, "PKG_CST_CONFIG_CONTROL");
    bit("CFG Lock (bit15)", cs, 15);
    puts16("    Package C-state limit (bits3:0) = "); dec(cs & 0xF); puts16("\n");

    puts16("\n--- Energia (RAPL) ---\n");
    UINT64 u = rd(0x606, "RAPL_POWER_UNIT");
    PowerUnitDiv = 1u << (u & 0xF); TimeUnitDiv = 1u << ((u >> 16) & 0xF);
    UINT64 pl = rd(0x610, "PKG_POWER_LIMIT (MSR)");
    rapl("PL1", pl, 0); rapl("PL2", pl, 32); bit("Lock (bit63)", pl, 63);
    UINT64 pi = rd(0x614, "PKG_POWER_INFO");
    puts16("    TDP (SKU) = "); milli((pi & 0x7FFF) * 1000 / PowerUnitDiv); puts16(" W\n");
    UINT64 p3 = rd(0x615, "PL3_CONTROL");
    rapl("PL3", p3, 0); bit("Lock (bit31)", p3, 31);
    UINT64 p4 = rd(0x601, "VR_CURRENT_CONFIG (PL4)");
    puts16("    PL4 (bits12:0, 1/8) = "); milli((p4 & 0x1FFF) * 1000 / 8); puts16("  lock bit31="); dec((p4 >> 31) & 1); puts16("\n");
    UINT64 ps = rd(0x65C, "PLATFORM_POWER_LIMIT (Psys)");
    rapl("Psys PL1", ps, 0); rapl("Psys PL2", ps, 32); bit("Lock (bit63)", ps, 63);
    rd(0x648, "CONFIG_TDP_NOMINAL");
    rd(0x649, "CONFIG_TDP_LEVEL1");
    rd(0x64A, "CONFIG_TDP_LEVEL2");
    UINT64 ct = rd(0x64B, "CONFIG_TDP_CONTROL");
    puts16("    nivel cTDP = "); dec(ct & 3); puts16("  lock bit31="); dec((ct >> 31) & 1); puts16("\n");
    rd(0x64C, "TURBO_ACTIVATION_RATIO");
    UINT64 pc = rd(0x1FC, "POWER_CTL");
    bit("EE Turbo disable (bit19)", pc, 19);
    bit("BD PROCHOT (bit0)", pc, 0);

    puts16("\n--- MMIO (MCHBAR) ---\n");
    UINT64 mch = ((UINT64)pci_rd(0, 0, 0, 0x4C) << 32) | pci_rd(0, 0, 0, 0x48);
    puts16("MCHBAR reg = "); hex(mch, 16); puts16("\n");
    if (mch & 1) {
        UINT64 base = mch & 0x7FFFFE0000ULL;
        volatile UINT64 *mpl = (volatile UINT64 *)(base + 0x59A0);
        UINT64 m = *mpl;
        puts16("MMIO 0x59A0 PKG_RAPL_LIMIT = "); hex(m, 16); puts16("\n");
        rapl("PL1 (MMIO)", m, 0); rapl("PL2 (MMIO)", m, 32); bit("Lock (bit63)", m, 63);
    } else puts16("MCHBAR desabilitado\n");

    puts16("\n--- Termico ---\n");
    UINT64 tt = rd(0x1A2, "TEMPERATURE_TARGET");
    puts16("    TjMax = "); dec((tt >> 16) & 0xFF); puts16(" C   offset = "); dec((tt >> 24) & 0x3F);
    puts16(" C   => TCC ativa em "); dec(((tt >> 16) & 0xFF) - ((tt >> 24) & 0x3F)); puts16(" C\n");
    bit("Lock TCC offset (bit31)", tt, 31);

    puts16("\n--- Turbo / HWP ---\n");
    rd(0x1AD, "TURBO_RATIO_LIMIT");
    rd(0x1AE, "TURBO_RATIO_LIMIT_CORES");
    UINT64 he = rd(0x770, "PM_ENABLE (HWP)");
    if (he & 1) { rd(0x771, "HWP_CAPABILITIES"); rd(0x774, "HWP_REQUEST"); }
    rd(0x64F, "CORE_PERF_LIMIT_REASONS");

    puts16("\n--- Tensoes (OC mailbox, leitura) ---\n");
    puts16("    (offset em mV; requer OC Lock=0 para ALTERAR, leitura costuma funcionar)\n");
    oc_read(0, "IA / P-cores");
    oc_read(1, "GT / iGPU");
    oc_read(2, "Ring / cache / E-cores");
    oc_read(3, "System Agent");
    oc_read(4, "Analog I/O");

    puts16("\n==== fim ====\n");
    return 0;
}
