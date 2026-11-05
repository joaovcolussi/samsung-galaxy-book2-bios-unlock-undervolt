# Fase D — Menus ocultos da BIOS (estudo completo, NADA gravado)

Máquina: Galaxy Book2 NP550XED, BIOS P11RGK.050 (AMI Aptio V, Boot Guard Verified Boot + BIOS Guard).
Fonte: dump do chip `backups\bios_fd_me_bios.bin` → `AMITSE.efi` (SHA256 d4f06099…a603), PcdPeim, SiliconPolicyPeiPreMem.
Regra do usuário (04/11/2026 ~18:25): **estudar por completo; só aplicar quando houver certeza.**

## 1. Correção do estudo anterior (03_protecoes_variaveis_menus.md §3)
O documento 03 dizia que bastava zerar o PCD 0x5A5A0012 (ou patch `74 21 → EB 21`). **Está incompleto.**
Existem **dois portões em sequência** na inicialização do Setup:

| | Função (RVA) | O que faz | Condição |
|---|---|---|---|
| Portão 1 | `0xB0898` (gancho 0xFFFF0022, chamado 1× por `FUN_35664`, init do Setup) | Promove a aba de topo (`ParentPageID=0` em `0xB094D`) cada página da tabela `0x1B5480` (0x2711…0x271B) | Se `PCD Get8(EEE8EEBE…,0x5A5A0012) ≠ 0` **não promove** 0x2711, 0x2712, 0x2714–0x2717 |
| Portão 2 | `0xB0738` (chamado no fim do portão 1 e também em `0x1E40F` e `0x1EC74`) | Para cada página da tabela `0x1B56A0` liga `PageFlags bit0` (= **oculta**) e limpa bit 0x20 | **Sempre**. Só desoculta 0x2712/0x2714 se o EC for de engenharia (abaixo) |

Tabela `0x1B56A0` (portão 2): 0x2710 (raiz), formsets `aca9f304-21e2-4852-9875-7ff4881d67a5` e
`c25f2b5f-9a82-4e3b-8af9-e627e7ab3673` (formId 0), **0x2712, 0x2714, 0x2711, 0x2715, 0x2716, 0x2717**.

Condição de engenharia do portão 2 (só para Advanced 0x2712 e Chipset 0x2714):
1. Flash `0xFF5401F0` = cabeçalho `"$SBVC"` do **firmware do EC** (bytes `24 53 42 56 43 10 50 …`, checksum em 0x5401FF) — existe e é válido;
2. `FUN_A1D34`: comando EC `0x72`, bit 4 → `'E'`; senão devolve o byte da flash 0x5401F6 = `0x50` (`'P'` = produção);
3. global `[0x258FA0]` (`FUN_A2170`, comando EC `0x83`, 7 bytes) começa com `'M'`.
Numa máquina de produção isso é falso → **nenhuma variável, PCD ou NVRAM libera as abas sozinha.** Mudar o EC = gravar firmware do EC → fora de cogitação.

## 2. O PCD 0x5A5A0012 (portão 1)
- Banco de PCD PEI (PcdPeim, versão 7): ExToken 0x5A5A0012 → token local 422, `LocalTokenNumber = 0x010033E3`:
  tipo **DATA** (não HII, não VPD), UINT8, na área não inicializada (padrão 0). → `Set8` muda **só a RAM do boot atual**,
  nunca a NVRAM. Some no próximo reset.
- Gravado só por `SiliconPolicyPeiPreMem` (a partir do pad GPIO 0x09030006, strap de hardware).
- **Lido só pelo AMITSE** (varredura de todos os módulos do dump: o token 0x5A5A0012 aparece só em PcdPeim,
  SiliconPolicyPeiPreMem e AMITSE). `SecEcPei` e `SiInitPreMemFsp` usam **outro** PCD (0x5A5A0011).
  → zerar 0x5A5A0012 em DXE não afeta nada além da exibição dos menus.
- Protocolo usado: PI `EFI_PCD_PROTOCOL` {13a3f0f6-264a-3ef0-f2e0-dec512342f34}: Get8 em +0x08, **Set8 em +0x40**.

## 3. Memória do AMITSE
- PE32+ x64, ImageBase 0, SizeOfImage 0x277560, DXE boot-service driver (subsystem 11).
- Seções alinhadas a 0x20 (não 4 KB) → a proteção de memória do DXE não consegue marcar `.text` como RO.
  As tabelas 0x1B5480/0x1B56A0 estão em `.data` (RW) de qualquer forma.
- Instala o próprio `EFI_FORM_BROWSER2` (interface em RVA 0x1A9918 = {SendForm 0x19F90, BrowserCallback 0x1A6CC}) e
  **desinstala** qualquer FormBrowser2 que exista antes (0x19F04). → base do AMITSE em runtime = `SendForm − 0x19F90`.
- Sem entrada "Enter Setup" no BootOrder (bcdedit /enum firmware: Windows, BIOSmod UEFI Shell, kali, UEFI OS).

## 4. Opções que os menus AMI expõem (riscos)
Ver `..\01_opcoes_IFR_catalogo.md` §"Lista de opções PERIGOSAS": memória (sem POST e sem F9), tensões fixas/mínimas,
IccMax/VR, BCLK/FLL, PROCHOT/térmico. Nas abas AMI também: Security (Secure Boot keys, TPM clear, senhas → senha de
supervisor ativa o filtro NvramDxe, ver 03 §1.2), Chipset (ME, PCIe, flash protection), Boot (Fast Boot — pode tirar o F2).
**Tudo o que esses menus fazem já é alcançável hoje por `setup_var` com os offsets do IFR**; o menu é conveniência.

## 5. Caminho escolhido: SendForm do próprio AMITSE (sem patch) — detalhes em 05_RE_sendform_entrada_setup.md
- `SendForm` (0x19F90) grava o FormId pedido e roda a engine; os portões continuam rodando, MAS a escolha da página
  inicial (`FUN_1b888`) casa só FormId + handle HII e **ignora PageFlags bit0 e ParentPageID** → a form pedida abre e os
  filhos são navegáveis. FormId=0 cai na visão restrita (abas Samsung). Confiança ALTA (estática).
- Salvar (F10) passa pelo fluxo HII normal (ConfigAccess/RouteConfig) = mesmo efeito de salvar no F2. Confiança MÉDIA.
- Sair do Shell com `exit` volta ao BDS (próxima entrada do BootOrder); não entra no Setup sozinho.
- Driver####/DriverOrder rodam antes do F2 → daria para mostrar as abas no próprio F2 com patch só-de-dados
  (PCD Set8=0 + FormIds em 0x1B5710/30/50/70/90/B0 → FFFF). **NÃO recomendado**: um driver que trava no boot impede o
  Windows e o F2, e F9 não apaga Driver#### (recuperação = CH341A). O SendForm dá o mesmo acesso sem persistência.

| Caminho | Grava algo? | Persistente? | Risco do método | Abas no F2? |
|---|---|---|---|---|
| **A. `faseD_menu.efi <FormId>` no Shell (SendForm)** | não (só se você salvar no menu) | não | ~zero; pior caso trava → desligar | não (abre form por form) |
| B. Driver#### com patch de dados | não grava firmware | sim (todo boot) | médio-alto (boot preso) | sim |
| C. Gravar EC/flash | sim | sim | brick | descartado |

## 6. Ferramentas (prontas, NÃO executadas) — fontes em biosmod\src\, build_faseD.cmd
- `biosmod\faseD_sonda.efi` (SHA256 8711E5A8…4A9C) — SOMENTE LEITURA: PCD, base do AMITSE por 2 métodos, bytes dos
  portões/tabelas, flag de init, páginas, cabeçalho $SBVC.
- `biosmod\faseD_menu.efi` (SHA256 0A5FBDC3…A693): `listar` (só lê o banco HII e acha o formset Setup) ou `<FormId hex>`
  (2711 Main, 2712 Advanced, 2714 Chipset, 2715 Security, 2716 Boot, 2717 Save&Exit). Antes de abrir confere que o
  FormBrowser2 é o AMITSE esperado (assinatura do portão 1) e que o formset Setup existe 1 vez; senão aborta.

## 7. Plano de teste em degraus (cada degrau precisa de OK explícito do usuário)
- **D1 — só leitura, automático:** startup.nsh do ESP roda biosmod.efi + faseD_sonda.efi + `faseD_menu.efi listar`,
  grava .txt no ESP e volta ao Windows. Confere base/assinaturas/PCD/handle. Nada é aberto nem gravado.
- **D2 — menu aberto, SEM salvar:** startup.nsh com "parada" (fica no Shell); o usuário digita
  `fs0:\EFI\biosmod\faseD_menu.efi 2712`, navega, sai com ESC → descartar. Fotografar telas de interesse.
- **D3 — mudança real (opcional):** só opção a opção, conferida antes contra o IFR e a lista de perigosas;
  preferir setup_var (offset exato, com backup dmpstore). Nunca: memória, tensões fixas, IccMax/VR, BCLK, PROCHOT,
  senhas, Secure Boot keys, ME, Fast Boot.
- Recuperação: nada persiste em D1/D2. Em D3: F2 → F9, ou setup_var com o valor antigo, ou CH341A (último recurso).
