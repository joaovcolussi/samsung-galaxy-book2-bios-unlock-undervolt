/*
 * faseD_sonda.efi - Fase D (menus ocultos) - SOMENTE LEITURA.
 * Confirma em runtime o que a engenharia reversa estatica do AMITSE (P11RGK.050) concluiu:
 *  - valor do PCD {EEE8EEBE-2885-41B7-AAC4-EBACF7F8CDFE} 0x5A5A0012 (portao 1, promove abas AMI)
 *  - endereco de carga do AMITSE (via EFI_FORM_BROWSER2.SendForm - 0x19F90 e via varredura LoadedImage)
 *  - bytes exatos nos pontos de patch (portao 1 @0xB08E3, portao 2 @0xB07CE) e nas tabelas 0x1B5480/0x1B56A0
 *  - cabecalho "$SBVC" do firmware do EC na flash mapeada (0xFF5401F0)
 *  - lista de paginas do Setup (se ja inicializada)
 * NAO escreve em variavel, PCD, memoria do AMITSE, EC, MSR nem flash. So le.
 *
 * Uso no UEFI Shell:  faseD_sonda.efi > fs0:\EFI\biosmod\faseD_sonda.txt
 * Compilar: build_faseD.cmd (MSVC, sem CRT)
 */
typedef unsigned long long UINT64;
typedef unsigned int       UINT32;
typedef unsigned short     UINT16;
typedef unsigned char      UINT8;
typedef unsigned short     CHAR16;
typedef UINT64             UINTN;
typedef UINT64             EFI_STATUS;
typedef void              *EFI_HANDLE;
typedef struct { UINT32 D1; UINT16 D2, D3; UINT8 D4[8]; } EFI_GUID;

typedef struct _SIMPLE_TEXT_OUT {
    void *Reset;
    EFI_STATUS (*OutputString)(struct _SIMPLE_TEXT_OUT *This, CHAR16 *Str);
} SIMPLE_TEXT_OUT;

/* deslocamentos padrao UEFI 2.x */
#define ST_CONOUT      0x40
#define ST_BOOTSERV    0x60
#define BS_FREEPOOL    0x48
#define BS_HANDLEPROT  0x98
#define BS_LOCHANDBUF  0x138
#define BS_LOCATEPROT  0x140

typedef EFI_STATUS (*FN_LOCATEPROT)(EFI_GUID *, void *, void **);
typedef EFI_STATUS (*FN_HANDLEPROT)(EFI_HANDLE, EFI_GUID *, void **);
typedef EFI_STATUS (*FN_LOCHANDBUF)(UINTN SearchType, EFI_GUID *, void *, UINTN *, EFI_HANDLE **);
typedef EFI_STATUS (*FN_FREEPOOL)(void *);
typedef UINT8      (*FN_PCDGET8)(EFI_GUID *, UINTN);

static EFI_GUID gPcdProt   = {0x13a3f0f6,0x264a,0x3ef0,{0xf2,0xe0,0xde,0xc5,0x12,0x34,0x2f,0x34}};
static EFI_GUID gPcdSpace  = {0xeee8eebe,0x2885,0x41b7,{0xaa,0xc4,0xeb,0xac,0xf7,0xf8,0xcd,0xfe}};
static EFI_GUID gFB2       = {0xb9d4c360,0xbcfb,0x4f9b,{0x92,0x98,0x53,0xc1,0x36,0x98,0x22,0x58}};
static EFI_GUID gLoadedImg = {0x5b1b31a1,0x9562,0x11d2,{0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b}};

#define TSE_SIZE        0x277560ULL
#define RVA_SENDFORM    0x19F90ULL
#define RVA_FB2_IFACE   0x1A9918ULL
#define RVA_GATE1       0xB08E3ULL   /* FF 50 08 84 C0 74 21 B8 13 27 00 00 */
#define RVA_GATE2       0xB07CEULL   /* F6 43 14 20 74 05 E8 57 FB F6 FF 8B 43 14 83 E0 DF 83 C8 01 89 43 14 */
#define RVA_TAB1        0x1B5480ULL
#define RVA_TAB2        0x1B56A0ULL
#define RVA_PAGELIST    0x259790ULL
#define RVA_PAGEBASE    0x25A678ULL
#define RVA_INITFLAG    0x258A78ULL
#define RVA_MFGGLOBAL   0x258FA0ULL

static const UINT8 sig_gate1[12] = {0xFF,0x50,0x08,0x84,0xC0,0x74,0x21,0xB8,0x13,0x27,0x00,0x00};
static const UINT8 sig_gate2[23] = {0xF6,0x43,0x14,0x20,0x74,0x05,0xE8,0x57,0xFB,0xF6,0xFF,0x8B,0x43,0x14,0x83,0xE0,0xDF,0x83,0xC8,0x01,0x89,0x43,0x14};

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
static void hexbytes(const UINT8 *p, UINTN n) {
    static const char *H = "0123456789ABCDEF"; char b[4]; UINTN i;
    for (i = 0; i < n; i++) { b[0] = H[p[i] >> 4]; b[1] = H[p[i] & 15]; b[2] = ' '; b[3] = 0; puts16(b); }
}
static int same(const UINT8 *a, const UINT8 *b, UINTN n) { while (n--) if (*a++ != *b++) return 0; return 1; }
static int guideq(const EFI_GUID *a, const EFI_GUID *b) { return same((const UINT8 *)a, (const UINT8 *)b, 16); }
static void guid(const EFI_GUID *g) {
    hex(g->D1, 8); puts16("-"); hex(g->D2, 4); puts16("-"); hex(g->D3, 4); puts16("-"); hexbytes(g->D4, 8);
}

static UINT64 check_tse(UINT64 base, const char *via) {
    puts16("  candidato ("); puts16(via); puts16(") base = "); hex(base, 16); puts16("\n");
    if (base == 0 || (base & 0xFFF) != 0) { puts16("    base desalinhada/nula -> descartado\n"); return 0; }
    UINT8 *g1 = (UINT8 *)(base + RVA_GATE1), *g2 = (UINT8 *)(base + RVA_GATE2);
    puts16("    portao1 @+0xB08E3: "); hexbytes(g1, 12); puts16(same(g1, sig_gate1, 12) ? " -> CONFERE\n" : " -> DIFERENTE\n");
    puts16("    portao2 @+0xB07CE: "); hexbytes(g2, 23); puts16(same(g2, sig_gate2, 23) ? " -> CONFERE\n" : " -> DIFERENTE\n");
    return (same(g1, sig_gate1, 12) && same(g2, sig_gate2, 23)) ? base : 0;
}

static void dump_tab(UINT64 base, UINT64 rva, int n, const char *nm) {
    int i; puts16("  "); puts16(nm); puts16(" @+"); hex(rva, 6); puts16(":\n");
    for (i = 0; i < n; i++) {
        UINT8 *e = (UINT8 *)(base + rva + 0x20ULL * i);
        puts16("    ["); hex(i, 2); puts16("] formset="); guid((EFI_GUID *)e);
        puts16(" formId="); hex(*(UINT16 *)(e + 0x10), 4); puts16(" ptr18="); hex(*(UINT64 *)(e + 0x18), 16); puts16("\n");
    }
}

EFI_STATUS efi_main(EFI_HANDLE Image, void *ST) {
    UINT8 *st = (UINT8 *)ST;
    Out = *(SIMPLE_TEXT_OUT **)(st + ST_CONOUT);
    UINT8 *bs = *(UINT8 **)(st + ST_BOOTSERV);
    FN_LOCATEPROT LocateProtocol = *(FN_LOCATEPROT *)(bs + BS_LOCATEPROT);
    FN_HANDLEPROT HandleProtocol = *(FN_HANDLEPROT *)(bs + BS_HANDLEPROT);
    FN_LOCHANDBUF LocateHandleBuffer = *(FN_LOCHANDBUF *)(bs + BS_LOCHANDBUF);
    FN_FREEPOOL FreePool = *(FN_FREEPOOL *)(bs + BS_FREEPOOL);
    EFI_STATUS s; void *p = 0; UINT64 base = 0, base_fb2 = 0, base_li = 0; int nli = 0;

    puts16("==== faseD_sonda.efi v1 (somente leitura) ====\n");

    /* 1. PCD */
    puts16("--- PCD (portao 1)\n");
    s = LocateProtocol(&gPcdProt, 0, &p);
    puts16("  EFI_PCD_PROTOCOL: status="); hex(s, 16); puts16(" iface="); hex((UINT64)p, 16); puts16("\n");
    if (s == 0 && p) {
        FN_PCDGET8 Get8 = *(FN_PCDGET8 *)((UINT8 *)p + 0x08);
        puts16("  Get8(EEE8EEBE..., 0x5A5A0012) [oculta abas AMI se != 0] = "); hex(Get8(&gPcdSpace, 0x5A5A0012), 2); puts16("\n");
        puts16("  Get8(EEE8EEBE..., 0x5A5A0011) [outro PCD, referencia]   = "); hex(Get8(&gPcdSpace, 0x5A5A0011), 2); puts16("\n");
    }

    /* 2. AMITSE via FormBrowser2 */
    puts16("--- AMITSE na memoria\n");
    p = 0; s = LocateProtocol(&gFB2, 0, &p);
    puts16("  EFI_FORM_BROWSER2: status="); hex(s, 16); puts16(" iface="); hex((UINT64)p, 16);
    if (s == 0 && p) {
        UINT64 sf = *(UINT64 *)p;
        puts16(" SendForm="); hex(sf, 16); puts16("\n");
        base_fb2 = sf - RVA_SENDFORM;
        puts16("  iface - base = "); hex((UINT64)p - base_fb2, 8); puts16(" (esperado 0x001A9918)\n");
        base_fb2 = check_tse(base_fb2, "FormBrowser2");
    } else puts16("\n");

    /* 3. AMITSE via LoadedImage (tamanho da imagem) */
    {
        EFI_HANDLE *hb = 0; UINTN nh = 0, i;
        s = LocateHandleBuffer(2 /*ByProtocol*/, &gLoadedImg, 0, &nh, &hb);
        puts16("  LoadedImage handles: status="); hex(s, 16); puts16(" n="); hex(nh, 4); puts16("\n");
        for (i = 0; s == 0 && i < nh; i++) {
            UINT8 *li = 0;
            if (HandleProtocol(hb[i], &gLoadedImg, (void **)&li) != 0 || !li) continue;
            UINT64 ib = *(UINT64 *)(li + 0x40), isz = *(UINT64 *)(li + 0x48);
            if (isz >= TSE_SIZE && isz <= TSE_SIZE + 0x2000) {
                nli++;
                UINT64 b2 = check_tse(ib, "LoadedImage");
                if (b2) base_li = b2;
            }
        }
        if (hb) FreePool(hb);
        puts16("  imagens com tamanho do AMITSE: "); hex(nli, 2); puts16("\n");
    }
    base = base_fb2 ? base_fb2 : base_li;
    puts16("  RESULTADO: base AMITSE = "); hex(base, 16);
    puts16((base_fb2 && base_li && base_fb2 == base_li) ? "  (os dois metodos concordam)\n" :
           (base ? "  (so um metodo confirmou)\n" : "  (NAO CONFIRMADO - nada a fazer)\n"));

    if (base) {
        dump_tab(base, RVA_TAB1, 11, "tabela abas (portao 1, promove)");
        dump_tab(base, RVA_TAB2, 10, "tabela ocultar (portao 2, PageFlags|=1)");
        puts16("  flag setup inicializado [+0x258A78] = "); hex(*(UINT8 *)(base + RVA_INITFLAG), 2); puts16("\n");
        puts16("  global 'M' [+0x258FA0] = "); hexbytes((UINT8 *)(base + RVA_MFGGLOBAL), 7); puts16("\n");
        UINT32 *pl = *(UINT32 **)(base + RVA_PAGELIST); UINT64 pb = *(UINT64 *)(base + RVA_PAGEBASE);
        puts16("  lista de paginas = "); hex((UINT64)pl, 16); puts16(" base = "); hex(pb, 16); puts16("\n");
        if (pl && pb) {
            UINT32 n = pl[0], i; puts16("  paginas: "); hex(n, 4); puts16("\n");
            for (i = 0; i < n && i < 400; i++) {
                UINT8 *pg = (UINT8 *)(pb + pl[1 + i]);
                puts16("    pg "); hex(i, 3); puts16(" formId="); hex(*(UINT16 *)(pg + 0x0A), 4);
                puts16(" parent="); hex(*(UINT16 *)(pg + 0x12), 4); puts16(" flags="); hex(*(UINT32 *)(pg + 0x14), 8); puts16("\n");
            }
        }
    }

    /* 4. cabecalho do EC na flash mapeada (leitura MMIO do SPI, inofensiva) */
    puts16("--- flash 0xFF5401F0 (\"$SBVC\", portao 2): ");
    hexbytes((UINT8 *)0xFF5401F0ULL, 16); puts16("\n");
    puts16("==== fim ====\n");
    return 0;
}
