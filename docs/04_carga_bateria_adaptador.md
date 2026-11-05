# Carga da bateria e adaptador: limite de nível e limite de potência

Galaxy Book2 NP550XED, BIOS P11RGK.050. Investigação **somente leitura** feita em 04/11/2026, por volta das 17h, no Windows.
Nada foi gravado. O único arquivo criado fora do scratchpad é este.

Legenda: **[F]** = fato verificado nesta máquina. **[I]** = inferência ou fonte externa, ainda não confirmada aqui.

---

## A) Limite de NÍVEL de carga (para em 80%)

### Estado atual
- **[F]** O limite está **ligado, em 80%**. Fonte: registro `HKLM\SOFTWARE\Samsung\SamsungSettings\ModuleProtectBattery`, com `OnOff=1`, `Value=80`, `Support=1` e `CurrentState=0`.
- **[F]** A bateria está parada em 80%:
  - WMI `BatteryStatus`: `PowerOnline=True`, `Charging=True`, mas `ChargeRate=0`.
  - Carga restante 30 096 mWh, tensão 11,953 V (cerca de 3,98 V por célula, numa bateria de 3 células).
  - O HWiNFO também mostra 80%, com taxa de carga de 0 W.
- **[F]** A ACPI informa "carregando" sempre que o notebook está na tomada, mesmo sem carregar de fato. O `_BST` só informa "descarregando" quando o EC sinaliza `EPTS=0x81`. Por isso o Windows mostra "Carregando" parado em 80%.
- **[F]** Saúde da bateria (`powercfg /batteryreport`, salvo no scratchpad):

| Item | Valor |
|---|---|
| Capacidade de projeto | 43,092 Wh |
| Carga total atual | 37,620 Wh (desgaste de 12,7%) |
| Ciclos | 66 |
| Histórico da carga total | 39,9 Wh até abr/2026, 38,9 Wh em jul/2026, 37,6 Wh desde set/2026 |

  A chave `ModuleBatteryDegradationNoti` mostra que o Samsung Settings já exibiu um aviso de degradação da bateria.

### Onde o limite é controlado
- **[F] Não está na BIOS.** O IFR completo do chip **não tem** opção de limite de carga ("Battery Life Extender" ou similar). As únicas opções de bateria visíveis são:
  - *Smart Battery Calibration* (descarrega a bateria toda para recalibrar);
  - *Smart Battery Power Off* (modo de envio, "shipmode").

  Há também opções ocultas, todas da Intel e nenhuma de nível de carga:

| Opção oculta | Onde fica | Valor atual |
|---|---|---|
| "Charging Method" (Normal ou Fast) | Setup 0x851 | 0 = Normal |
| Charger participant do DTT | Setup 0x6DD | 0 |
| Battery participant do DTT | Setup 0x6E1 | 0 |

- **[F] Não está na ACPI como limite padrão.** A bateria `BAT1` só tem `_BIF`, `_BIX`, `_BST` e `_BTP` (este último é só o alarme de capacidade). Não existem `_BMC`, `_BTM` nem o "charge control" padrão.
- **[F] Caminho real:** o Samsung Settings envia o pedido ao dispositivo ACPI `\_SB.SCAI` (SAM0429), pelo método `CSFI`. O `CSFI` chama `SAWS`, que copia o pedido para a memória `SAWB` e dispara uma interrupção de software (SW SMI) na porta 0xB2. A partir daí o firmware em modo SMM fala com o **EC**, que é quem corta a carga.
- **[I]** Formato do pedido, segundo o driver Linux oficial `samsung-galaxybook`:
  - campos `SAFN 0x5843`, `SASB 0x7A`, `GUNM 0x82`, `GUDS[0]=0xE9`;
  - `GUDS[1]=0x91` lê o limite; `GUDS[1]=0x90` com `GUDS[2]=valor` grava.
  - O EC aceita de 1 a 100. Os valores 0 e 100 significam "sem limite". Alguns modelos desligam o limite sozinhos com valores abaixo de 30.
  - Os valores compatíveis com o Samsung Settings são 50, 60, 70, 80 e 90.
- **[I]** O valor fica guardado no EC. Por isso deve valer também com o notebook desligado e no Kali. O registro é só o estado da interface do Samsung Settings.

### Dá para carregar até 100%? Ou escolher outro valor?
- **Sim, até 100%, e é seguro: é uma função oficial.** Passo a passo:
  1. Abra o **Samsung Settings**.
  2. Entre em **Bateria → Proteção da bateria** (pode aparecer como "Battery Protection" ou "Proteger bateria").
  3. **Desligue** a opção. A bateria passa a carregar até 100%.
  4. Para voltar ao normal, ligue de novo.
  - **[I]** Pela versão do app, a interface deste modelo provavelmente só oferece liga/desliga com 80% fixo.
- **Outro valor (por exemplo 90%):** o app do Windows provavelmente não oferece. Pelo Kali dá, **se** o kernel tiver o driver `samsung-galaxybook`:
  - **[I]** O driver entrou no Linux por volta da versão 6.15 e cobre o SCAI.
  - Verificar: `ls /sys/class/power_supply/BAT1/charge_control_end_threshold`.
  - Gravar 90%: `echo 90 | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold`. Esta é uma **escrita no EC**: só fazer com a aprovação do usuário.
  - **[I]** O Samsung Settings pode regravar 80% ao iniciar o Windows, já que guarda `Value=80`.
  - Não recomendo escrever no EC "na mão" (ec_sys, RW-Everything). Os offsets do EC não estão documentados e uma gravação errada pode, por exemplo, mexer na ventoinha ou no carregador.

### Impacto na vida útil
- **[I]** Ganho de autonomia ao carregar até 100%: cerca de **+7,5 Wh** (de 30,1 para 37,6 Wh), ou seja, uns 25% a mais.
- **[I]** O custo é o envelhecimento mais rápido. A 100%, as células de Li-ion ficam por volta de 4,35 a 4,4 V, contra cerca de 3,98 V hoje. Ficar muito tempo em tensão alta, ainda mais quente, é o que mais acelera o envelhecimento por tempo. Esta máquina esquenta (CPU a 87–95 °C nos testes, perto da bateria). Com 12,7% de desgaste em 66 ciclos, a bateria já envelhece mais por tempo e calor do que por ciclos.
- **Recomendação:** deixar em 80% no dia a dia na tomada. Desligar a proteção só na véspera de usar na bateria e religar depois. 90% (pelo Kali) é um meio-termo razoável.
- **[F]** O limite de 80% **não** afeta o desempenho na tomada. Com a bateria parada, toda a energia vem do adaptador.

---

## B) Limite de POTÊNCIA do adaptador, PSys e PBM, e o teto de cerca de 20 W / 34 W

### O que se sabe sobre o adaptador
- **[F]** O Windows não informa a potência negociada:
  - `ADP1` (ACPI0003) e `_PSR` só dizem se está na tomada ou não;
  - não há campo de potência do adaptador no mapa do EC da ACPI;
  - existe o UCSI (`ACPI\USBC000`, UcmUcsiAcpiClient), mas o Windows não mostra o contrato USB-PD.
- **[F]** O log `USB-UCMUCSICX/Operational` tem 4 timeouts antigos do UCSI (entre out/2025 e jul/2026): `GetPdos`, `GetConnectorStatus`, `PpmReset` e `AckCcCi`. O EC ou o controlador PD às vezes não responde.
- **[F] Há um adaptador USB-C de vídeo ligado:** "USB Type-C Digital AV Adapter" (VID 0x343C, um dispositivo Billboard), atrás de um hub Genesys 05E3:0608, com um teclado Apple 05AC:024F, na porta HS01.
  - **Se o carregador estiver ligado na entrada PD desse adaptador**, e não direto no notebook, o adaptador fica com 10 a 15 W para ele. **[I]**
  - Com um carregador de 45 W isso daria um contrato de cerca de 30 a 35 W. Isso **coincide** com os cerca de 34–35 W de "Total System Power" medidos.
- **[I]** O carregador original deste modelo exato não foi confirmado. A família Book2 usa 65 W USB-C (20 V / 3,25 A), mas o NP750XED, por exemplo, é listado com 45 W. **Conferir a etiqueta do carregador.**
- **[I]** Um carregador de 100 W PD **não** entrega mais que o máximo que o notebook pede, provavelmente 65 W (20 V / 3,25 A). Só ajudaria se hoje o problema for falta de energia: carregador fraco ou energia passando pelo hub.

### PSys, PBM e EC na BIOS (verificado)

| Item | Onde | Valor atual | O que significa |
|---|---|---|---|
| Platform PL1 Enable / Power / Time | CpuSetup 0x31 / 0x32 / 0x36 | 0 / 0 / 0 | desligado |
| Platform PL2 Enable / Power | CpuSetup 0x37 / 0x38 | 0 / 0 | desligado |
| MSR 0x65C PLATFORM_POWER_LIMIT (lido antes do SO, após a Etapa 1) | — | Psys PL1 e PL2 com **enable=0**, sem trava | **[F]** O PSys **não** limita no boot |
| PL3 (MSR 0x615) | CpuSetup 0x23 | 52 W, duty 4%, janela de 62 ms, **travado** | só corta picos curtos |
| PL4 | — | 123 W | — |
| EC Turbo Control Mode | CpuSetup 0xC7 | **0** (desligado) | é a função da Intel em que o EC limita a CPU via PECI conforme o adaptador |
| AC Brick Capacity / EC Polling / EC Guard Band | CpuSetup 0xC8 / 0xC9 / 0xCA | 1 (90 W) / 1 / 0 | ocultas e inativas com 0xC7=0 |
| PSYS Slope / Offset / Prefix | CpuSetup 0x127 / 0x128 / 0x12A | 0 / 0 / 0 (automático) | calibração da **leitura** do PSys, não é limite |
| PSYS PMax | CpuSetup 0x12B | 1152 = 144 W (padrão) | calibração da **leitura** do PSys, não é limite |
| Participantes Power / Charger / Battery do DTT | Setup 0x6DE / 0x6DD / 0x6E1 | 0 / 0 / 0 | sem TPWR/CHRG no vault da Samsung |

- **[F]** Ligar o PSys PL ou o EC Turbo Control **só acrescentaria** limites. Não existe opção na BIOS que "solte" um limite de adaptador, porque nenhum está programado pela BIOS.
- **[F]** Na ACPI, a troca tomada/bateria (`_Q51`/`_Q52`) chama `GSSM(0x9A, PWRS)`, uma SW SMI. **[I]** O firmware em SMM ou o EC pode ajustar alguma coisa nessa troca. Não dá para ver sem analisar o SMM.

### O que as medições mostram (CSVs 02, 11 e 12)

| Teste | Pacote | Sistema | Motivo de limite PL2/PL3/PBM | Throttle térmico |
|---|---|---|---|---|
| 11 Desempenho (25/51 W) | 18,9 W | 33,7 W | 99% do tempo | 58% |
| 12 Equilibrado | 19,9 W | 34,0 W | 0% | 0% |
| 02 (28/51 W, ThrottleStop) | 20,0 W (pico 23,0) | 34,9 W (pico 38,6) | 86% | — |

- **[F]** No teste 11, o teto aparece em **2 a 4 s**, com a CPU a 63–72 °C. **Não é térmico nem PL1** (25 W, janela de 28 s).
- **[F]** No teste 12 o pacote fica no mesmo nível, mas sem motivo de limite: quem segura é o teto de frequência do plano (P-cores 2,4 / E-cores 1,8 GHz).
- **[F]** Em todos os testes a diferença entre sistema e pacote é estável, de cerca de 14–15 W.
- **[F]** Durante os testes a bateria ficou parada em 79–80% (relatório de bateria). Não houve descarga perceptível, ou seja, não faltou energia de forma grosseira. Uma diferença de 1% (cerca de 0,4 Wh) não seria detectada.
- **[F] curiosidade:** o MSR 0x64F lido no UEFI Shell, antes de qualquer carga, já tinha o bit de registro de "PL2" ligado (0x19001000). Esse motivo PL2 é sinalizado também por fontes que não são o PL2 de 51 W programado.

### Conclusão sobre o teto de ~20 W / ~34 W
- **[F] Descartados:** PL1/PL2 da BIOS e do MMIO (25/51 W, conferidos), DTT (desligado), Psys PL no boot (enable=0), PL3 (52 W) e PL4 (123 W).
- **[I] Hipóteses que restam**, em ordem de probabilidade:
  1. **Orçamento de energia imposto em tempo de execução pelo EC ou pelo firmware SMM**, via PECI ou gravando Psys PL2/PL2 depois do boot. Pode ou não depender do adaptador detectado.
  2. **Contrato USB-PD baixo**: carregador de 45 W, ou energia passando pelo adaptador AV/hub. O EC limitaria o sistema a cerca de 34–35 W.
  3. Limite interno do próprio processador (pcode/PBM) para este modelo.
- Hoje **não há** nada no adaptador ou no PSys que se possa mudar com segurança na BIOS para subir o teto.

### Testes sugeridos (só leitura, sem gravar nada) para separar as hipóteses
Use o mesmo `stress_log.py`, 120 s no plano **Desempenho**, e anote `pkgW`, `sysW` e `rPL2`:
1. **Carregador original ligado direto** na USB-C do notebook, sem o adaptador AV/hub. Anote a etiqueta (W, V e A).
2. **Na bateria**, com o carregador desligado e a carga acima de 50%.
3. (Opcional) Com **outro carregador PD de 65 W ou mais** e um cabo de 5 A (com e-marker).

Como ler o resultado:
- O teto **muda** com o carregador ou a ligação: a causa é o adaptador. A solução é ligar o carregador direto, ou usar um de 65 W ou mais.
- O teto **continua igual** em todos os casos, inclusive na bateria: o limite é interno (EC ou pcode). O carregador não muda nada.

Prova direta, no Kali, durante a carga (só lê): `sudo modprobe msr; sudo rdmsr -a 0x65C; sudo rdmsr 0x610; sudo rdmsr 0x64F`. Se `0x65C` mostrar Psys PL2 ligado com cerca de 34–35 W, quem o gravou foi o EC ou o SMM.
- Opção sem reiniciar: um leitor de MSR em modo leitura no Windows, por exemplo a aba TPL ou FIVR do ThrottleStop, ou o RW-Everything só lendo.

## Fontes externas
- Documentação do kernel, driver `samsung-galaxybook`: https://docs.kernel.org/admin-guide/laptops/samsung-galaxybook.html
- Código do driver: https://github.com/torvalds/linux/blob/master/drivers/platform/x86/samsung-galaxybook.c
- Carregador original de 65 W da família Book2 (20 V / 3,25 A): https://www.pccharger.com/products/original-samsung-65w-usb-c-adapter-for-galaxy-book2-business-np641bed-i7-1260p
- NP750XED listado com 45 W: https://www.sparepartworld.com/samsung/notebook/galaxy-book2-15-np750xed/
