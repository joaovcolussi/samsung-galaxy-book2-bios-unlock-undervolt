# Engenharia reversa — ACPI, Intel DTT e interface Samsung (SCAI/EC)

Galaxy Book2 NP550XED, BIOS P11RGK.050. Análise **somente leitura** (04/11/2026).

## Fontes
- **Tabelas da BIOS:** extraídas do dump do chip (UEFIExtract), em `acpi\firmware\*.aml`, decompiladas com iasl 20260408 (ACPICA oficial) em `acpi\dsl\*.dsl`.
- **Tabelas ao vivo:** lidas do Windows via `GetSystemFirmwareTable`, em `acpi\live\`.
  - O DSDT ao vivo é idêntico ao do firmware (435 618 bytes).
  - A API do Windows só devolve o 1º SSDT, que é justamente o `DptfTabl` (DTT, 14 191 bytes) e também bate com o firmware.
  - A tabela MSDM (chave do Windows) foi descartada de propósito.
- **Data vault do DTT (GDDV):** extraído e descomprimido em `acpi\gddv\`.
  - `gddv_Default_payload.bin` e `gddv_PLID_0x1B_payload.bin`.
  - Decodificados em `*_decodificado.txt`.
  - Parsers: `parse_gddv.py` e `decode_esif.py`.

## 1. Intel DTT (IPF): de onde vêm os 12 W / 13–16 W

### Ativação
O dispositivo `\_SB.IETM` (INTC1041) só aparece para o sistema se `\DPTF == 1 && \IN34 == 1`, conforme o `_STA` em `SSDT_DptfTabl`.
- `DPTF` é a cópia, na memória da ACPI (NVS), da opção **Setup 0x6D2** ("Intel Dynamic Tuning Technology").
- Com **Setup 0x6D2 = 0**, o IETM retorna `_STA = 0` e os drivers DTT/IPF **não carregam**. Ninguém mais reescreve o limite no MMIO.
- `TCPU` (participante processador) depende de `\SADE` (Setup 0x6D4 "Processor Thermal Device").
- `SNS1`/`SNS2` (termistores do EC) estão fixos ligados (`_STA = 0x0F`).

### Data vault (GDDV)
O método `\_SB.IETM.GDDV` escolhe entre dois vaults pelo `PLID` (ID da plataforma, no NVS):

| Vault | O que é | Conteúdo |
|---|---|---|
| `PLID == 0x1B` | Referência da Intel (RVP) | PPCC de 28–30 W, sensores CHRG/SEN3 |
| **Default** | **O da Samsung** | Bate com as medições: modos high/optimize/silent, sensores SNS1/SNS2 |

**Formato do vault:**
- Cabeçalho de 0x94 bytes (`E5 1F 94 00`, "gddv", "OEM Exported DataVault").
- **SHA-256** em 0x6C, calculado sobre os dados a partir de 0x94.
- Corpo **LZMA (formato alone)** a partir de 0x94.
- Dentro dele, outro cabeçalho "dptf" com seu próprio SHA-256 do conteúdo.
- Registros chave/valor: `u16 0xA0D8, u32 ns, u32 klen, key, u32 type, u32 vlen, val`.

**Não há assinatura, só hashes recalculáveis.** Um vault alterado pode ser reconstruído. Não foi verificado se o driver do Windows aceita um vault alterado.

### Tabelas do vault Samsung
- **PPCC (TCPU):** PL1 **mín. 12 000 / máx. 20 000 mW**, janela de tempo 23–32 s, passo 250 mW. PL2 64 000 mW.
  - Este PPCC do vault **substitui** o `TCPU.PPCC` da ACPI (aquele usa `\_SB.PL10/PL20`, que vêm do cTDP Nominal da BIOS).
- **APAT (ações por modo):**

| Modo Samsung (ODV0) | PL1MAX | PL1MIN | Tabela PSVT |
|---|---|---|---|
| Alto desempenho (0x15 = 21) | 20 000 | **13 000** | `high` |
| Otimizado (0x02) | 20 000 | **12 000** | `optimize` (+ SystemMode 1) |
| Silencioso (0x0A) | 20 000 | **10 000** | `silent` |

- **APCT (condições):** a condição 19 (OEM variable 0 = ODV0) igual a 21, 2 ou 10 escolhe a ação.
- **PSVT (política passiva):**
  - Fonte: `TCPU`, alvo: termistor **`SNS2`** do EC.
  - Limite passivo: **52,0 °C** (high), **51,0 °C** (optimize), **49,0 °C** (silent).
  - Amostragem de 8 s, botão de controle 65536 (PL1), passo 250 mW, até "MAX" de restrição.
- **Trip points do vault:** `_psv` = 3632 (90,0 °C) para SNS1/SNS2 e TCPU; `_crt` e `_hot` desativados.

**Conclusão:**
- Com o DTT ligado, o PL1 **nunca passa de 20 W** em nenhum modo.
- Como o SNS2 passa de ~51 °C em carga, o DTT desce o PL1 até o **mínimo do modo**: 12 W no Otimizado, 13 W no Alto desempenho. Era exatamente o que o HWiNFO mostrava como "PL1 Dynamic".
- Os 16 W vistos logo depois da troca de modo eram o DTT ainda descendo do máximo de 20 W.

## 2. Interface Samsung: SCAI (`SAM0429`) e EC
- **Modo de desempenho:** `\_SB.SCAI.PRF3`, chamada Samsung `SAFN 0x5843`, `SASB 0x91`, `FNCN 0x51`.
  - `SUBN 1`: lista os modos suportados: **0, 1, 2, 0x0A, 0x14, 0x15**.
  - `SUBN 2`: lê o modo atual (`PFMD`).
  - `SUBN 3`: grava o modo. Faz `PFMD = modo` e chama `CHOV(0, modo)`, que grava ODV0 e notifica o IETM (0x88).
  - Para todo modo **exceto 0x02 (Otimizado)**, também manda ao EC o comando `CMDD(0xEE, 2, {0x80, modo})`, que é o **perfil da ventoinha no EC**.
- **`\_SB.IETM.IMOK`** chama `SCAI.IMOK`, que manda ao EC 0xEE {0x80,0} ou {0x80,0x0A}.
- **`_OSC` do IETM:** grava os bits `DPPF` no EC (offset 0x6E, bits 0–2) para avisar que o DTT está cuidando das políticas passiva/ativa/crítica. Sem DTT, esses bits ficam zerados: o EC fica sabendo que não há DTT.
- **Campos do EC** (OperationRegion EmbeddedControl em `H_EC`):
  - 0x50 `CMDR`, `PPSL`/`PPSH`, `PINV`/`PENV`, `PSTP`, **`CPUP` (16 bits)**
  - 0x5C–0x65 `TSR1..TSR7`/`TSD0..3` (temperaturas)
  - 0x66 `CFSP` (rotação da ventoinha)
  - 0x69 `TSI`/`HYST`/`TSHT`/`TSLT`/`TSSR` (limiares)
  - 0x6E `DPPF`
  - `CTMP` (usado pelo `_TMP` das zonas térmicas)
  - `FANS`, `VRMF`, `SCAI`
- **Ventoinha:** `FAN0` com `_DSM` "Fan Trip Points" (UUID a7611840-…) devolve a tabela `FANT`.
- **Carga da bateria e demais funções Samsung:** pelo mesmo despachante SCAI (`CSXI`/`CSFI`). O driver Linux `samsung-galaxybook` implementa essa mesma ABI (SAFN 0x5843).

## 3. Processador / limites na ACPI
- **A ACPI não escreve limite de potência:** nenhuma referência a MCHBAR+0x59A0 nas 48 tabelas.
- `TCPU` só **lê** MCHBAR+0x5930 (PKG_POWER_SKU), 0x5F3C… (níveis de cTDP) e expõe `TDPL`/`STDP` (troca de nível de cTDP), `_PSS`/`_TSS`/`_PPC`/`_TDL`/`_PDL`.
- Quem escreve o PL1 no MMIO é o driver IPF (`ipf_cpu.sys` / `ipf_uf.exe`), seguindo o vault.
- **TZ00:** `_TMP` = EC `CTMP`, `_CRT` = `CRTP`, `_PSV` = `PTTP` (Setup 0x6BC "Passive Trip Point" = 95 °C).
  - O `_PSV` só existe se `\_SB.APSV != 0`.
  - `_PSL` = todos os núcleos.
  - Sem DTT, o Windows ainda pode fazer resfriamento passivo pela ACPI aos ~95 °C: uma rede de segurança.
- **Nenhum participante de energia/carregador/bateria do DTT:** Setup 0x6DD/0x6DE/0x6E1 = 0, e não existe TPWR/CHRG no SSDT da Samsung.

## 4. Opções do Setup (NVRAM) que mudam o comportamento da ACPI
| Opção (Setup) | Offset | Valor atual | Efeito na ACPI |
|---|---|---|---|
| Intel Dynamic Tuning Technology | 0x6D2 | 1 | `\DPTF`: liga ou desliga o IETM inteiro (e com ele todo o DTT) |
| Processor Thermal Device | 0x6D4 | 1 | `\SADE`: `_STA` do TCPU |
| PPCC Step Size | 0x6D5 (4B) | 500 | `PPSZ` no PPCC da ACPI (o vault da Samsung substitui) |
| Passive / Critical Trip Point | 0x6BC / … | 95 °C | `PTTP` / `CRTP` do TZ00 |
| Design Variable 0..5 | 0x6FB–0x700 | 0 | valor inicial provável de ODV0..5 (o SCAI sobrescreve ODV0 em tempo de execução) |
| Power / Charger / Battery participant | 0x6DE / 0x6DD / 0x6E1 | 0 | desligados |

## Implicações para o biosmod
1. **Dá para fazer os modos da Samsung funcionarem só com NVRAM? Não.**
   - Os limites de modo (PL1MAX 20 W, PL1MIN 10/12/13 W, PSVT 49–52 °C no SNS2) estão no GDDV, dentro do SSDT do firmware, que é protegido pelo Boot Guard.
   - O PPCC do vault anula o PL10/PL20 que vêm da BIOS.
   - Aumentar o cTDP Nominal na BIOS **não** sobe o teto de 20 W do DTT.
2. **Por ACPI, sim, é possível em teoria.** Um driver UEFI carregado antes do boot (o Secure Boot está desligado) poderia substituir na memória o SSDT `DptfTabl`, com o GDDV reconstruído (LZMA + os dois SHA-256 recalculados + checksum da tabela).
   - Mudanças possíveis: PL1MAX/PL1MIN por modo, limites do SNS2 e PPCC.
   - Assim o seletor da própria Samsung (Fn ou Samsung Settings) controlaria limites de verdade.
   - Risco: não testado. O driver IPF pode recusar ou cachear o vault, mas não há assinatura, então é viável.
3. **DTT desligado (Setup 0x6D2 = 0):**
   - Os limites passam a ser os da BIOS (CpuSetup PL1/PL2), sem nada reescrevendo.
   - O seletor da Samsung **continua mudando o perfil da ventoinha no EC** (comando 0xEE em todos os modos menos o Otimizado). Só a parte do DTT deixa de existir.
   - Perde-se a proteção de temperatura da carcaça (SNS2).
   - O EC passa a ver `DPPF = 0` e pode usar a própria proteção (PROCHOT). O TZ00 da ACPI aos 95 °C continua como segurança.
4. **Teto de ~20 W "PBM PL2/PL3": não vem da ACPI.**
   - Não existe participante de energia ou Psys no DTT nem programação de Psys na ASL.
   - Suspeitos fora da ACPI: Psys PL (MSR 0x65C, Setup "Platform PL1/PL2" desligados = padrão do chip), PL3 (CpuSetup 0x23 = 52 W, duty 4 %, travado), o EC via PECI, ou o próprio driver IPF.
   - Para confirmar: ler os MSRs 0x615/0x65C/0x601 antes do SO (`biosmod.efi info`) e repetir o teste de carga com o DTT desligado.
