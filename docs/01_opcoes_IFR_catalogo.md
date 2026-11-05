# Catálogo de opções da BIOS úteis para o biosmod (NVRAM / setup_var)

Samsung Galaxy Book2 NP550XED, BIOS P11RGK.050. Gerado em 04/11/2026 a partir do **firmware lido do chip** (`bios_fd_me_bios.bin`).
Análise somente leitura, sem nenhuma gravação.

## Como foi feito
- **IFR completo do módulo `Setup`:** 4.536 perguntas. Também do `PciDynamicSetup` (5 perguntas).
- **Outros módulos com menus HII:** ReFlash/Recovery, Media Sanitization, Intel RST, Realtek LAN, Ip4/Ip6, TLS e o "PCI Resource ERROR". Nenhum tem opção útil de desempenho; só o `PciDynamicSetup` (Above 4G / ReBAR) entrou na lista.
- **Valor atual:** vem da NVRAM ativa (store 0x500000). Variável ausente da store ativa (ex.: `PCI_COMMON`, `SiSetup`) significa que vale o `StdDefaults`.
- **Lista completa legível por máquina:** `01_opcoes_IFR_todas.csv` (separador `;`), com varstore, GUID, offset, tamanho, atual, padrão do IFR, padrão da NVRAM, faixa, opções, condições SuppressIf/GrayOutIf avaliadas e texto de ajuda.
- **Alcance dos formulários:** `01_formularios_alcance.csv`.
- **Visibilidade:** a coluna `visivel_no_menu` vale para a **árvore Aptio** do IFR. A tela F2 da Samsung mostra um subconjunto ainda menor. Mesmo assim, **toda variável listada pode ser gravada via setup_var**, apareça no menu ou não.
- **Condições não avaliáveis:** as que dependem de variáveis voláteis criadas em tempo de boot (`SetupCpuFeatures`, `SetupVolatileData`, `CpuSetupVolatileData`) ficam como "?".
- **Gravação:** `setup_var.efi <Var>:<offset>(<tam>)=<valor>`, com valores multibyte em little-endian. O tamanho vem da coluna "Tam".

Legenda de risco: 🟢 baixo/reversível pelo F9 · 🟡 médio (instabilidade, resolvido com F9) · 🔴 **PERIGOSO** (pode impedir o POST e exigir CH341A ou reset da CMOS).

---

## A. Potência (limites RAPL)
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| CpuSetup | 0x017 | 4 | 20000 | 20000 | 0–4095875 mW | PL1 (menu "Samsung Debug Option"). 🟢 |
| CpuSetup | 0x01B | 1 | 1 | 1 | 0/1 | PL1 Override. 🟢 |
| CpuSetup | 0x01C | 1 | 28 | 28 | 0–128 s | Tau (PL1 Time Window). 🟢 |
| CpuSetup | 0x01D | 1 | 1 | 1 | 0/1 | PL2 Override. 🟢 |
| CpuSetup | 0x01E | 4 | 0 | 0 | mW (0 = automático) | PL2. 🟢 |
| CpuSetup | 0x05B/0x05F/0x063 | 4/4/1 | 20000/44000/0 | — | mW / s | cTDP **Nominal** PL1/PL2/Tau: é esse o valor que vale, porque cTDP = 1 e o boot é Nominal. 🟢 |
| CpuSetup | 0x065/0x069 · 0x06F/0x073 | 4 | 20000/44000 | — | mW | cTDP Level1 / Level2 PL1/PL2. 🟢 |
| CpuSetup | 0x227 | 1 | 1 | 1 | 0/1 | Enable Configurable TDP. 🟢 |
| CpuSetup | 0x044 | 1 | 0 | 0 | 0 = Nominal, 1 = Down | cTDP Boot Mode. 🟢 |
| CpuSetup | 0x045 | 1 | 0 | 0 | 0/1 | Configurable TDP Lock (destravado). 🟢 |
| CpuSetup | 0x030 | 1 | 0 | 0 | 0/1 | **Package Power Limit MSR Lock**: travaria o MSR 0x610. Manter 0 para o SO/Kali poder ajustar. 🟢 |
| CpuSetup | 0x022 | 1 | **1** | 1 | 0/1 | PL3 Override (ligado). 🟢 |
| CpuSetup | 0x023 | 4 | **52000** | 52000 | mW | PL3 = 52 W (limite de pico). Não é o teto de 20 W visto nos testes. 🟢 |
| CpuSetup | 0x027 / 0x028 | 1/1 | 64 / 4 | — | — | PL3 Time Window / Duty Cycle. 🟢 |
| CpuSetup | 0x029 | 1 | **1** | 1 | 0/1 | **PL3 Lock = 1** (MSR 0x615 travado). 🟢 |
| CpuSetup | 0x02A / 0x02B | 1/4 | 1 / 123000 | 1 / 123000 | mW | PL4 Override / PL4 = 123 W. 🟡 Reduzir ajuda na bateria (evita desligamento por pico). |
| CpuSetup | 0x02F | 1 | 0 | 0 | 0/1 | PL4 Lock. 🟢 |
| CpuSetup | **0x031** | 1 | **0** | 0 | 0/1 | **Platform (Psys) PL1 Enable**: desligado, a BIOS não programa. 🟢 |
| CpuSetup | 0x032 / 0x036 | 4/1 | 0 / 0 | — | mW / s | Platform PL1 Power / Time Window. Ficam ocultos enquanto 0x031 = 0. |
| CpuSetup | **0x037** | 1 | **0** | 0 | 0/1 | **Platform (Psys) PL2 Enable**: desligado. |
| CpuSetup | 0x038 | 4 | 0 | 0 | mW | Platform PL2 Power. |
| CpuSetup | 0x12B | 2 | 1152 | 1152 | 1/8 W (1152 = 144 W) | PSYS PMax. 🟡 |
| CpuSetup | 0x127 / 0x128 / 0x12A | 1/2/1 | 0/0/0 | — | — | PSYS Slope / Offset / Prefix (calibração do sensor Psys). 🟡 |
| CpuSetup | 0x2AD | 1 | 0 | 0 | 0/1 | Dual Tau Boost. Deixa o DTT cinza; só visível em certas SKUs. |

> **Teto de ~20 W "PBM PL2/PL3" dos testes:** a BIOS **não** programa Psys (0x031 = 0x037 = 0) e o PL3 é 52 W. Esse limite, portanto, vem de fora da configuração da BIOS: DTT (Power Boss / PPCC) ou EC. O teste com o DTT desligado confirma.

## B. Undervolt / overclock (FIVR)
Todos os formulários **Processor / Ring / GT / Uncore / CEP Disable / VR ICCMAX Override** ficam sob `SuppressIf OverClocking Feature (0x1D9) == 0`. **Na prática, sem OC Feature = 1 a BIOS não aplica esses valores** (é o padrão do Intel RC). Além disso, sem **OC Lock (0x10E) = 0** o próprio processador recusa offsets vindos do SO.

| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| CpuSetup | **0x10E** | 1 | **1** | 1 | 0/1 | **Overclocking Lock** (bit 20 do MSR 0x194). 0 = permite undervolt pelo SO e pela BIOS. 🟢 |
| CpuSetup | **0x1D9** | 1 | **0** | 0 | 0/1 | **OverClocking Feature**: libera e aplica o menu OC. 🟡 |
| CpuSetup | 0x232 | 1 | 0 | 0 | 0 = Legacy, 1 = Selection | VF Offset Mode, P-core/IA. Legacy = offset global. Fica cinza se 0x233 = 0. |
| CpuSetup | 0x261 | 1 | 0 | 0 | 0 = All-core, 1 = Per-core | VF Configuration Scope. |
| CpuSetup | **0x1E0** | 2 | 0 | 0 | 0–1000 mV | **P-core (IA) Voltage Offset**, global no modo All-core. 🟡 |
| CpuSetup | **0x1E2** | 1 | 0 | 0 | 0 = +, 1 = − | Sinal do offset acima (1 = undervolt). 🟡 |
| CpuSetup | 0x262…0x270 / 0x272…0x279 | 2/1 | 0 | 0 | mV / sinal | Offsets por P-core 0–7. Só com escopo Per-core (0x261 = 1). |
| CpuSetup | 0x315/0x317/0x319/0x31B | 2 | 0 | 0 | mV | E-core Cluster 0–3 Voltage Offset. **Só aparecem/valem com 0x261 = 1 (Per-core)**. |
| CpuSetup | 0x31D…0x320 | 1 | 0 | 0 | 0 = +, 1 = − | Sinal dos clusters E-core. |
| CpuSetup | 0x234…0x250 / 0x252…0x25F | 2/1 | 0 | 0 | mV | 15 pontos da curva VF (modo Selection). 🟡 |
| CpuSetup | **0x1EC / 0x1EE** | 2/1 | 0/0 | 0 | mV / sinal | **Ring (cache) Voltage Offset**. No ADL-U o ring divide o trilho com os núcleos: use o **mesmo** offset do IA. 🟡 |
| CpuSetup | 0x27C | 1 | 0 | 0 | Legacy/Selection | VF Offset Mode do Ring. |
| SaSetup | 0x25F / 0x261 | 2/1 | 0/0 | 0 | mV / sinal | Uncore (SA) Voltage Offset. 🟡 Ganho pequeno; risco de instabilidade de memória/iGPU. |
| SaSetup | 0x264 / 0x266 | 2/1 | 0/0 | 0 | mV / sinal | GT (iGPU) Voltage Offset. 🟡 |
| SaSetup | 0x26D / 0x26F | 2/1 | 0/0 | 0 | mV / sinal | GTU (media) Voltage Offset. 🟡 |
| CpuSetup | 0x1E5 | 1 | 0 | 0 | 0–31 bins | AVX2 Ratio Offset. 🟢 |
| CpuSetup | 0x225 | 1 | 100 | 100 | 0–200 (/100) | AVX2 Voltage Guardband Scale. 🟡 Abaixar = menos tensão em AVX; pode travar. |
| CpuSetup | **0x334** | 1 | **1** | 1 | 0/1 | **IA CEP Enable** (Current Excursion Protection). Com undervolt grande, desligar evita *clock stretching*. 🟡 |
| CpuSetup | 0x335 | 1 | 1 | 1 | 0/1 | GT CEP Enable. 🟡 |
| CpuSetup | 0x347 / 0x346 | 2/1 | 4 / 0 | — | 1/4 A / 0–1 | IA IccMax Override / IA ICC Unlimited Mode. 🔴 Ver lista de perigosas. |
| CpuSetup | 0x34A / 0x349 | 2/1 | 4 / 0 | — | — | GT IccMax Override / Unlimited. 🔴 |
| CpuSetup | 0x187 / 0x189 / 0x18B | 2 | 320 / 160 / 160 | — | 1/4 A (80 A / 40 A / 40 A) | VR Current Limit (IccMax) IA/GT/SA. Fica cinza com OC Feature = 1. 🔴 |
| CpuSetup | 0x19B / 0x191 / 0x1A0 / 0x1B4 | 1/2/4/1 | 1 / 344 / 1 ms / 0 | — | — | IA TDC Enable / Limit (1/8 A: 43 A) / Window / Lock. 🟡 |
| CpuSetup | 0x19C / 0x193 / 0x1A4 | 1/2/4 | 1 / 184 / 1000 | — | — | GT TDC Enable / Limit / Window. 🟡 |
| CpuSetup | 0x12D/0x12E/0x12F | 1 | 1 | 1 | 0/1 | VR Config Enable IA/GT/SA. 🔴 Não desligar. |
| CpuSetup | 0x1DD / 0x1DE | 1/2 | 0 / 0 | — | Adaptive/Override, mV | Core Voltage Mode / **Override** (tensão fixa). 🔴 |
| CpuSetup | 0x1E9 / 0x1EA | 1/2 | 0 / 0 | — | — | Ring Voltage Mode / Override. 🔴 |
| CpuSetup | 0x2DE / 0x2DF | 1/2 | 0 / 0 | — | — | Uncore Voltage Mode / Override. 🔴 |
| SaSetup | 0x263 / 0x267 | 1/2 | 0 / 0 | — | — | GT Voltage Mode / Override. 🔴 |
| CpuSetup | 0x207 / 0x208 / 0x20A | 1/2/2 | 0 | — | mV | Min Voltage Override / Runtime / C8. 🔴 |
| CpuSetup | 0x336 / 0x337 | 1/2 | 0 / 1800 | — | 1620–1900 mV | VCCIN AUX CPU override. 🔴 |
| CpuSetup | 0x2F7 / 0x20D / 0x344 | 4/1/1 | 0 / 1 / 0 | — | — | BCLK OC / BCLK-aware AVP / TSC fixup. 🔴 |
| CpuSetup | 0x352 / 0x353 | 1/1 | 0 / 0 | — | — | FLL Overclock Mode. 🔴 |

## C. Térmico / PROCHOT
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| CpuSetup | 0x07F | 1 | **6** | 6 | 0–63 °C | **TCC Activation Offset**: corta clock em TjMax(100) − 6 = **94 °C**. 0 = 100 °C. 🟡 Com metal líquido dá para ir a 3–4; 0 deixa a carcaça muito quente. |
| CpuSetup | 0x1C8 / 0x1CC / 0x1CD | 4/1/1 | 0 / 0 / **1** | — | — | Tcc Offset Time Window / Clamp / **Lock** (trava o MSR 0x1A2; com 0 o SO pode ajustar). 🟢 |
| CpuSetup | 0x1F8 | 1 | 0 | 0 | 0–63 | TjMax Offset (no menu OC). 🟡 |
| CpuSetup | 0x07A / 0x07B | 1/1 | 1 / 1 | 1 | 0/1 | Bi-directional PROCHOT# / Disable PROCHOT# output. 🔴 **Não** desligar o bidirecional: é por ele que o EC protege VRM, carregador e carcaça. |
| CpuSetup | 0x07E / 0x07D | 1/1 | 1 / 1 | — | — | PROCHOT Response / PROCHOT Lock. 🟡 |
| CpuSetup | 0x07C | 1 | 0 | 0 | 0/1 | Disable VR Thermal Alert. 🔴 |
| CpuSetup | 0x2E3 / 0x2E4 / 0x378 | 1 | 1 / 1 / 1 | 1 | 0/1 | TVB / TVB Voltage Opt / Enhanced TVB. 🟢 |
| CpuSetup | 0x34F / 0x350 | 1 | 70 / 100 | — | °C | TVB Temperature Thresholds. 🟢 |
| CpuSetup | 0x1F1 | 1 | 1 | 1 | 0/1 | Enable All Thermal Functions. 🔴 Não desligar. |
| Setup | 0x6BC | 1 | 95 | 95 | °C | ACPI Passive Trip Point: o Windows reduz clock a 95 °C pela zona térmica. 🟡 |
| Setup | 0x6BD | 1 | 119 | 119 | °C | ACPI Critical Trip (desliga). 🔴 Não subir. |
| Setup | 0x6B9/0x6BB · 0x6B8/0x6BA | 1 | 71/100 % · 55/75 % | — | °C / % | Active Trip Points 0/1 e velocidade da ventoinha nas zonas ACPI. 🟡 Provavelmente o EC da Samsung é quem manda na ventoinha; efeito incerto. |
| Setup | 0x6D0 / 0x6D1 | 1 | 72 / 65 | — | — | Platform Thermal "CPU Temp" / "CPU Fan Speed" (valores de referência). |

## D. Turbo / HWP / P-states
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| CpuSetup | 0x013 | 1 | 1 | 1 | 0 = Max Battery, 1 = Max Non-Turbo, 2 = Turbo | Boot performance mode. 🟢 |
| CpuSetup | 0x016 | 1 | 1 | 1 | 0/1 | Turbo Mode. 🟢 |
| CpuSetup | 0x009 / 0x00B | 1 | 1 / 1 | 1 | 0/1 | SpeedStep / **Speed Shift (HWP)**. 🟢 Manter 1: os modos do Windows dependem disso. |
| CpuSetup | 0x00C | 1 | 1 | 1 | 0/1 | Turbo Boost Max 3.0. 🟢 |
| CpuSetup | 0x00E / 0x00F / 0x010 | 1 | 1 / 1 / 1 | 1 | 0/1 | Per-core P-state OS / HWP autonomous per-core / EPP grouping. 🟢 |
| CpuSetup | 0x012 | 1 | 0 | 0 | 0/1 | HwP Fast MSR. 🟢 |
| CpuSetup | **0x228** | 1 | **1** | 1 | 0/1 | **HwP Lock**: trava parte da configuração HWP. O EPP por pacote continua ajustável. 🟢 |
| CpuSetup | 0x20C | 1 | 1 | 1 | 0/1 | Speed Shift Interrupt Control. 🟢 |
| CpuSetup | 0x00A | 1 | 1 | 1 | 0/1 | Race To Halt. 🟢 |
| CpuSetup | **0x1D5** | 1 | **1** | 1 | 0/1 | **Energy Efficient Turbo**: em carga leve reduz o turbo por eficiência. 0 = turbo mais agressivo, pouco mais de consumo. 🟢 |
| CpuSetup | 0x03C | 1 | 1 | 1 | 0/1 | Energy Efficient P-state. 🟢 |
| SaSetup | 0x075 | 1 | 0 | 0 | 0/1 | Energy Performance Gain. 🟢 |
| CpuSetup | 0x04A | 1 | 1 | 1 | 0/1 | HDC Control. 🟢 |
| CpuSetup | 0x0D6…0x0DD / 0x0E6…0x0ED | 1 | 47,41×7 / 1…8 | 0 (a BIOS preenche) | ratio | P-core Turbo Ratio Limits (47 = 4,7 GHz em 1 núcleo; 41 em 2+). Subir não funciona: é limitado por fusível no 1255U. |
| CpuSetup | 0x0F6…0x0FD / 0x106…0x10D | 1 | 35 / 1…8 | 0 | ratio | E-core Turbo Ratio Limits (3,5 GHz). |
| CpuSetup | 0x005 / 0x006 / 0x22F | 1 | 1 / 255 / 255 | — | — | Hyper-Threading / núcleos P e E ativos. 🟡 |
| CpuSetup | 0x2DC | 1 | 0 | 0 | 0 = Enabled | AVX. 🟢 |

## E. C-states / latência / S0ix
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| CpuSetup | 0x014 | 1 | 1 | 1 | 0/1 | C states. 🟡 Desligar aumenta muito o consumo em repouso e quebra o Modern Standby. |
| CpuSetup | 0x015 | 1 | 1 | 1 | 0/1 | C1E. 🟢 |
| CpuSetup | **0x04B** | 1 | 255 | 255 | 0 = C0/C1 … 8 = C10, 254 = CPU default, 255 = Auto | **Package C State Limit**. 🟡 Limitar a C3 ou C6 reduz latência, mas gasta bateria. |
| CpuSetup | 0x03D…0x041 | 1 | 1 | 1 | 0/1 | Pre-wake / auto-demotion / un-demotion (core e package). 🟢 |
| CpuSetup | 0x114 | 1 | 1 | 1 | 0/1 | C6DRAM. 🟢 |
| Setup | 0x03D | 1 | 1 | 1 | 0/1 | Low Power S0 Idle (Modern Standby). 🔴 **Não desligar**: o suspender do Windows 11 neste notebook provavelmente depende dele (não verificado se há S3). |
| Setup | 0x03E…0x051 etc. | 1 | — | — | — | Restrições PEP (S0ix) por dispositivo. 🟡 |

## F. Intel DTT (Dynamic Tuning) — Setup
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| Setup | **0x6D2** | 1 | **1** | 1 | 0/1 | **Intel DTT**: 0 = a BIOS não expõe IETM/participantes e nada no SO reescreve PL1/PL2. 🟡 Sem proteção de temperatura da carcaça; os modos Samsung talvez percam efeito na potência. |
| Setup | 0x6D3 | 1 | 5 | 5 | — | "DTT Configuration" (perfil/versão). |
| Setup | 0x6D4 | 1 | 1 | 1 | 0/1 | Processor Thermal Device (B0:D4, participante do processador). 🟡 |
| Setup | 0x6E2 | 1 | 1 | 1 | 0/1 | INT3400 (IETM, o gerenciador). 🟡 |
| Setup | 0x6D5 | 4 | 500 | 500 | mW | PPCC Step Size. 🟢 |
| Setup | 0x6EF / 0x6F0 / 0x6F1 | 1 | 0 / 0 / 0 | 0 | 0 = Enabled | Objetos ACPI PPCC / ARTG / PMAX. 🟡 |
| Setup | 0x6DC / 0x6DD / 0x6DE / 0x6E1 / 0x6EE | 1 | 0 | 0 | 0/1 | Participantes Fan1 / Charger / Power / Battery / PCH FIVR (todos desligados). |
| Setup | 0x6E9…0x6ED | 1 | 0 | 0 | 0/1 | Sensor Device 1–5. Os participantes SNS1/SNS2 que aparecem no Windows vêm de outra origem (ACPI da Samsung). |
| Setup | 0x6FB…0x700 | 1 | 0 | 0 | — | Design Variables 0–5 (OEM). |
| Setup | 0x720 | 1 | 0 | 0 | 0/1 | Power Sharing Manager (SPLC/DPLC em 0x721–0x730, ocultos). |

## G. Memória (SaSetup) — 🔴 risco de não dar POST
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| SaSetup | 0x006 / 0x005 | 1/1 | **20** / 0 | — | ratio / 0 = 133 MHz | **CORRIGIDO 15:45:** 2666 é só o ponto SAGV parado; sob carga roda **DDR4-3200 CL20-22-22-42 Gear 2** (medido). As tCL/tRCD/tRAS = 20/22/42 vêm do SPD padrão (JEDEC). |
| SaSetup | **0x18D** | 1 | **0** | 0 | 0 = Default SPD, 1 = Custom, 2 = XMP1, 3 = XMP2 … | **Memory profile**: DESNECESSÁRIO — já roda a 3200 (spec do kit). Não mexer. (ADL-U suporta DDR4-3200). 🔴 Se o treino falhar, não dá POST. Só tentar com o CH341A à mão. O menu é gated por uma condição volátil (QID 0x1169); não dá para saber pelo IFR se exige OC Feature = 1. |
| SaSetup | 0x18B | 2 | 0 | 0 | 0 = Auto, 1067…4200 | Maximum Memory Frequency. 🔴 Só eleva se o perfil escolhido suportar. |
| SaSetup | 0x1F1 | 1 | 5 | 5 | 0 = off, 1–4 = ponto fixo, 5 = Enabled | SA GV (troca dinâmica de frequência da memória). 🟡 Fixar no ponto mais alto tira latência na troca e gasta um pouco mais. |
| SaSetup | 0x008…0x017, 0x434…0x43E | var | timings | — | — | Timings manuais (Custom Profile). 🔴 |
| SaSetup | 0x003 / 0x3F5 / 0x3F7 | 2 | 0 | 0 | mV | VDD / VDDQ / VPP da memória. 🔴 |
| SaSetup | 0x18F | 1 | 1 | 1 | 0/1 | MRC Fast Boot (pula o retreino). 🟢 |
| SaSetup | 0x23C / 0x19E | 1 | 0 / 0 | — | — | MRC ULT Safe Config / Safe Mode Support. 🟡 Ligar pode ajudar a recuperar de um treino ruim. |

## H. iGPU (Iris Xe)
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| SaSetup | 0x07A | 1 | 2 | 2 | 1 = 32M, 2 = 64M, 4 = 128M … | DVMT Pre-Allocated (64 MB). 🟡 Ganho mínimo no Windows (a memória é dinâmica). |
| SaSetup | 0x034 | 1 | 1 | — | 0 = 128M, 1 = 256M, 3 = 512M, 7 = 1024M | Aperture Size. 🟡 |
| SaSetup | 0x03F / 0x040 | 1/1 | 255 / 0 | 255 / 0 | 255 = máximo padrão | Maximum GT frequency / Disable Turbo GT. 🟢 Útil para um modo econômico. |
| SaSetup | 0x02E / 0x042 | 1 | 1 / 0 | — | 0/1 | RC6 (Render Standby) / RC1p. 🟢 |
| SaSetup | 0x0B7 / 0x0B1 | 1 | 1 / 0 | — | — | Internal Graphics / Primary Display. 🔴 Não mexer (sem dGPU, perde o vídeo). |

## I. PCIe / ASPM / PCI
| Var | Offset | Tam | Atual | Padrão | Valores | Efeito / risco |
|---|---|---|---|---|---|---|
| Setup | 0x032 / 0x033 | 1 | 1 / 2 | — | Native PCIe / Native ASPM 2 = Auto | ASPM controlado pelo SO. 🟢 |
| SaSetup | 0x0AD / 0x0AC | 1 | 2 / 2 | — | 0 = off, 2 = L1 | DMI ASPM / DMI Gen3 ASPM. 🟢 Desligar reduz latência de I/O, gasta bateria. |
| SaSetup | 0x379 / 0x37D (RP1; demais portas na sequência) | 1 | 2 / 2 | — | ASPM L1 / L1.1+L1.2 | ASPM e L1 Substates por root port (NVMe). 🟡 |
| SaSetup | 0x2A5 / 0x2A9 | 1 | 1 / 1 | — | 0/1 | PCIe Clock Gating / Power Gating RP1. 🟢 |
| SaSetup | 0x08B | 1 | 4 | 4 | Gen1–4 | DMI Max Link Speed. 🔴 Não reduzir sem motivo. |
| PCI_COMMON | 0x003 / 0x004 | 1 | 1 / 0 | — | 0/1 | Above 4G Decoding / Re-Size BAR. Sem dGPU, irrelevante. 🟢 |
| SaSetup | 0x07D / CpuSetup 0x0B9 | 1 | 1 / 1 | — | 0/1 | VT-d / VMX: necessários para Docker, WSL2 e Hyper-V. 🟢 Manter. |

## J. "Samsung Debug Option" (menu de engenharia, Setup)
| Var | Offset | Tam | Atual | Valores | Efeito / risco |
|---|---|---|---|---|---|
| CpuSetup | 0x017 / 0x01E | 4 | 20000 / 0 | mW | PL1 / PL2 de depuração (as mesmas variáveis da seção A). |
| Setup | **0xC7F** | 1 | **1** | 0/1 | **Bios Guard Enable**. 🔴 Desligar **não** permite gravar uma BIOS modificada (o Boot Guard continua conferindo a assinatura) e abre o chip para gravação por software, inclusive por malware. Não recomendado. |
| Setup | 0xC4F / 0xC50 | 1/4 | 2 / 2000 | logo / ms | Logo do boot vindo do sistema de arquivos / atraso de 2 s. 🟢 0xC50 = 0 encurta o boot. |
| Setup | 0xC73…0xC7E | 1 | — | — | Ajuste de sinal (TX/de-ênfase) das portas USB2/USB3. 🔴 |
| Setup | 0xC80 | 1 | 0 | 0/1 | SmartThings Find Power Test Mode. 🟢 Não mexer. |

## K. Travas e segurança (estado atual)
| Var | Offset | Atual | Comentário |
|---|---|---|---|
| CpuSetup | 0x043 | 0 | CFG Lock (MSR 0xE2) já destravado. |
| CpuSetup | 0x10E | **1** | **OC Lock**: o principal obstáculo ao undervolt. |
| CpuSetup | 0x030 | 0 | PL MSR Lock destravado. |
| CpuSetup | 0x029 | 1 | PL3 Lock. |
| CpuSetup | 0x02F | 0 | PL4 Lock. |
| CpuSetup | 0x1B4/0x1B5/0x1B6 | 0 | TDC Locks. |
| CpuSetup | 0x228 | 1 | HwP Lock. |
| CpuSetup | 0x07D | 1 | PROCHOT Lock. |
| CpuSetup | 0x1CD | 1 | Tcc Offset Lock. |
| CpuSetup | 0x045 | 0 | cTDP Lock. |
| CpuSetup | 0x0C1 | 0 | TXT. |
| CpuSetup | 0x112 | 1 | CPU Run Control Lock (debug). |
| PchSetup | 0x73E | 0 | DCI (depuração JTAG via USB): exige Platform Debug Consent (SiSetup 0x1). 🔴 Risco de segurança. |
| MeSetupStorage | 0x002 | 1 | ME State. 🔴 Desligar o ME pode afetar PTT/TPM, Boot Guard e as atualizações. |
| MeSetup | 0x003 | 0 | Me FW Image Re-Flash. 🔴 |
| Setup | 0xC7F | 1 | BIOS Guard. |

---

## ⚠️ Lista de opções PERIGOSAS (risco de não dar POST ou de dano)
1. **Memória:** Memory profile / XMP (SaSetup 0x18D), Max Memory Frequency (0x18B), timings (0x008–0x017, 0x434–0x43E), tensões VDD/VDDQ/VPP (0x003/0x3F5/0x3F7), ODT/Ch Hash/Scrambler/ECC. Falha de treino = sem POST e sem acesso ao F9.
2. **Tensão fixa ou mínima:** Core / Ring / Uncore / GT Voltage **Override** (0x1DD/0x1DE, 0x1E9/0x1EA, 0x2DE/0x2DF, SaSetup 0x263/0x267), Min Voltage (0x207–0x20A), VCCIN AUX (0x336/0x337), PSYS/VccIn Aux IMON.
3. **Corrente e VR:** IccMax / VR Current Limit (0x187/0x189/0x18B), ICC Unlimited (0x346/0x349), ICC overrides (0x347/0x34A), VR Config Enable (0x12D–0x12F), Disable VR Thermal Alert (0x07C).
4. **BCLK / FLL / PLL:** 0x2F7, 0x20D, 0x344, 0x352/0x353, SA PLL (0x342).
5. **Térmico:** Enable All Thermal Functions (0x1F1 = 0), Bi-directional PROCHOT / Disable PROCHOT Output (0x07A/0x07B), Critical Trip Point (Setup 0x6BD).
6. **Plataforma:** Low Power S0 Idle (Setup 0x03D = 0), Internal Graphics / Primary Display (SaSetup 0x0B7/0x0B1), DMI link speed / equalização (SaSetup 0x08B…, Setup 0xB8F–0xBAF), ajuste de sinal USB da Samsung (Setup 0xC73–0xC7E), PMIC (Setup 0x6C4–0x6C9), Active P/E-cores (0x006/0x22F = 0).
7. **Segurança / ME:** ME State, Me Re-Flash, DCI, BIOS Guard Enable (0xC7F), TXT.
8. **Undervolt em geral 🟡:** não é perigo de brick, mas um offset excessivo gravado na BIOS pode travar já no boot. Testar antes no ThrottleStop (com OC Lock = 0) e só depois gravar na BIOS. Se travar, F9 ou recuperação pela NVRAM.
