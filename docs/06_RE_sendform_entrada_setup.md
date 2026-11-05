# Fase D — SendForm / FORM_BROWSER2 e entrada em Setup (AMITSE.efi P11RGK.050)

Alvo: `D:\BIOS_Otimizacao\engenharia_reversa\faseD\bin\AMITSE.efi`
SHA256: `d4f06099ed1a0c8642b66bb17568314cb8086a45dd91ece42212cfce8fada603`
PE32+ x64, ImageBase 0 (RVA == endereço). Análise 100% estática / somente leitura.

Convenção: todos os endereços são RVAs (== endereço em memória, ImageBase 0). Trechos de código/bytes mantidos verbatim.

---

## Resumo do mecanismo (confirmado nesta sessão)

Há DOIS mecanismos independentes que escondem as abas AMI, ambos aplicados durante a
construção da lista de páginas em `FUN_35664` (data-init de Setup), via o hook `0xFFFF0022`:

1. **Promoção / "top-level"** — `FUN_B0898` (Gate 1) grava `ParentPageID(+0x12)=0` nas páginas
   que casam a tabela `0x1B5480`. Em produção (PCD != 0) as abas AMI `0x2711,0x2712,0x2714-0x2717`
   NÃO são promovidas → ficam aninhadas (não aparecem como aba de topo).
2. **Flag HIDDEN** — `FUN_B0738` (Gate 2) grava `PageFlags(+0x14) |= 1` (bit0 = HIDDEN) nas páginas
   que casam a tabela `0x1B56A0`, e só limpa bit0 de `0x2712/0x2714` sob a condição de engenharia EC
   (falsa em produção). `FUN_35664` pula páginas com bit0 ao escolher a primeira página.

Para a página aparecer como aba navegável na *front page* interativa (F2) é preciso corrigir os DOIS.
Já a navegação explícita via `SendForm(FormId=...)` ignora ambos (ver Q1).

Estruturas decodificadas nesta sessão (via `read_bytes`):

- Tabela `0x1B5480` (Gate 1, 11 entradas × 0x20; `+0`=GUID16, `+0x10`=FormId(word), `+0x18`=qword filtro):
  todas com GUID formset `Setup {7B59104A-C00D-4158-87FF-F04D6396A915}`, `+0x18`=0.
  FormIds: `0x2711,0x2712,0x2714,0x2715,0x2716,0x2717,0x2718,0x2719,0x271A,0x271B` + entrada-zero.
- Tabela `0x1B56A0` (Gate 2, 10 entradas × 0x20; mesmo layout):
  - E0 `0x1B56A0`: Setup, FormId `0x2710` (root)
  - E1 `0x1B56C0`: `{ACA9F304-21E2-4852-9875-7FF4881D67A5}`, FormId `0x0000`
  - E2 `0x1B56E0`: `{C25F2B5F-9A82-4E3B-8AF9-E627E7AB3673}`, FormId `0x0000`
  - E3 `0x1B5700`: Setup, FormId `0x2712`
  - E4 `0x1B5720`: Setup, FormId `0x2714`
  - E5 `0x1B5740`: Setup, FormId `0x2711`
  - E6 `0x1B5760`: Setup, FormId `0x2715`
  - E7 `0x1B5780`: Setup, FormId `0x2716`
  - E8 `0x1B57A0`: Setup, FormId `0x2717`
  - E9 `0x1B57C0`: zeros (terminador)
  (campo FormId fica em `base+0x10`.)

---

## Q1 — SendForm(Handles=[HII Setup], 1, &7B59104A, FormId=0x2712, Dim=NULL, &Action)

### FORM_BROWSER2 instalado
No DriverEntry, em `0x2089`:
```
0000207F: lea r8,[1A9918h]           ; interface struct = {SendForm=0x19F90, BrowserCallback=0x1A6CC}
00002089: lea rdx,[1A8EA0h]          ; GUID EFI_FORM_BROWSER2_PROTOCOL
00002094: call [rax+148h]            ; gBS->InstallMultipleProtocolInterfaces
```
AMITSE é um driver DXE; o protocolo existe desde o despacho DXE — disponível em BDS e para um app
de UEFI Shell carregado como boot option (BootServices ativo). `SendForm` faz a própria init
(gate em `0x19FFA`: `[0x258F88]`/`byte[0x206D64]`), logo funciona antes OU depois do Setup interativo.
Confiança: ALTA.

### Fluxo de SendForm (`0x19F90`)
Mapeamento de argumentos (MS x64, prólogo salva não-voláteis em shadow space):
`rcx=This`, `rsi=rdx=Handles`, `rdi=r8=HandleCount`, `rbx=r9=FormSetGuid`, `FormId=word[rbp+0x50]`,
`ScreenDimensions=[rbp+0x58]`, `ActionRequest=[rbp+0x60]`.

- Valida (`Handles`/`HandleCount` nulos → `EFI_INVALID_PARAMETER 0x8000...02`).
- Monta o array interno de handles em `[0x2598D0]` (count em `[0x2598D8]`) a partir dos `Handles`
  passados (loop `0x1A109..0x1A153`; grava `Handles[i]`).
- Grava a requisição:
  - `0x1A0E8: mov [0x20F868],rbx`   → FormSetGuid
  - `0x1A0F2: mov [0x20F878],ax`    → **FormId pedido (0x2712)**  (lido de `[rbp+0x50]`)
- Dispara a engine TSE: `0x1A30E: call FUN_37064` (quando `[0x2598D0]!=0`, isto é, com lista de handles).
- No fim repõe estado: `0x1A4FF [0x2598D0]=0`, `0x1A506 [0x20F878]=0`.
- `ActionRequest`: em `0x1A4B7`, se `[rbp+0x60]!=0`, grava `*ActionRequest = 1`.

### O hiding É aplicado, mas a seleção da página o ignora
`FUN_37064` → `FUN_35664` (data-init). `FUN_35664` (confirmado):
```
FUN_00004670(0xffff0022,&LAB_000b0898);   // registra Gate1 (hook)
...
FUN_0003473c(0,*DAT_00259790);            // dispara hooks -> B0898 -> B0738 (aplica hiding)
```
Ou seja, mesmo pela rota do SendForm, a página `0x2712` recebe em produção
`ParentPageID != 0` (não promovida) e `PageFlags bit0 = 1` (HIDDEN).

PORÉM, a escolha da página inicial em `FUN_35664` usa `FUN_1b888` quando há lista de handles
do SendForm (`DAT_002598d0 != 0`):
```
if ((DAT_002598d0 == 0) ||
    ((lVar5 = FUN_0001b888(&local_res8), lVar5 != 0 || ((short)local_res8 == -1))))
        FUN_000c47c0(0xfffff00b,&LAB_000354fc);   // rota PADRÃO (front page, respeita hiding)
else
        FUN_000a86cc();                            // navega direto para a página achada
```

`FUN_1b888` (`0x1b888`) — resolvedor da página inicial a partir do FormId pedido:
```
sVar3 = DAT_0020f878;                 // FormId pedido (0x2712)
*param_1 = 0xffff;
if (sVar3 != 0 && page_count != 0) {
  for cada página p:
    plVar5 = [0x25a678] + offset;     // struct da página
    if (p != 0 && p[0] != 0 && p[0] != 0xffff
        && *(short*)(p+0xA) == sVar3  // >>> casa FormId da página com o FormId pedido
        && DAT_002598d8 != 0) {
       for cada handle h em [0x2598d0][0..2598d8):
          if (p[0] == h) {            // >>> página pertence a um dos HII handles passados
             *param_1 = (short)p[2];  // retorna id da página (p+0x10)
             return 0;
          }
    }
}
return 0x8000000000000e;             // NOT_FOUND
```
**`FUN_1b888` NÃO lê `PageFlags` (+0x14 / bit0 HIDDEN) nem `ParentPageID` (+0x12).** Casa apenas
`(FormId == [0x20F878])` E `(handle da página ∈ handles passados)`. Portanto:

- `SendForm(..., FormId=0x2712)` → `FUN_1b888` acha a página 0x2712 (ela existe na lista; o hiding só
  altera flags, não remove a página), retorna 0, e `FUN_35664` chama `FUN_a86cc()` → **a form 0x2712
  (Advanced) é exibida e os filhos são navegáveis**, independentemente de estar HIDDEN/não-promovida.
  O hiding (`B0898`/`B0738`) só governa a lista de abas da *front page* e a auto-seleção da primeira
  página (rota `FUN_c47c0` + loop que pula bit0), NÃO a navegação explícita por FormId.
  **Confiança: ALTA** (observado diretamente que `FUN_1b888` ignora bit0 e ParentPageID).

- **FormId = 0 (formset inteiro):** `FUN_1b888` tem guarda `if (sVar3 != 0 ...)`; com FormId=0 o loop é
  pulado, retorna `0xffff`/NOT_FOUND → `FUN_35664` cai na rota padrão `FUN_c47c0(0xfffff00b)` que usa o
  loop de primeira-página-visível (pula bit0) → aterrissa na primeira aba VISÍVEL = uma aba Samsung
  `0x2718+` em produção. Ou seja, **FormId=0 mostra a visão restrita, não o Advanced.** Confiança: ALTA.

### Gravação (F10 / ActionRequest submit)
AMITSE é um provedor FORM_BROWSER2 padrão: a submissão percorre o fluxo HII — `ConfigAccess`
(`ExtractConfig`/`RouteConfig`/`Callback`) do dono de cada question e o HII ConfigRouting — que
efetivamente escreve as variáveis NVRAM. TSE mantém um cache de respostas em memória durante a sessão
e faz o commit via RouteConfig/ConfigAccess no submit; não é um canal privado paralelo. NÃO foi
rastreado o handler de F10 instrução-a-instrução nesta sessão → **Confiança: MÉDIA (inferência
arquitetural).** Implicação prática: variáveis bloqueadas por ConfigAccess/autenticação continuam
sujeitas às mesmas checagens mesmo via SendForm externo.

---

## Q2 — Quem chama `FUN_B0738` e quando (risco de re-esconder)

Callers resolvidos (Ghidra) de `FUN_B0738`: `0x1e3b4`, `0x1e914` (+1 ref não resolvida = `FUN_B0898`,
alcançada só por ponteiro de hook). Os dois call-sites citados (`0x1E40F`, `0x1EC74`) ficam dentro
dessas funções.

1. **`FUN_B0898` → `FUN_B0738`** em `0xB0977`: disparado pelo hook `0xFFFF0022` dentro de `FUN_35664`
   (uma vez por construção de dados de Setup).
2. **`FUN_0001e3b4`** (call em `0x1e40f`): helper de *rebuild/refresh* da lista de páginas
   (`FUN_1e440`, `FUN_298e4`, `FUN_1bff0/1c2a0/1c0dc`, …). Faz `if (ok) FUN_b0738()`. Reaplica o hide
   sempre que o conjunto de páginas é reconstruído.
3. **`FUN_0001e914`** (call em `0x1ec74`): caminho de *registro de novo pacote HII/formset dinâmico*
   (cresce arrays `[0x251828]`, `[0x20f8e8]`, reconstrói buffer de páginas `[0x25a678]`, seta
   `[0x206d65]=1`), re-parse e `if (ok) FUN_b0738()`.

**Conclusão:** SIM — se, após um patch ou após um SendForm, qualquer destes rodar (refresh de formset,
ou um driver publicar um novo pacote HII), as páginas que casam a tabela `0x1B56A0` têm bit0
re-setado. Logo, um patch que mexe apenas nas structs de página já construídas pode ser desfeito;
um patch que **neutraliza a tabela `0x1B56A0`** é durável (B0738 passa a não casar nada).
Confiança: ALTA (as três funções foram descompiladas).

---

## Q3 — Patches mínimos (dados preferível) para liberar as abas AMI

Lembrar: para a FRONT PAGE interativa é preciso corrigir promoção (ParentPageID, Gate1) E hide (bit0,
Gate2). Para navegação externa por SendForm(FormId) nada disto é necessário (Q1).

### (A) Patch só-dados — RECOMENDADO (durável contra os re-runs do Q2)
Aplicar ANTES do hook disparar (ex.: a partir de um driver `Driver####`, ver Q4), ou combinar com o
fallback de structs vivas abaixo se aplicado tarde.

**(A1) PCD Set8 = 0** — faz `B0898` promover as abas AMI (grava `ParentPageID=0`):
- Protocolo PI PCD (`gEfiPcdProtocol 13A3F0F6-...`), `Set8` em `+0x40`.
- GUID do token: `EEE8EEBE-2885-41B7-AAC4-EBACF7F8CDFE` (em `0x1A8CD0`), token `0x5A5A0012`.
- É dado DATA UINT8 (volatile). Não é byte da imagem TSE.

**(A2) Neutralizar os 6 FormIds das abas AMI na tabela `0x1B56A0`** — faz `B0738` não casar essas
páginas (não seta bit0, nem chama `FUN_20330`). Usar `FFFF` (nenhuma página tem FormId 0xFFFF; mais
seguro que `0000`, que poderia casar entradas de formset):

| RVA (word) | original | novo | FormId |
|---|---|---|---|
| `0x1B5710` | `12 27` | `FF FF` | 0x2712 |
| `0x1B5730` | `14 27` | `FF FF` | 0x2714 |
| `0x1B5750` | `11 27` | `FF FF` | 0x2711 |
| `0x1B5770` | `15 27` | `FF FF` | 0x2715 |
| `0x1B5790` | `16 27` | `FF FF` | 0x2716 |
| `0x1B57B0` | `17 27` | `FF FF` | 0x2717 |

Deixar intactas E0 (`0x2710` root, `0x1B56B0`) e as duas entradas de formset (E1 `0x1B56D0`,
E2 `0x1B56F0`) — alterá-las é desnecessário e o tratamento do root é intencional.

### (B) Patch de código — alternativa (3 bytes, também durável)

**(B1) Gate 1 — promoção, em `0xB08E8`:** `74 21` (`je 0xB090B`) → `EB 21` (`jmp 0xB090B`).
Checagem da direção (o enunciado suspeitava estar errada): `test al,al` em `0xB08E6` reflete o PCD;
`je 0xB090B` é tomado quando `al==0` (PCD==0) e `0xB090B` é a rota de casar-tabela-e-promover
(`mov word ptr [rdi+12h],bp` em `0xB094D`, bp=0). Quando PCD!=0 cai no filtro `0xB08EA..0xB0909` que
manda as abas AMI para `0xB0951` (sem promover). Trocar por `jmp 0xB090B` força TODA página à rota de
promoção, independente do PCD → **`EB 21` é a direção CORRETA** (páginas fora da tabela `0x1B5480`
caem em `0xB0951` inofensivamente). Substitui (A1).

**(B2) Gate 2 — hide, em `0xB0738`:** `48 8B C4` (`mov rax,rsp`, 1º byte) → `C3` (`ret`).
`B0738` passa a ser no-op; nenhuma página recebe bit0 (default é 0), e o EC-unhide e o tratamento de
0x20 (nunca verdadeiros em produção) são ignorados. `ret` no 1º byte é seguro (prólogo ainda não
mexeu em rsp). Substitui (A2).

### Efeitos colaterais / observações
- **bit 0x20 e `FUN_20330` (`0x20330`)**: `FUN_20330` apenas decrementa um contador "DynamicPageCount"
  (grava via `[0x206cb8]+0x58` e `FUN_a3cd4(0x12)`) quando a página casada tem bit 0x20 (página
  dinâmica). As abas AMI são estáticas (sem bit 0x20); e tanto (A2) quanto (B2) evitam o casamento,
  então `FUN_20330` não é chamado para elas → **sem efeito colateral**.
- **Root `0x2710`**: deixado intacto em (A); em stock o root recebe bit0 e o Setup funciona — root não
  é aba, sem efeito visível. (B2) também não o esconde (bit0 nunca é setado).
- **Chamada `0x20330`**: idem acima; não disparada pelos patches propostos.
- **Timing / fallback de structs vivas**: (A) e (B) mudam o que `B0898`/`B0738` FAZEM; precisam estar
  no lugar ANTES do 1º build de dados (`FUN_35664`, guardado por `[0x258A78]`). Se aplicados com o
  Setup já construído/escondido, corrigir também as structs de página vivas: para cada página AMI,
  `ParentPageID(+0x12)=0` e limpar `PageFlags(+0x14) bit0`. Endereço da struct =
  `[0x25A678] + [0x259790][idx+1]`; `FormId` em `struct+0xA`. Um driver `Driver####` (Q4) corrige a
  imagem antes do Setup, então (A) ou (B) sozinhos bastam.
- Observação on-disk: RVAs acima são endereços em memória (ImageBase 0). Para patch no arquivo, as
  RVAs em `.data` (0x1A89E0–0x25A820) exigem conversão RVA→offset de arquivo da seção `.data`.

---

## Q4 — Quando o TSE entra em Setup; retorno de boot option; Driver#### antes do F2

### Entrada em Setup / OsIndications
TSE referencia as variáveis `L"OsIndications"` (`0x1BA9C8`, usada em `0xB008E`/`0xB010C`) e
`L"OsIndicationsSupported"` (`0x1C32C8`, usada em `0xAFFD8`/`0xB0057`) — todas na região de boot-flow
`0xAFFxx–0xB01xx`, sob `gEfiGlobalVariableGuid {8BE4DF61-93CA-11D2-AA0D-00E098032B8C}` (em `0x1A8AA0`;
é essa GUID, não "OsIndications" literal — e é referenciada em dezenas de GetVariable/SetVariable).
Logo o TSE anuncia `OsIndicationsSupported` (capacidade `BOOT_TO_FW_UI`) e consome o pedido
`BOOT_TO_FW_UI`. A entrada em Setup nesta plataforma ocorre por: (i) hotkey F2 detectado pelo
caminho de console/hotkey do BDS; (ii) `OsIndications` com `BOOT_TO_FW_UI` setado (ex.: Windows
"Reiniciar nas configurações de firmware UEFI" / `shutdown /fw`); (iii) caminho de falha de boot.
O BDS então invoca a entrada de Setup do TSE. Confiança: ALTA (strings/refs observadas no binário);
a semântica exata de clear do bit é padrão UEFI (MÉDIA-ALTA, não rastreada linha-a-linha).

### Módulos no dump
Confirmado no dump UEFIExtract (`3 BIOS region`): existe o módulo BDS padrão da AMI, pasta `4 Bds`,
e `329 AMITSE`. Portanto vale o fluxo BDS padrão do AMI Aptio V.

### Boot option de Shell que retorna ao firmware
`Boot#### → \EFI\biosmod\shellx64.efi` que dá "exit": o BDS recupera o controle quando a imagem
carregada retorna. Comportamento padrão UEFI/AMI: o BDS continua o laço de tentativa de boot —
tenta a PRÓXIMA entrada de `BootOrder`; se as opções se esgotarem/falharem, o AMI BDS cai no
Boot Manager / `BootManagerMenuApp` (NÃO entra em Setup automaticamente). Só entra em Setup se
`BOOT_TO_FW_UI`/hotkey pedir. Um "exit" do Shell retorna `EFI_SUCCESS` e o BDS segue para a próxima
ação, sem auto-entrar em Setup. Confiança: MÉDIA-ALTA (comportamento padrão AMI; o binário `Bds` não
foi desmontado nesta sessão — inferência do padrão, não rastreio direto).

### Driver####/DriverOrder antes do handshake de Setup — VIÁVEL
Pelo spec UEFI e pelo BDS da AMI, durante `BdsEntry` os `Driver####`/`DriverOrder`
(EfiBootManagerLoadDrivers — "load & connect drivers") são carregados/conectados na fase INICIAL do
BDS, ANTES das boot options e ANTES da avaliação de F2/`BOOT_TO_FW_UI` e do handshake de front page.
Como o AMITSE é driver DXE já residente (instala FORM_BROWSER2 no DriverEntry, muito antes do BDS),
um `Driver####` apontando para um driver DXE roda depois de todos os DXE (inclusive AMITSE) estarem
despachados/residentes, mas antes de o Setup ser entrado → **pode corrigir a imagem AMITSE em
memória (tabelas `0x1B56A0`/`0x1B5480`, PCD, ou as structs de página) antes do F2.** Este é o vetor de
patch pré-F2 viável. Confiança: MÉDIA-ALTA (comportamento padrão UEFI/AMI; presença do módulo `Bds`
confirma o fluxo padrão; ordem exata não rastreada no binário `Bds`).

---

## Tabela de confiança

| Item | Confiança |
|---|---|
| Q1: `FUN_1b888` ignora bit0/ParentPageID; SendForm(0x2712) exibe Advanced navegável | ALTA |
| Q1: FormId=0 → front page restrita (respeita hiding) | ALTA |
| Q1: SendForm usável em Shell/BDS, antes/depois da init | ALTA |
| Q1: gravação via ConfigAccess/RouteConfig (não cache privado) | MÉDIA (inferência arquitetural) |
| Q2: B0738 chamado por B0898, FUN_1e3b4, FUN_1e914; re-esconde em refresh/novo HII | ALTA |
| Q3: tabelas e RVAs/bytes dos patches; B08E8 `EB 21` correto; efeitos colaterais | ALTA |
| Q4: TSE consome OsIndications/BOOT_TO_FW_UI; módulos Bds e AMITSE no dump | ALTA (refs); MÉDIA-ALTA (semântica BDS) |
| Q4: Shell exit não auto-entra Setup; Driver#### roda antes do F2 | MÉDIA-ALTA (padrão UEFI/AMI) |
