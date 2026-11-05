# Carregador de 45 W ou de 65 W? E de onde vem o teto de ~20 W / ~34 W

Galaxy Book2 NP550XED (550XED), i7-1255U, BIOS P11RGK.050, Windows 11 25H2.
Investigação de 04/11/2026, das 18h25 às 19h. Foi **somente leitura**: nada foi gravado em BIOS, NVRAM, EC, MSR ou registro.
Este documento continua o `04_carga_bateria_adaptador.md`.

Legenda: **[F]** = fato medido ou verificado nesta máquina. **[W]** = fonte da internet (URL na seção 5). **[I]** = inferência.

---

## 0. Conclusão

1. **Um carregador de 65 W não deve aumentar o desempenho da CPU.** Três motivos:
   - **[F]** Medido agora: com a CPU no teto (~19 W de pacote e ~33 W de sistema), a tensão da bateria **não caiu** (11,948–11,950 V, igual ao repouso). Ou seja, a bateria não precisou complementar: a energia que chega (mesmo passando pelo adaptador AV) já cobre ≥33 W. O teto não vem de falta de energia.
   - **[F]** O pacote para no mesmo nível (~19–20 W) nos dois planos:
     - no plano **Equilibrado**, sem nenhum motivo PL2/PBM (o limite é o teto de frequência do plano);
     - no plano **Desempenho**, com o motivo "PBM PL2/PL3" o tempo todo.
   - **[W]** A Notebookcheck testou um Galaxy Book2 15 com fonte de **65 W** e mediu CPU sustentada de **~20 W** no modo "Alto desempenho" (11,5 W no Silencioso, 17 W no Otimizado). O mesmo teto aparece com 65 W.
2. **Para carregar, o de 45 W dá conta.**
   - **[W]** A fonte original do NP550XED (Brasil) é de **45 W USB-C**. A peça provável é a Samsung EP-TA845 (GH44-03114A), com saída de até 20 V × 2,25 A.
   - **[W]** Recarga completa em cerca de 2,5 h, segundo a Canaltech (NP550XED, bateria de 43 Wh).
   - **[F]** Com a Proteção da bateria em 80%, a bateria fica parada a maior parte do tempo e a velocidade de carga quase não importa.
   - **[I]** Um carregador de 65 W só ajudaria a **carregar mais rápido enquanto o notebook está em carga pesada**: são ~34 W de sistema, e com 45 W sobram ~10 W para a bateria. Também ajudaria a compensar o que o adaptador AV/hub consome.
3. **O que comprar ou testar:**
   - **Primeiro, de graça:** ligar o carregador de 45 W **direto** na USB-C do notebook, sem o adaptador AV, e repetir o teste (seção 4).
   - **Se quiser margem:** qualquer carregador **USB-PD de 65 W** que ofereça o perfil fixo **20 V / 3,25 A**, com cabo de 3 A ou de 5 A com e-marker. Exemplos: Samsung EP-T6530 ou um GaN de 65 W de boa marca.
   - **Não precisa de 100 W.** O notebook só pede o que suporta.
   - Não compre achando que o teto de 20 W vai subir.
4. **O limitador real de ~20 W / ~34 W:**
   - É um limite **interno da plataforma** (EC, firmware SMM e/ou pcode), sinalizado como "Package-Level RAPL/PBM PL2,PL3".
   - Aparece mesmo com PL1/PL2 de 25/51 W e PL3 de 52 W visíveis no MSR/MMIO, e sem nenhum limite do DTT.
   - Os ~34 W de sistema são só consequência: ~20 W do pacote mais ~14–15 W fixos do resto da plataforma (veja a seção 3.3).
   - **[I]** Os candidatos são:
     1. um PSys PL2 (MSR 0x65C) gravado pelo EC ou pelo SMM depois do boot, com cerca de 34–35 W;
     2. um limite gravado pelo EC via PECI;
     3. um alvo de projeto da Samsung para este chassi, que bate com os ~20 W da Notebookcheck.
5. **Dá para subir o teto sem Kali?**
   - **Hoje, com segurança, não.**
   - O Windows não deixa ler o MSR 0x65C nem a RAM do EC sem carregar um driver de baixo nível. O ThrottleStop.sys está instalado mas parado. RW-Everything e chipsec não estão instalados. O único driver de MSR rodando é o `semav6msr64` da Intel (esrv), que não tem interface pública.
   - O que dá para fazer **sem Kali e sem gravar nada** é o teste A/B/C da seção 4, que separa "limite do adaptador" de "limite interno".
   - Se o teto **não mudar** na bateria nem com o carregador direto, o carregador está descartado de vez. Aí o próximo passo é ler o 0x65C, o que exige Kali ou um driver de leitura que você aceite carregar.

---

## 1. Pesquisa na internet

| Tema | Resultado | Fonte |
|---|---|---|
| Fonte de fábrica do NP550XED (BR) | **45 W USB-C**, bivolt (KaBuM, NP550XED-KF2BR) | [W1] |
| Review BR do NP550XED-KF3BR (i5-1235U) | 45 W USB-C, bateria de 43 Wh, ~2,5 h para carregar de 6% a 100% | [W2] |
| NP750XED (global) | Fonte padrão de 45 W. A peça listada é "ADAPTOR-EP-TA845, USB-C" | [W3] |
| Peça GH44-03114A | EP-TA845, DC 5–20 V, 3 A / 2,25 A (máximo de 45 W em 20 V) | [W4] |
| Dono de NP750XED-KC4IT (Itália) | Veio com fonte de 45 W | [W5] |
| Outras lojas | 45 W (Newegg NP750XED-KB2CA, Findprix NP750XED-KB1IN). Algumas lojas da Europa citam 65 W, provavelmente confundindo com o NP750XEE (Arc A350M), que vem com 65 W | [W6][W7][W8] |
| Notebookcheck, Galaxy Book2 15 com i7-1260P + Arc A350M e fonte de 65 W | CPU sustentada de 11,5 / 17 / **20 W** (Silencioso / Otimizado / Alto desempenho). PL1 de 20 W e PL2 de 35 W. Consumo na tomada de 59 W em média sob carga. Fonte de 65 W "barely adequate". Carga de 80% em ~65 min | [W9] |
| Notebookcheck, Galaxy Book2 15 com i7-1255U | Não tem review própria, só um agregado (72,5%) | [W10] |
| 65 W em outros Galaxy Book2 | Num Book2 360, um usuário mediu ~26 W de carga com qualquer carregador, inclusive de 65 W. Outros relatos dizem que o cabo (3 A contra 5 A) e os PDOs limitam | [W11][W12][W13] |
| O EC limita conforme o carregador? | A Samsung mostra o aviso "Auxiliary power connected" quando a fonte é fraca (~10 W, 5 V/2 A), então detecta o contrato PD. Não há documentação de PL1 caindo entre 45 W e 65 W | [W12] |
| Carregamento rápido no Samsung Settings | **Não existe** opção para notebook. Existem Proteção da bateria, Carregamento USB e Modo de desempenho. A Samsung diz apenas que o carregador USB-C "suporta fast charging" | [W14][W15][W16] |
| Hub ou adaptador com PD pass-through | Reserva de 7 a 15 W, conforme o modelo. Com 45 W, sobram ~30–38 W para o notebook | [W17][W18][W19] |
| "Charging Method Normal/Fast" do BIOS | Sem documentação pública. **[I]** Deve controlar só a corrente de carga da bateria no EC, não PL1/PL2 | — |

---

## 2. Windows: o que foi medido

### 2.1 Bateria (WMI, HWiNFO, powercfg)
**[F]** Arquivos `01_wmi_bateria.txt` e `02_battery_report.html/.xml`.

| Item | Valor |
|---|---|
| Estado no WMI (`BatteryStatus`) | `PowerOnline=True`, `Charging=True`, **`ChargeRate=0`**, `DischargeRate=0` |
| Carga restante | 29 720 mWh, **79%** |
| Tensão | 11,948 V |
| Carga total atual / de projeto | 37 620 / 43 092 mWh (desgaste de 12,7%) |
| Ciclos | 66 |
| Tempo estimado (`BatteryRuntime`) | 0xFFFFFFFF (desconhecido, porque está na tomada) |
| HWiNFO, sessão desde 18h04 | Charge Rate de 0 W (máximo de 1,58 W). Nível entre 79 e 80% |
| Proteção da bateria | 80% ligada, então o EC mantém a bateria em 79–80% e **não deu para medir a taxa de carga real**. Para medir, seria preciso desligar a Proteção da bateria no Samsung Settings (fora do escopo, porque altera configuração) |

**[F]** A carga restante só muda em degraus de 376 mWh, ou seja, 1% da carga total (28 591, 28 967, 29 344, 29 720, 30 096). O EC informa a carga com resolução de 1%. Por isso a "queda de 1%" vista nos testes antigos não prova que a bateria descarregou.

**[F]** O ETW de `Microsoft-Windows-Battery`, gravado por 2 minutos (`06_etw_cad_ucsi.*`), só mostra a consulta periódica do `_BST`, com `PresentRate=0`. Os provedores `Microsoft-Windows-Power-CAD` (driver de arbitragem de carga) e `Microsoft-Windows-USB-UCMUCSICX` não geraram eventos: eles só registram algo quando há troca de conexão.

### 2.2 USB-C, UCSI e PD no Windows
**[F]** Arquivos `04_pnp_usbc.txt` e `05_pnp_props.txt`.

Dispositivos encontrados:
- `ACPI\USBC000\0`, "Dispositivo UCM-UCSI ACPI" (UcmUcsiAcpiClient);
- `ROOT\CAD\0000`, "Driver de Arbitragem de Carregamento";
- `ACPI\ACPI0003`, adaptador de CA;
- "USB Type-C Digital AV Adapter" (VID 0x343C), ainda conectado.

O que **não** dá para ler:
- O Windows **não expõe** PDOs nem o contrato PD em nenhuma interface de usuário: nem propriedade PnP, nem WMI, nem log.
- O registro de `UcmCx0101` e `UcmUcsiCx` só tem parâmetros do WDF e o GUID de rastreamento WPP. Esse rastreamento precisaria dos TMF/PDB da Microsoft para ser decodificado.

O que o log mostra:
- `USB-UCMUCSICX/Operational`: as mesmas 4 falhas antigas do UCSI (out/2025 a jul/2026). Nada novo.
- `Kernel-Power 105` (troca de fonte de energia): as últimas ligações na tomada foram com 62–80% de carga. Não há "flapping", ou seja, troca repetida entre tomada e bateria.

### 2.3 Samsung Settings (registro, só leitura)
**[F]** Arquivos `07_registro_samsung.txt` e `11_strings_samsung_settings.txt`.

| Chave | Valores |
|---|---|
| `ModuleProtectBattery` | `OnOff=1`, `Value=80` |
| `ModulePerformance` | `Value=3`, `ModeList=[2,1,3]`, `WindowsPowerOption=BestPerformance` |
| `ModuleUSBCharging` | `Support=0` |

- **Não existe** módulo de carregamento rápido nem de potência do adaptador. Os nomes no `SamsungSettings.dll` confirmam isso: há `ProtectBattery`, `UsbCharging`, `BatteryInformation`, `IsCharger` e `PerformamancModeUSBChargCharging`, e nenhum controle de velocidade de carga.

### 2.4 O carregador limita a energia? Medições com a tensão da bateria
Ideia do teste: se o carregador (ou o caminho pelo adaptador AV) não der conta, a bateria complementa e a tensão dela cai sob carga. Em repouso a tensão é de ~11,948 V.

**[F]** Medido no plano Equilibrado, com o carregador ligado como está hoje (pelo adaptador AV):

| Teste (arquivo) | Sistema | Pacote | Temp. | Tensão da bateria |
|---|---|---|---|---|
| Passivo, 150 s (`08_…csv`) | 15 W (máx. 20 W) | — | — | 11,947–11,950 V |
| 4 threads escalares, 30 s (`09_…csv`) | 22,0 W | 11,4 W | 63 °C | 11,948–11,949 V |
| 12 threads escalares, 45 s (`09_…csv`) | 28,5 W | 17,3 W | 77 °C | 11,947–11,949 V |
| **numpy (AVX), 45 s (`10_…csv`)** | **31,4–33,4 W** | **17,7–19,2 W** | 69–82 °C | **11,948–11,950 V**, sem queda |

- O teste com numpy chegou ao teto de sempre: pacote ~19 W e sistema ~33 W, com `rPL2=0` neste plano.
- **Leitura:** a ~33 W de sistema, a energia vem toda do carregador. A bateria não complementa, então o contrato efetivo, mesmo passando pelo adaptador AV, é **≥ ~33 W**.
- **[F] Ressalva:** a sessão do HWiNFO desde 18h04 registrou uma tensão mínima de 11,740 V. Isso pode ter sido um pico durante os testes de LL das 18h06–18h20 (sistema de até 37,4 W) ou um transiente. Hoje não dá para dizer se, **acima** de ~35 W, a bateria complementa. O teste da seção 4 responde isso.

### 2.5 Reanálise dos CSVs antigos (testes multi de 300 s, `D:\BIOS_Otimizacao\testes\*.csv`)
**[F]**

| Teste | Pacote | Sistema | Sistema − pacote | Motivo PL2/PBM |
|---|---|---|---|---|
| 11 Desempenho | 18,9 ± 0,8 W | 33,8 W | 14,9 W | 99% |
| 26 Desempenho | 18,6 ± 0,7 W | 33,3 W | 14,8 W | 99% |
| 04 Alto desempenho + trava | 19,6 W | 34,7 W | 15,1 W | 99% |
| 12 Equilibrado | 20,1 ± 0,2 W | 34,4 W | 14,2 W | **0%** |
| 24 Equilibrado | 19,0 W | 33,0 W | 14,0 W | **0%** |
| 01 Fábrica (com DTT) | 12,1 W | 25,2 W | 13,1 W | 1% |

- A diferença entre sistema e pacote fica constante, com ±0,2–0,5 W de variação. Pacote e sistema sobem e descem juntos, então os dados não permitem dizer qual dos dois o limite está segurando.
- O Equilibrado chega ao mesmo nível **sem** motivo de limite. Isso enfraquece a hipótese "PSys PL2 = contrato do carregador" e reforça "alvo de ~20 W da plataforma" ou coincidência com o teto de frequência do plano.

---

## 3. ACPI (leitura estática das tabelas em `acpi\dsl`)

### 3.1 Adaptador
**[F]**
- `\_SB.ADP1` (ACPI0003): o `_PSR` só devolve `PWRS` (1 na tomada, 0 na bateria). Não há `_PIF` nem `_PRL`, então o firmware não informa a potência ao sistema.
- `_Q51`/`_Q52` (tomada/bateria): fazem `PWRS=1/0`, chamam `GSSM(0x9A, PWRS)` (SW SMI, que manda o SMM agir na troca de fonte), `Notify(ADP1)`, `VRMF=1` (campo do EC na posição 0x9A) e `CCRN` (avisa as CPUs para reavaliar `_PPC`/`_CST`).
- **[I]** Se a Samsung ajusta algum limite conforme a fonte, isso acontece no SMM (SMI 0x9A) ou no próprio EC, e não aparece na ACPI.

### 3.2 Mapa do EC (`OperationRegion ECR`, EmbeddedControl 0x00–0xFF)
**[F]**

| Posição | Campos | O que é |
|---|---|---|
| 0x10–0x3E | `VERS`, `CCI0-3`, `CTL0-7`, `MGI0-F`, `MGO0-F`, `OPMO` | **Caixa de mensagens do UCSI, dentro da RAM do EC.** As respostas de `GET_PDOS` e `GET_CONNECTOR_STATUS` (PDOs e contrato PD) passam por aqui |
| 0x50–0x57 | `CMDR`, `PPSL`, `PPSH`, `PINV`, `PENV`, `PSTP`, `CPUP`(16) | Campos do modelo de referência Intel (DTT/PTID). `CPUP` (potência da CPU) e `PENV` só são lidos pelo `PtidDevc`. Nenhum tem relação com o adaptador |
| 0x84 | `B1ST` | Estado da bateria |
| 0x9A | `VRMF` | Gravado com 1 a cada troca tomada/bateria |
| 0x9C–0x9F | `SCAI`, `CSMF`, `CSST`, `EPTS` | Interface Samsung (SCAI) e flag de descarga |
| 0xA0–0xBF | `B1RR`, `B1PV`, `B1AF`, `B1VL`… | Dados da bateria |

- **[F] Não existe** campo de potência ou corrente do adaptador (`ACWT`, `ADPW`, `ARTG`, `PROP`, `PMAX`, `PBSS`, `CTYP`, `ACUR`, `AVOL`, `CHGR`, `FCHG`, `PPWR`). Esses nomes aparecem **só como External** no `SSDT_DptfTabl`, herança do modelo de referência Intel. A Samsung retirou os participantes de energia e de carregador (`TPWR`/`CHRG`) e não definiu esses campos no EC.
- **[I]** Ou seja: a **única** fonte do contrato PD é a caixa do UCSI em EC 0x10–0x3E. Ela só pode ser lida (a) pelo driver UCSI do sistema, que não expõe os PDOs no Windows, ou (b) lendo a RAM do EC diretamente, o que exige um driver de baixo nível no Windows ou `ec_sys` no Linux.

### 3.3 PSys e DPTF
**[F]**
- Não há PSys, PPL1 de plataforma nem limite por adaptador na ACPI. O único `PPL1` é o do MCHBAR+0x59A0 (método `SPL1`/`RPL1`), que é o PL1 do pacote, mexido pelo método de referência Intel para Modern Standby.
- O `SSDT_Pmax_Dev` trata do PMAX da câmera e do flash, não de potência da plataforma.
- **[I] Por que o sistema fica uns 14–15 W acima do pacote:**
  - **[F]** Esse "resto" vale ~10 W em idle e ~14–15 W em carga.
  - **[I]** Inclui as perdas dos reguladores de tensão (VR), a memória, o SSD, a tela, o ventilador e os dispositivos USB alimentados pelo notebook (teclado Apple e hub).

---

## 4. Teste decisivo sem Kali (só leitura, ~3 min cada)
Script: `D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py`. Ele só lê o HWiNFO, aplica 120 s de carga numpy e grava a tensão da bateria junto com a potência do sistema e do pacote.

```
python -I D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py A_como_esta
python -I D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py B_direto      (45 W direto, sem adaptador AV)
python -I D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py C_bateria     (desligado da tomada, bateria > 50%)
python -I D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py D_65W         (opcional: outro PD >= 65 W, direto)
```

- Faça todos no **mesmo plano**, Desempenho de preferência, e com a mesma posição do notebook.
- Anote a etiqueta do carregador (modelo, W, V/A).

Como ler o resultado:

| Resultado | Significa |
|---|---|
| A = B = C (~19–20 W de pacote) | O teto é interno (EC, pcode ou alvo da Samsung). O carregador não muda nada. Fica confirmado que o de 65 W não ajuda o desempenho |
| B > A | O adaptador AV estava roubando potência. Resolve ligando o carregador direto |
| C < A | Normal: na bateria a Samsung reduz o limite (a Notebookcheck viu 13–20 W na bateria) |
| Em A ou B, a tensão da bateria cai >0,05 V na carga | A bateria está complementando, então o carregador é o gargalo. Aí o de 65 W **ajuda** |

---

## 5. Fontes
- [W1] KaBuM, NP550XED-KF2BR: https://www.kabum.com.br/produto/520072/notebook-samsung-galaxy-book2-intel-core-i5-1235u-8gb-ram-ssd-256gb-15-6-fhd-windows-11-home-grafite-np550xed-kf2br
- [W2] Canaltech, review do Galaxy Book2 (NP550XED-KF3BR): https://canaltech.com.br/notebooks/analise/review-galaxy-book2-otimo-custo-beneficio-da-linha-galaxy/
- [W3] Sparepartworld, NP750XED: https://www.sparepartworld.com/samsung/notebook/galaxy-book2-15-np750xed/
- [W4] IPC-Computer, GH44-03114A (EP-TA845): https://www.ipc-computer.eu/laptop-spare-parts/spareparts/sparepart-gh44-03114a-132773846
- [W5] Samsung Community EU (NP750XED-KC4IT, 45 W): https://eu.community.samsung.com/t5/computer-e-monitor/cavo-di-ricarica-galaxy-book-2/m-p/12133320
- [W6] Newegg Business, NP750XED-KB2CA: https://www.neweggbusiness.com/samsung-galaxy-book2-15-6-fhd-intel-core-i7-1255u-intel-iris-xe-graphics-8gb-memory-256-gb-ssd-graphite/p/9B-34-132-530
- [W7] Findprix, NP750XED-KB1IN: https://www.findprix.com/laptops/samsung-galaxy-book2-np750xed-kb1in-core-i5-12th-gen-8gb-256gb-ssd-windows-11-405
- [W8] BCC (cita 65 W, provável confusão de modelo): https://www.bcc.nl/product/samsung-galaxy-book2-15-8gb-256gb-zilver
- [W9] Notebookcheck, review do Galaxy Book2 15 (Arc A350M): https://www.notebookcheck.net/Samsung-Galaxy-Book2-15-review-multimedia-laptop-with-Arc-A350M-fails-to-impress.642418.0.html
- [W10] Notebookcheck, agregado do i7-1255U: https://www.notebookcheck.net/Samsung-Galaxy-Book2-15-i7-1255U.651476.0.html
- [W11] Samsung Community US, Book2 360 com carga lenta: https://us.community.samsung.com/t5/Computers/Samsung-Book-2-360-Slow-charge/m-p/2507899
- [W12] Samsung Community US, aviso "Auxiliary power" e cabos: https://us.community.samsung.com/t5/Computers/Galaxy-Book-Pro-360-15-6-quot-Power-Adaptor-Issue/m-p/2212591
- [W13] Samsung Community EU, fast charger no Book2 Pro: https://eu.community.samsung.com/t5/computers-it/fast-charger-not-working-galaxy-book2-pro/m-p/10906036
- [W14] Samsung IN, Battery and Performance: https://www.samsung.com/in/support/computing/battery-and-performance-feature-in-galaxy-book-series/
- [W15] Samsung US, bateria do Galaxy Book: https://www.samsung.com/us/support/galaxy-battery/galaxy-book-battery/
- [W16] Samsung CA, carga do Galaxy Book: https://www.samsung.com/ca/support/computing/galaxy-book-charge
- [W17] StarTech, PD pass-through: https://community.startech.com/t/what-is-usb-c-power-delivery-pd-pass-through/816
- [W18] Plugable, carga por hub: https://kb.plugable.com/usb-hub/when-attempting-to-charge-my-laptop-via-the-usbc-7n1e-adapter-my-laptop-does-not-charge-or-reports-that-it-is-charging-at-a-slower-than-expected-rate-why-is-this
- [W19] Comunidade Anker, hub PD com 45 W: https://community.anker.com/t/dell-xps13-and-anker-pd-media-hub-a8380-passthrough-charging/87178
- Relato BR de throttling (página não abriu): https://r1.community.samsung.com/t5/inform%C3%A1tica/power-throttling-galaxybook2/m-p/24930720/highlight/true

## 6. Arquivos gerados (`D:\BIOS_Otimizacao\testes\carregador\`)

| Arquivo | Conteúdo |
|---|---|
| `01_wmi_bateria.txt` | WMI da bateria |
| `02_battery_report.html`, `.xml` | Relatório do powercfg |
| `04_pnp_usbc.txt`, `05_pnp_props.txt` | Dispositivos UCSI, CAD e AC |
| `06_etw_cad_ucsi.etl`, `.xml` | ETW de 2 minutos |
| `07_registro_samsung.txt` | Registro do Samsung Settings |
| `08_…`, `09_…`, `10_…csv` | Medições de tensão da bateria contra potência |
| `11_strings_samsung_settings.txt` | Nomes de funções do Samsung Settings |
| `teste_carregador_tensao.py` | Script do teste da seção 4 |

O ETW foi uma sessão temporária (`logman -ets`), já encerrada. Ela não deixa configuração no sistema.
