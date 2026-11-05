/*
 * faseD_menu.efi - Fase D: abre um formulario OCULTO do Setup AMI pelo navegador do proprio AMITSE.
 * Nao faz patch em nada: chama o protocolo padrao EFI_FORM_BROWSER2.SendForm (instalado pelo AMITSE)
 * com o FormId pedido. A selecao de pagina do AMITSE para SendForm (FUN_1b888) casa so FormId + handle
 * e ignora as flags de ocultacao (ver engenharia_reversa\faseD\05_RE_sendform_entrada_setup.md).
 *
 * Uso no UEFI Shell:
 *   faseD_menu.efi listar      -> so lista os handles HII de formularios e onde esta o formset Setup (nao abre nada)
 *   faseD_menu.efi 2712        -> abre "Advanced" (AMI). Outros: 2711 Main, 2714 Chipset, 2715 Security,
 *                                 2716 Boot, 2717 Save & Exit, 2719 Advanced Samsung (visivel, para comparar)
 * Nada e gravado a menos que o usuario salve DENTRO do navegador (F10 / Save). ESC + "Discard" = sai sem gravar.
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

#define ST_CONOUT      0x40
#define ST_BOOTSERV    0x60
#define BS_ALLOCPOOL   0x40
#define BS_FREEPOOL    0x48
#define BS_HANDLEPROT  0x98
#define BS_LOCATEPROT  0x140
#define EFI_BUFFER_TOO_SMALL 0x8000000000000005ULL

typedef EFI_STATUS (*FN_LOCATEPROT)(EFI_GUID *, void *, void **);
typedef EFI_STATUS (*FN_HANDLEPROT)(EFI_HANDLE, EFI_GUID *, void **);
typedef EFI_STATUS (*FN_ALLOCPOOL)(UINTN Type, UINTN Size, void **);
typedef EFI_STATUS (*FN_FREEPOOL)(void *);
typedef EFI_STATUS (*FN_LISTPKG)(void *This, UINT8 Type, EFI_GUID *PkgGuid, UINTN *Len, EFI_HANDLE *Buf);
typedef EFI_STATUS (*FN_EXPORTPKG)(void *This, EFI_HANDLE H, UINTN *Size, void *Buf);
typedef EFI_STATUS (*FN_SENDFORM)(void *This, EFI_HANDLE *Handles, UINTN Count, EFI_GUID *FormSet,
                                  UINT16 FormId, void *ScreenDim, UINTN *ActionRequest);

static EFI_GUID gHiiDb     = {0xef9fc172,0xa1b2,0x4693,{0xb3,0x27,0x6d,0x32,0xfc,0x41,0x60,0x42}};
static EFI_GUID gFB2       = {0xb9d4c360,0xbcfb,0x4f9b,{0x92,0x98,0x53,0xc1,0x36,0x98,0x22,0x58}};
static EFI_GUID gLoadedImg = {0x5b1b31a1,0x9562,0x11d2,{0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b}};
static EFI_GUID gSetupFs   = {0x7b59104a,0xc00d,0x4158,{0x87,0xff,0xf0,0x4d,0x63,0x96,0xa9,0x15}};

#define RVA_SENDFORM 0x19F90ULL
#define TSE_GATE1    0xB08E3ULL
static const UINT8 sig_gate1[12] = {0xFF,0x50,0x08,0x84,0xC0,0x74,0x21,0xB8,0x13,0x27,0x00,0x00};

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
static int same(const UINT8 *a, const UINT8 *b, UINTN n) { while (n--) if (*a++ != *b++) return 0; return 1; }

/* procura o opcode EFI_IFR_FORM_SET (0x0E) seguido do GUID do formset dentro do pacote exportado */
static int has_formset(const UINT8 *buf, UINTN n, const EFI_GUID *g) {
    UINTN i;
    for (i = 0; i + 18 <= n; i++)
        if (buf[i] == 0x0E && (buf[i + 1] & 0x7F) >= 18 && same(buf + i + 2, (const UINT8 *)g, 16)) return 1;
    return 0;
}

/* le o ultimo argumento da linha de comando (LoadOptions UCS-2 do Shell) */
static int get_arg(CHAR16 *opt, UINTN bytes, char *out, int max) {
    UINTN n = bytes / 2, i, st = 0; int k = 0;
    if (!opt || !n) return 0;
    while (n && (opt[n - 1] == 0 || opt[n - 1] == ' ')) n--;
    for (i = 0; i < n; i++) if (opt[i] == ' ') st = i + 1;
    if (st == 0) return 0;               /* so o nome do programa: usa o padrao */
    for (i = st; i < n && k < max - 1; i++) out[k++] = (char)opt[i];
    out[k] = 0; return k;
}
static int parse_hex(const char *s, UINT32 *v) {
    UINT32 r = 0; int d = 0;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
    for (; *s; s++, d++) {
        char c = *s; UINT32 x;
        if (c >= '0' && c <= '9') x = c - '0'; else if (c >= 'a' && c <= 'f') x = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') x = c - 'A' + 10; else return 0;
        r = r * 16 + x;
    }
    *v = r; return d > 0 && d <= 4;
}

EFI_STATUS efi_main(EFI_HANDLE Image, void *ST) {
    UINT8 *st = (UINT8 *)ST;
    Out = *(SIMPLE_TEXT_OUT **)(st + ST_CONOUT);
    UINT8 *bs = *(UINT8 **)(st + ST_BOOTSERV);
    FN_LOCATEPROT LocateProtocol = *(FN_LOCATEPROT *)(bs + BS_LOCATEPROT);
    FN_HANDLEPROT HandleProtocol = *(FN_HANDLEPROT *)(bs + BS_HANDLEPROT);
    FN_ALLOCPOOL AllocatePool = *(FN_ALLOCPOOL *)(bs + BS_ALLOCPOOL);
    FN_FREEPOOL FreePool = *(FN_FREEPOOL *)(bs + BS_FREEPOOL);
    EFI_STATUS s; void *hii = 0, *fb2 = 0; UINT8 *li = 0;
    char arg[16]; int listar = 0; UINT32 formId = 0x2712;

    puts16("==== faseD_menu.efi v1 ====\n");
    if (HandleProtocol(Image, &gLoadedImg, (void **)&li) == 0 && li &&
        get_arg(*(CHAR16 **)(li + 0x38), *(UINT32 *)(li + 0x30), arg, sizeof(arg))) {
        if (same((const UINT8 *)arg, (const UINT8 *)"listar", 6)) listar = 1;
        else if (!parse_hex(arg, &formId) || formId < 0x2710 || formId > 0x27FF) {
            puts16("argumento invalido (use: listar | 2711..27FF em hex)\n"); return 0;
        }
    }

    s = LocateProtocol(&gFB2, 0, &fb2);
    puts16("FormBrowser2: status="); hex(s, 16); puts16("\n");
    if (s || !fb2) return s;
    UINT64 sf = *(UINT64 *)fb2, base = sf - RVA_SENDFORM;
    int is_tse = ((base & 0xFFF) == 0) && same((UINT8 *)(base + TSE_GATE1), sig_gate1, 12);
    puts16("SendForm="); hex(sf, 16); puts16(is_tse ? "  -> e o AMITSE P11RGK.050 esperado\n" : "  -> NAO e o AMITSE esperado\n");
    if (!is_tse) { puts16("Abortado: navegador desconhecido.\n"); return 0; }

    s = LocateProtocol(&gHiiDb, 0, &hii);
    puts16("HiiDatabase: status="); hex(s, 16); puts16("\n");
    if (s || !hii) return s;
    FN_LISTPKG ListPackageLists = *(FN_LISTPKG *)((UINT8 *)hii + 0x18);
    FN_EXPORTPKG ExportPackageLists = *(FN_EXPORTPKG *)((UINT8 *)hii + 0x20);

    UINTN len = 0; EFI_HANDLE *hs = 0;
    s = ListPackageLists(hii, 0x02 /*FORMS*/, 0, &len, 0);
    if (s != EFI_BUFFER_TOO_SMALL || !len) { puts16("ListPackageLists falhou: "); hex(s, 16); puts16("\n"); return s; }
    if (AllocatePool(4 /*BootServicesData*/, len, (void **)&hs)) return 1;
    s = ListPackageLists(hii, 0x02, 0, &len, hs);
    UINTN nh = len / sizeof(EFI_HANDLE), i; EFI_HANDLE setupH = 0; int nfound = 0;
    puts16("handles HII com formularios: "); hex(nh, 4); puts16("\n");
    for (i = 0; s == 0 && i < nh; i++) {
        UINTN sz = 0; UINT8 *buf = 0;
        if (ExportPackageLists(hii, hs[i], &sz, 0) != EFI_BUFFER_TOO_SMALL || !sz) continue;
        if (AllocatePool(4, sz, (void **)&buf)) continue;
        if (ExportPackageLists(hii, hs[i], &sz, buf) == 0 && has_formset(buf, sz, &gSetupFs)) {
            setupH = hs[i]; nfound++;
            puts16("  formset Setup 7B59104A no handle "); hex((UINT64)hs[i], 16); puts16(" (pacote "); hex(sz, 8); puts16(" bytes)\n");
        }
        FreePool(buf);
    }
    FreePool(hs);
    if (nfound != 1) { puts16("Formset Setup nao encontrado exatamente 1 vez -> abortado.\n"); return 0; }
    if (listar) { puts16("Modo listar: nada foi aberto.\n"); return 0; }

    puts16("Abrindo FormId "); hex(formId, 4);
    puts16(" ...\n  Para sair SEM gravar: ESC e escolha descartar (Discard / No).\n");
    UINTN action = 0;
    s = ((FN_SENDFORM)sf)(fb2, &setupH, 1, &gSetupFs, (UINT16)formId, 0, &action);
    /* o navegador pode ter limpado a tela */
    puts16("\nSendForm retornou status="); hex(s, 16); puts16(" ActionRequest="); hex(action, 2); puts16("\n");
    puts16("Se voce SALVOU algo, digite 'reset' para reiniciar. Se nao salvou, nada mudou.\n");
    return 0;
}
