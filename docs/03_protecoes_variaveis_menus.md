# 03 — Proteções, variáveis e menus ocultos (engenharia reversa estática)

Fonte: dump do chip `bios_fd_me_bios.bin` (SHA256 122a35fc…), BIOS P11RGK.050. Análise **somente leitura**
(UEFIExtract A76, ifrextractor 1.6.1, Ghidra via REA, dumpbin MSVC). Endereços de código = RVA do módulo
(PE x64) ou endereço XIP (PEI IA32). Nada foi gravado.

---

## 1. Proteção de escrita das variáveis de Setup

### 1.1 Variable Lock / Variable Policy
- **Variable Policy**: nenhum módulo referencia o GUID 81d1675c-… → não existe.
- **EDKII Variable Lock** (cd3d0a05-…): varri todos os 416 módulos e resolvi cada `RequestToLock`.
  Variáveis travadas no EndOfDxe:
  | Módulo | Variável travada |
  |---|---|
  | EsrtDxe | EsrtFmp, EsrtNonFmp |
  | Smbios | SmbiosEntryPointTable(+V3, F000), SmbiosScratchBuffer, MaximumTableSize |
  | AmiTcgPlatformDxe / Tpm20PlatformDxe / Tcg2Dxe | TPMPERBIOSFLAGS, AMITCGPPIVAR, TpmServFlags |
  | CapsuleRuntimeDxe | CapsuleLongModeBuffer |
  | RstUefiDriverSupport | IntelRstFeatures |
  | AdvancedAcpiDxe (@0x19A8) | S3MemoryVariable |
  | HstiResultDxe | HSTI_RESULTS |
  | SaveMemoryConfig | MemoryConfig |
  | Setup (13 KB) | TcgNvmeVar |
  | CnvUefiVariables | as próprias variáveis CNV/Wi-Fi |
  | NbDxe | só localiza o protocolo, **não** chama RequestToLock |
- **Nenhum módulo trava `Setup`, `CpuSetup`, `SaSetup` ou `PchSetup`.**

### 1.2 Filtro AMI/Samsung no NvramDxe (SetVariable hook, FUN_0000a6a4)
- Lê `Setup[0xC44]` = **"Password protection of Runtime Variables"** (IFR, VarStore Setup). Valor atual **0**
  → o filtro retorna EFI_UNSUPPORTED (passa adiante) na primeira linha.
- Se estivesse ativo, com senha de administrador definida e `NvLockMailbox == 1`, bloquearia com
  EFI_SECURITY_VIOLATION apenas: `Setup`, `AMITSESetup` e `NetworkStackVar` (tabela de 4 entradas).
  **CpuSetup/SaSetup/PchSetup nunca estão na lista.**
- O hook encadeado FUN_0000a550 só trata `$SETUPPASSWD` e `$SETUPPASSWDANY` (senha).
- **Recomendação:** não definir senha de supervisor na BIOS e manter `Setup[0xC44] = 0`.

### 1.3 Atributos e integridade
- NVAR attr 0x82 (sem Runtime) → só BS|NV. O Windows/Linux não escreve; o **UEFI Shell (antes do
  ExitBootServices) escreve normalmente**.
- Nenhum checksum ou assinatura sobre Setup/CpuSetup foi encontrado.
- `SecSetupLoadDefault`: no ReadyToBoot zera o **CMOS índice 0x4E** (flag "carregar padrões") e checa
  o HOB 3FCA54F6-E1A2-4B20-BE76-926B4B48BFAA. Os padrões só voltam por **F9**, por falha de RTC/CMOS
  (`SecRtcFailure*`) ou por esse flag. Nesses casos os mods se perdem e é só reaplicar.
- NVRAM principal quase cheia (0x21 bytes livres): a próxima escrita fará reclaim AMI (normal).

### 1.4 SecSetupWinSmm (Windows → BIOS via SMI)
Lista branca fixa, sem escrita genérica:
- Touchpad: Setup 0xC5C
- Senhas de supervisor/usuário
- Password On Boot: AMITSESetup 0x51
- TPM: Setup 0x12, 0x0E e 0x1A
- Select Boot Device
- Fast BIOS Mode: Setup 0x01
- PXE: Setup 0xC70
- Secure Boot Control

**Não serve** para gravar opções de CPU pelo Windows.

### Veredito
**setup_var.efi (datasone), rodando no UEFI Shell, deve funcionar** para CpuSetup, SaSetup e PchSetup
sem restrições. Para Setup (ex.: DTT 0x6D2) também funciona, desde que `Setup[0xC44] = 0` e não haja
senha de supervisor.

---

## 2. Boot Guard e faixas protegidas

- **FIT:** Startup ACM em FFEC0000 (SVN 3), KM em FFF64F80 (KmSvn 0), BPM em FFF64A80. Hash da chave
  OEM (SHA256) E30601D7…7FDE0.
- **IBB (verificado pelo ACM):** 0xD50000–0xEC0000, 0xF00000–0xF64A80 e 0xF65380–0x1000000.
- **Arquivo de hash AMI v2** (FFS CBC91F44, em 0xF49ED0, dentro do IBB). Faixas confirmadas
  **recalculando o SHA256** = 8B50F175…F036:
  - 0x5E2000 + 0xA4 (cabeçalho do FV DXE)
  - 0x5E30A4 – 0x886600 (volume DXE principal: Setup, AMITSE, NvramDxe…)
  - 0x940000 – 0x9E0C00
  - O aviso "hash mismatch" do UEFIExtract é **bug do parser** (ele lê o tamanho como 0xFF5E30A4).
- **BootGuardPei** (convertido de TE para PE e analisado): lê o MSR 0x13A bit 0 (ACM ativo). Se ativo,
  localiza o arquivo de hash, faz SHA256 das faixas e compara 32 bytes; se não bater, entra em laço
  infinito (FUN_fff290b3). Também copia KM/BPM (FIT tipos 0x0B/0x0C) para um HOB.
- **A NVRAM (0x500000–0x55FFFF) não é coberta**, como esperado. É por isso que o mod por NVRAM é seguro.
- **Lacuna possível (NÃO validada em hardware):** estes volumes não aparecem cobertos nem pelo IBB nem
  pela lista AMI v2, e não existe FvReportPei/StoredHashFv:
  - 0xBE0000 FV 3DA4F21C: PEI pós-memória (CpuPei, PlatformInitPostMem, SiliconPolicyPeiPostMem,
    BiosGuardVerifyRomImage…)
  - 0xCA0000 FV 8C8CE578: FSP-S
  - 0x572000: Application F1749ADE
  - 0x5C2000: freeform
  - 0x540000–0x560000
  Explorar isso exigiria programador SPI externo (BIOS Guard, SMM_BWP e SPI lockdown bloqueiam a
  gravação interna). Risco alto de brick, então **não recomendado**: fica só documentado.
- **Tabela RomLayout AMI** ("ROML" em 0xF3BCFC, 15 áreas). O bit 0x400 aparece no IBB e no FV
  pós-memória, mas não no DXE (0x0228).
- O estado final dos fusíveis vem do MSR 0x13A em runtime (outra ferramenta).

---

## 3. Menus ocultos: como funcionam e como liberar

- A IFR tem um **formset único** "Setup" (7B59104A). A raiz (Form 0x2710) tem 11 Refs **sem SuppressIf**:
  - AMI/Intel: Main 0x2711, Advanced 0x2712, Chipset 0x2714, Security 0x2715, Boot 0x2716, Save&Exit 0x2717
  - Samsung: SysInfo 0x2718, Advanced 0x2719, Security 0x271A, Boot 0x271B, Exit 0x271C
- `AMITSESetupData` (pacote "$SPF", 505 KB descomprimido): as 116 páginas têm PageFlags = 0 e os 11
  controles da raiz têm flags idênticas. **A ocultação não está nos dados** (AMIBCP não resolveria).
- `SecSetupFlag` (02 01 00 01 01 00 04) só guarda contagens de hardware para a tela SysInfo
  (slots de memória, SATA, NVMe, compra, WLAN wake). **Não destrava nada.**
- **Mecanismo real:** AMITSE (B1DA0ADF), função em RVA **0xB08AA**.
  - Percorre a tabela de abas em 0x1B5480 (formIDs 0x2711–0x271B).
  - Em 0xB08E3 chama `PCD->Get8(EEE8EEBE-2885-41B7-AAC4-EBACF7F8CDFE, 0x5A5A0012)`.
  - Se o valor for ≠ 0, **não promove** 0x2711–0x2717 (menos 0x2713) a abas de topo. A promoção normal
    é a escrita `ParentPageID = 0` em 0xB094D. Resultado: as abas AMI ficam ocultas.
- **Origem da PCD:** `SiliconPolicyPeiPreMem` faz Set8 (0xFFF250EF) a partir do **GPIO pad 0x09030006**,
  um strap de hardware. Por isso **nenhuma variável NVRAM destrava os menus**.
- **Segundo portão (a investigar):** a função em 0xB0738/0xB0761 lê o byte de flash em **0xFF5401F0**
  (offset 0x5401F0, fora das faixas protegidas). Se for '$' e o global [0x258FA0] for 'M'
  ("manufacturing mode"?), ela altera o bit 0 das páginas 0x2712/0x2714.

**Caminhos de liberação (nenhum grava firmware):**
1. **(Recomendado) Driver UEFI mínimo** carregado via `Driver####`/`DriverOrder` (ou `load` no shell):
   `gEfiPcdProtocol->Set8(&{EEE8EEBE-2885-41B7-AAC4-EBACF7F8CDFE}, 0x5A5A0012, 0)` antes do F2.
   - Sem patch de código; vale só até o próximo reset.
   - Ainda precisa confirmar em runtime que o Set8 retorna sucesso.
   - Os consumidores PEI (SiliconPolicyPeiPreMem, SiInitPreMemFsp, SecEcPei) já rodaram, então só o
     AMITSE é afetado.
2. **Patch em memória estilo SREP no AMITSE** (fallback):
   - Padrão: `FF 50 08 84 C0 74 21 B8 13 27 00 00` (RVA 0xB08E3)
   - Trocar `74 21` por `EB 21` (salto incondicional, trata como "não oculto")
   - Aplicar depois que o AMITSE carregar e antes de montar as páginas.
- **Risco:** o menu completo expõe opções perigosas (memória, PCIe, ME). Ter sempre o backup e o F9.

---

## 4. Outros módulos úteis
- **SecSabiDispatchSmm:** interface SW-SMI "SABI" da Samsung, usada pelo Samsung Settings
  (ThermalOffStatus, PxeBootBySabi, datas, SecMeProt). Referencia Setup e SaSetup.
- **SecSetupValueToEc:** envia valores do Setup ao EC no boot.
- **SecEcDxe, SecEcSmm, SecEcSmiDispatchSmm:** comunicação com o EC (ThermalOffStatus, WDT, warm boot).
- **SecThermalDxe e SecPerformanceDxe:** pequenos, ligados a modo térmico/desempenho.
- **SamsungEcUpdateDxe:** atualização de firmware do EC/PD (exige bateria conectada).
- **SecBatInfoSmbios:** dados da bateria no SMBIOS.
- A proteção de bateria a 80% é Carregamento Inteligente do Windows, não BIOS.
- **Não existe "Undervolt Protection"** na IFR. O undervolt depende só do OC Lock (CpuSetup 0x10E).
- **VerifyFwBootGuard (SMM):** analisa a `_FIT_` durante o flash por SMI e recusa imagens cujos KM/BPM
  não batam. Impede gravar BIOS modificada por software.
