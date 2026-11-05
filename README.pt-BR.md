# Samsung Galaxy Book2: desbloqueio de BIOS e undervolt (NP550XED / i7-1255U)

**Menus ocultos da BIOS AMI · fim do throttling do Intel DTT · limites de potência · undervolt por AC loadline — sem gravar BIOS**

🇺🇸 [English version](README.md)

Desbloqueio de limites de potência, *undervolt* e menus ocultos da BIOS do **Samsung Galaxy Book2 NP550XED
(i7-1255U)** **sem gravar BIOS modificada**. Tudo é feito editando variáveis NVRAM pelo UEFI Shell, e os menus
ocultos são abertos pelo navegador de setup do próprio firmware.

> ⚠️ **AVISO — leia antes de qualquer coisa**
> - Os offsets valem **somente para a BIOS P11RGK.050** (03/04/2025). Outra versão = outros offsets. **Confira no
>   IFR da sua BIOS** antes de gravar qualquer byte.
> - Este notebook tem **Intel Boot Guard (Verified Boot) + BIOS Guard**. **Gravar uma BIOS modificada = brick.**
>   Nada aqui faz flash do chip.
> - Valores errados de NVRAM podem impedir o POST. Tenha um **backup do chip** e saiba usar um programador
>   **CH341A** antes de começar.
> - Sem garantia. Use por sua conta e risco. Projeto independente, sem relação com Samsung, Intel ou AMI.

> ### ⚖️ Isenção de responsabilidade
> Este repositório é **apenas documentação de um experimento pessoal**, publicado para fins educacionais.
> **O autor não se responsabiliza** por qualquer dano, perda de dados, notebook inutilizado (*brick*), perda de
> garantia, instabilidade, superaquecimento, desgaste de hardware ou qualquer outro prejuízo, direto ou indireto,
> decorrente do uso destas informações, scripts ou programas. **Tudo o que você fizer com base neste material é
> por sua conta e risco.** Alterar a BIOS/NVRAM, a tensão e os limites de potência pode danificar o equipamento e
> anular a garantia do fabricante. Se não tiver certeza do que está fazendo, não faça.

---

## Resultado em uma tabela

Carga: multiplicação de matrizes FP64 (numpy/OpenBLAS, todos os threads), 300 s, na tomada. Média sem os 30 s
iniciais. Sensores lidos do HWiNFO a cada 1 s.

| Configuração | GFLOPS | Pacote | Temp. | VID |
|---|---:|---:|---:|---:|
| Fábrica (Samsung "Otimizado") | 56 | 12,0 W | 65 °C | — |
| Fábrica (Samsung "Alto desempenho") | 62 | 13,0 W | 67 °C | — |
| Etapa 1 — DTT off, PL1 25 W / PL2 51 W, plano Equilibrado | 120 | 20,1 W | 88 °C | 0,756 V |
| Final — + IA AC Loadline 1,40 mΩ, plano Equilibrado | 118–120 | 19,0 W | 83 °C | 0,733 V |
| **Final + metal líquido reaplicado** | **116–120** | **18,7 W** | **67 °C** | **0,738 V** |

**~2,1× o desempenho multi-core de fábrica** e, com o metal líquido, **21 °C a menos** que antes, sem nenhum erro WHEA.

Outros testes no estado final (com metal líquido):

| Teste | Antes do metal | Depois do metal |
|---|---|---|
| Single-thread FP64 (plano Desempenho, 120 s) | 41,8 GF, P-core 2,85 GHz, 79 °C | **61,1 GF**, P-core 3,88 GHz, 85 °C |
| iGPU WebGL 300 s (GT AC LL 1,85 mΩ) | 23,7 fps, 1221 MHz, 92 °C | **24,4 fps**, 1250 MHz (máx.), 87 °C |

iGPU de fábrica (GT AC LL 3,20 mΩ): 22,3 fps a 1148 MHz.

---

## O que descobrimos (resumo técnico)

1. **O limitador de fábrica é o Intel DTT, não a temperatura da CPU.** O DTT escreve PL1 = 12–16 W no MMIO
   (MCHBAR + 0x59A0) com base nos sensores de **carcaça** (SNS1/SNS2, tabela GDDV/PSVT do "vault" Samsung com alvo de
   49–52 °C). Desligar o DTT na BIOS (`Setup 0x6D2 = 0`) faz o PL voltar ao valor da BIOS.
2. **Existe um teto de plataforma de ~20 W de pacote / ~34 W de sistema** (PBM PL2/PL3 controlado pelo EC/Psys).
   PL1 acima de ~22 W não traz ganho sustentado. Um carregador de 65 W não sobe esse teto (o original é de 45 W).
3. **Undervolt por offset NÃO funciona nesta CPU.** Precisa de `OC Lock 0x10E = 0` + `OC Feature 0x1D9 = 1`
   para o mailbox de OC (MSR 0x150) responder. Mesmo assim:
   - em runtime (ThrottleStop/Windows) a escrita é recusada: *Undervolt Protection* da 12ª geração;
   - pela BIOS (offset −50 mV em `0x1E0/0x1E2`, Ring em `0x1EC/0x1EE`), a política chega correta ao FSP, mas o
     pcode ignora: o VID não muda. Não existe opção de "Undervolt Protection" no IFR.
4. **⚠️ Armadilha perigosa:** ligar `OC Feature 0x1D9 = 1` faz valer o **IA/GT IccMax Override (`0x347`/`0x34A`),
   que vem de fábrica = 4 (= 1 A!)** e substitui o VR Current Limit. Grave `0x347 = 320` (80 A) e `0x34A = 160`
   (40 A) **antes** de ligar o 0x1D9.
5. **O que funciona para reduzir tensão é o AC Loadline.** A Undervolt Protection não bloqueia o loadline (VR
   mailbox). IA AC LL de 2,80 para 1,60 mΩ deu −23 mV, −0,8 W e −2,8 °C com o mesmo desempenho; 1,40 mΩ foi
   estável, mas com ganho marginal. O **DC LL fica em 2,80 mΩ** para a leitura de potência continuar correta.
6. **No multi-core, o plano "Equilibrado" (P-core ≤ 2,4 GHz, E-core ≤ 1,8 GHz) rende mais que o "Desempenho
   máximo".** Com o teto de ~20 W, clock alto só gasta tensão: 120 contra 97 GFLOPS.
7. **Menus ocultos da BIOS (Advanced/Chipset AMI) sem patch.** O AMITSE tem dois "portões". O segundo **sempre**
   oculta as abas AMI, a menos que o EC seja de engenharia, e nenhuma variável NVRAM as libera. Mas o
   `EFI_FORM_BROWSER2.SendForm` do próprio AMITSE escolhe a página inicial só por FormId e handle HII, ignorando a
   flag de ocultação. O `faseD_menu.efi` emite o sinal `AMITSE_SETUP_ENTER` (o mesmo de todo F2, para o Setup
   publicar o formset no HII) e chama `SendForm(FormId)`. Não há patch nem persistência. Uma entrada fixa de boot "BIOS Avançada" (último item do BootOrder: Shell → sinal →
   `faseD_menu.efi 2712`/`2714`) abre esses menus quando você quiser; os scripts estão em `nsh/bios_avancada/`.
8. **Pegadinhas de software da Samsung:** o modo "Otimizado" do Samsung Settings ainda corta a CPU por frequência
   (~12 W) mesmo com o DTT desligado; use "Alto desempenho". O **Samsung Device Care** (`iveDeviceCareEngine.exe`)
   ocupou ~0,8 núcleo de forma contínua depois do boot e derrubou o multi-core em ~11 %; foi desinstalado sem
   afetar o Samsung Settings.
9. **Carga da bateria:** a "Proteção da bateria" (80 %) é do Samsung Settings → SCAI → SMM → EC. Não é opção da
   BIOS.

---

## Valores gravados (BIOS P11RGK.050)

GUIDs das variáveis (existem só em *boot services*; o Windows não lê nem escreve):

| Variável | GUID | Tamanho |
|---|---|---|
| Setup | `EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9` | 0xC81 |
| CpuSetup | `B08F97FF-E6E8-4193-A997-5E9E9B0ADB32` | 0x379 |

| Etapa | Opção | Variável:offset (tam) | Padrão | Gravado |
|---|---|---|---|---|
| 1 | Intel Dynamic Tuning (DTT) | `Setup:0x6D2` | 1 | **0** |
| 1 | Overclocking Lock | `CpuSetup:0x10E` | 1 | **0** |
| 1 | Boot performance mode | `CpuSetup:0x13` | 1 | **2** (Turbo) |
| 1 | Power Limit 1 | `CpuSetup:0x17(4)` | 20000 | **25000** (25 W) |
| 1 | cTDP Nominal PL1 | `CpuSetup:0x5B(4)` | 20000 | **25000** |
| 1 | Power Limit 2 | `CpuSetup:0x1E(4)` | 0 (auto) | **51000** (51 W) |
| 1 | cTDP Nominal PL2 | `CpuSetup:0x5F(4)` | 44000 | **51000** |
| 2a | IA IccMax Override | `CpuSetup:0x347(2)` | 4 (1 A!) | **320** (80 A) |
| 2a | GT IccMax Override | `CpuSetup:0x34A(2)` | 4 (1 A!) | **160** (40 A) |
| 2a | OverClocking Feature | `CpuSetup:0x1D9` | 0 | **1** (depois do IccMax!) |
| 2e | IA AC Loadline | `CpuSetup:0x132(2)` | 280 (2,80 mΩ) | **140** (1,40 mΩ) |
| 2e | IA DC Loadline | `CpuSetup:0x13C(2)` | 280 | 280 (não mexer) |
| 3 | Atraso do logo | `Setup:0xC50(4)` | 2000 ms | **0** |
| 3 | Energy Efficient Turbo | `CpuSetup:0x1D5` | 1 | **0** |
| 3 | GT AC Loadline (iGPU) | `CpuSetup:0x134(2)` | 320 (3,20 mΩ) | **185** = `0x00B9` (1,85 mΩ) |

Sintaxe do `setup_var.efi` no UEFI Shell, por exemplo: `setup_var.efi CpuSetup:0x132(2)=0x008C`.

**Reverter:** F2 → **F9** (padrões de fábrica) desfaz **tudo**. Para desfazer um item só, grave o valor padrão com o
`setup_var.efi`. Se o notebook não fizer POST, regrave o backup com um CH341A.

---

## Como reproduzir (resumo)

1. **Backup do chip SPI** (Linux, só leitura): `flashrom -p internal -r` duas vezes e compare os hashes. Guarde
   fora do notebook.
2. **Extraia e confira o *seu* firmware:** UEFIExtract no dump → módulo Setup → IFRExtractor. Confirme cada offset
   e os valores atuais das variáveis. **Não confie cegamente na tabela acima.**
3. **UEFI Shell + `setup_var.efi`** num pendrive ou no ESP, com um `startup.nsh` que faz: `dmpstore` (backup das
   variáveis) → grava → relê → `reset`.
4. **Uma etapa por vez.** Depois de cada uma: boot, conferir os valores, stress de 5 min, checar erros WHEA no
   Visualizador de Eventos.
5. No Windows: com o DTT desligado na BIOS os serviços `ipfsvc`/`dptftcs` não têm mais função. Use o plano
   Equilibrado com limite de clock para multi-core.

Os scripts deste repositório (pasta `nsh/`) são exatamente os que foram usados, com backup antes e conferência
depois.

---

## Avaliado e descartado

- **Flash de BIOS modificada:** Boot Guard Verified Boot confirmado (`MSR 0x13A = 0x130000007F`) + hash AMI dos
  volumes + BIOS Guard.
- **Driver UEFI (Driver####) com patch:** se travar no boot, F9 não resolve; a única saída é o CH341A.
- **TCC offset, PL3/PL4/Psys, C-states, IA CEP:** sem ganho, porque o teto é o PBM de ~20 W e não a temperatura.
- **Memória:** já roda DDR4-3200 com SAGV; XMP não acrescenta nada.
- **Senha de administrador na BIOS:** **não defina**. O filtro do NvramDxe passa a bloquear o setup_var.
- **PECI, PROCHOT, trips térmicos, ME, TXT, DCI, BIOS Guard:** perigosos, não foram tocados.

---

## Estrutura do repositório

```
docs/              engenharia reversa: IFR (catálogo + CSV das 4541 opções), ACPI/DTT, proteções, carga/carregador,
                   SendForm/menus ocultos
src/               biosmod.efi (diagnóstico pré-SO, só leitura), faseD_menu.efi, faseD_sonda.efi (C, MSVC, sem CRT)
nsh/<etapa>/       startup.nsh de cada etapa (dmpstore → grava → relê → reset) + armar_*.ps1 (ESP, BootNext, tarefa)
nsh/bios_avancada/ entrada fixa de boot que abre os menus AMI ocultos
scripts/windows/   medição (HWiNFO shared memory, stress FP64, GPU WebGL) e testes automáticos de cada etapa
scripts/linux/     backup do chip (flashrom, só leitura) e leitura do carregador/EC
scripts/analise/   extração do pacote de BIOS da Samsung e parser de IFR
results/           CSVs (1 linha/s) e logs de cada etapa; etapa*_gravacao = leitura antes/depois de cada gravação
```

**Não incluídos de propósito:** dump do chip e dumps da NVRAM (contêm número de série, UUID, MAC e a chave do
Windows na tabela MSDM), o firmware da Samsung (copyright) e binários de terceiros (veja os links abaixo).

---

## Créditos e ferramentas

- [setup_var.efi](https://github.com/datasone/setup_var.efi) — datasone
- [UEFI Shell](https://github.com/pbatard/UEFI-Shell) — pbatard
- [UEFITool / UEFIExtract](https://github.com/LongSoft/UEFITool) — LongSoft
- [IFRExtractor-RS](https://github.com/LongSoft/IFRExtractor-RS) — LongSoft
- [HWiNFO](https://www.hwinfo.com/) e [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/), usados no diagnóstico
- A ideia do AC Loadline em CPUs com Undervolt Protection veio da discussão do projeto OmenMon

## Licença

Código: MIT (veja `LICENSE`), fornecido "NO ESTADO EM QUE SE ENCONTRA", sem garantia de nenhum tipo.
Documentação: CC BY 4.0. Uso por sua conta e risco; veja a [isenção de responsabilidade](#️-isenção-de-responsabilidade).
