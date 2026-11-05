# Samsung Galaxy Book2 BIOS unlock & undervolt (NP550XED / i7-1255U)

**Hidden AMI BIOS menus · Intel DTT throttling fix · power limits · AC loadline undervolt — no BIOS flashing**

🇧🇷 [Versão em português](README.pt-BR.md)

Unlocking power limits, undervolting and opening the hidden BIOS menus on the **Samsung Galaxy Book2 NP550XED
(i7-1255U)** **without flashing a modified BIOS**. Everything is done by editing NVRAM variables from the UEFI
Shell, and the hidden menus are opened through the firmware's own setup browser.

> ⚠️ **WARNING — read this first**
> - The offsets are valid **only for BIOS P11RGK.050** (2025-04-03). A different version means different offsets.
>   **Check them against the IFR of your own BIOS** before writing a single byte.
> - This laptop has **Intel Boot Guard (Verified Boot) + BIOS Guard**. **Flashing a modified BIOS = brick.**
>   Nothing here flashes the chip.
> - Wrong NVRAM values can prevent POST. Have a **chip backup** and know how to use a **CH341A** programmer
>   before you start.
> - No warranty. Use at your own risk. Independent project, not affiliated with Samsung, Intel or AMI.

> ### ⚖️ Disclaimer
> This repository is **documentation of a personal experiment only**, published for educational purposes.
> **The author accepts no responsibility or liability** for any damage, data loss, bricked laptop, voided warranty,
> instability, overheating, hardware wear or any other direct or indirect harm resulting from the use of this
> information, these scripts or programs. **Anything you do based on this material is entirely at your own risk.**
> Changing BIOS/NVRAM settings, voltages and power limits can damage your hardware and void the manufacturer's
> warranty. If you are not sure what you are doing, don't do it.

---

## Results at a glance

Load: FP64 matrix multiplication (numpy/OpenBLAS, all threads), 300 s, on AC power. Average excludes the first
30 s. Sensors read from HWiNFO every 1 s.

| Configuration | GFLOPS | Package | Temp. | VID |
|---|---:|---:|---:|---:|
| Factory (Samsung "Optimized") | 56 | 12.0 W | 65 °C | — |
| Factory (Samsung "High performance") | 62 | 13.0 W | 67 °C | — |
| Stage 1 — DTT off, PL1 25 W / PL2 51 W, Balanced plan | 120 | 20.1 W | 88 °C | 0.756 V |
| Final — + IA AC Loadline 1.40 mΩ, Balanced plan | 118–120 | 19.0 W | 83 °C | 0.733 V |
| **Final + liquid metal reapplied** | **116–120** | **18.7 W** | **67 °C** | **0.738 V** |

**~2.1× the factory multi-core performance** and, with liquid metal, **21 °C cooler** than before, with zero WHEA errors.

Other tests in the final state (with liquid metal):

| Test | Before liquid metal | After liquid metal |
|---|---|---|
| Single-thread FP64 (Max performance plan, 120 s) | 41.8 GF, P-core 2.85 GHz, 79 °C | **61.1 GF**, P-core 3.88 GHz, 85 °C |
| iGPU WebGL 300 s (GT AC LL 1.85 mΩ) | 23.7 fps, 1221 MHz, 92 °C | **24.4 fps**, 1250 MHz (max), 87 °C |

Factory iGPU (GT AC LL 3.20 mΩ): 22.3 fps at 1148 MHz.

---

## What we found (technical summary)

1. **The factory limiter is Intel DTT, not CPU temperature.** DTT writes PL1 = 12–16 W to MMIO (MCHBAR + 0x59A0)
   based on the **chassis/skin** sensors (SNS1/SNS2, Samsung's GDDV/PSVT "vault" table targets 49–52 °C).
   Turning DTT off in the BIOS (`Setup 0x6D2 = 0`) brings PL back to the BIOS value.
2. **There is a platform cap of ~20 W package / ~34 W system** (PBM PL2/PL3 driven by the EC/Psys). PL1 above
   ~22 W gives no sustained gain. A 65 W charger does not raise this cap (stock charger is 45 W).
3. **Offset undervolting does NOT work on this CPU.** The OC mailbox (MSR 0x150) only answers with
   `OC Lock 0x10E = 0` + `OC Feature 0x1D9 = 1`. Even then:
   - at runtime (ThrottleStop/Windows) writes are refused: 12th-gen *Undervolt Protection*;
   - from the BIOS (−50 mV offset at `0x1E0/0x1E2`, Ring at `0x1EC/0x1EE`) the policy reaches the FSP correctly,
     but pcode ignores it and VID does not change. There is no "Undervolt Protection" option in the IFR.
4. **⚠️ Dangerous trap:** setting `OC Feature 0x1D9 = 1` activates the **IA/GT IccMax Override (`0x347`/`0x34A`),
   whose factory value is 4 (= 1 A!)**, replacing the VR Current Limit. Write `0x347 = 320` (80 A) and
   `0x34A = 160` (40 A) **before** enabling 0x1D9.
5. **AC Loadline is what actually lowers voltage.** Undervolt Protection does not block the loadline (VR mailbox).
   IA AC LL 2.80 → 1.60 mΩ gave −23 mV, −0.8 W and −2.8 °C at the same performance; 1.40 mΩ was stable with only
   a marginal extra gain. **DC LL stays at 2.80 mΩ** so power telemetry remains accurate.
6. **For multi-core, the "Balanced" plan (P-core ≤ 2.4 GHz, E-core ≤ 1.8 GHz) beats "Max performance".** Under a
   ~20 W cap, high clocks just burn voltage: 120 vs 97 GFLOPS.
7. **Hidden BIOS menus (AMI Advanced/Chipset) without patching.** AMITSE has two "gates". The second one
   **always** hides the AMI tabs unless the EC is an engineering unit, and no NVRAM variable unlocks them. However,
   AMITSE's own `EFI_FORM_BROWSER2.SendForm` picks the start page by FormId and HII handle only, ignoring the
   hidden flag. `faseD_menu.efi` raises the `AMITSE_SETUP_ENTER` signal (the same one every F2 raises, so Setup
   publishes its formset to HII) and calls `SendForm(FormId)`. No patch, nothing persistent. A permanent "BIOS Avancada" boot entry (last in BootOrder: Shell → signal →
   `faseD_menu.efi 2712`/`2714`) opens these menus whenever you want; scripts are in `nsh/bios_avancada/`.
8. **Samsung software gotchas:** Samsung Settings' "Optimized" mode still caps the CPU by frequency (~12 W) even
   with DTT off; use "High performance". **Samsung Device Care** (`iveDeviceCareEngine.exe`) used ~0.8 core
   continuously after boot and cut multi-core by ~11 %; it was uninstalled without affecting Samsung Settings.
9. **Battery charge limit:** "Battery protection" (80 %) lives in Samsung Settings → SCAI → SMM → EC. It is not a
   BIOS option.

---

## Values written (BIOS P11RGK.050)

Variable GUIDs (boot-services only; Windows cannot read or write them):

| Variable | GUID | Size |
|---|---|---|
| Setup | `EC87D643-EBA4-4BB5-A1E5-3F3E36B20DA9` | 0xC81 |
| CpuSetup | `B08F97FF-E6E8-4193-A997-5E9E9B0ADB32` | 0x379 |

| Stage | Option | Variable:offset (size) | Default | Written |
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
| 2a | OverClocking Feature | `CpuSetup:0x1D9` | 0 | **1** (after IccMax!) |
| 2e | IA AC Loadline | `CpuSetup:0x132(2)` | 280 (2.80 mΩ) | **140** (1.40 mΩ) |
| 2e | IA DC Loadline | `CpuSetup:0x13C(2)` | 280 | 280 (leave it) |
| 3 | Logo delay | `Setup:0xC50(4)` | 2000 ms | **0** |
| 3 | Energy Efficient Turbo | `CpuSetup:0x1D5` | 1 | **0** |
| 3 | GT AC Loadline (iGPU) | `CpuSetup:0x134(2)` | 320 (3.20 mΩ) | **185** = `0x00B9` (1.85 mΩ) |

`setup_var.efi` syntax in the UEFI Shell, for example: `setup_var.efi CpuSetup:0x132(2)=0x008C`.

**Revert:** F2 → **F9** (factory defaults) undoes **everything**. To undo a single item, write its default value
with `setup_var.efi`. If the laptop no longer POSTs, reflash your backup with a CH341A.

---

## How to reproduce (outline)

1. **Back up the SPI chip** (Linux, read-only): run `flashrom -p internal -r` twice and compare the hashes. Keep
   the backup off the laptop.
2. **Extract and check *your* firmware:** UEFIExtract on the dump → Setup module → IFRExtractor. Confirm every
   offset and the current variable values. **Do not blindly trust the table above.**
3. **UEFI Shell + `setup_var.efi`** on a USB stick or the ESP, with a `startup.nsh` that does: `dmpstore` (variable
   backup) → write → read back → `reset`.
4. **One stage at a time.** After each one: boot, verify the values, run a 5-minute stress test, check Event
   Viewer for WHEA errors.
5. On Windows: with DTT off in the BIOS, the `ipfsvc`/`dptftcs` services have nothing left to do. Use a Balanced
   plan with a clock cap for multi-core work.

The scripts in this repository (`nsh/` folder) are exactly the ones that were used, with a backup before and a
verification after each write.

---

## Evaluated and rejected

- **Flashing a modified BIOS:** Boot Guard Verified Boot confirmed (`MSR 0x13A = 0x130000007F`) + AMI volume hashes
  + BIOS Guard.
- **UEFI driver (Driver####) with a patch:** if it hangs at boot, F9 cannot fix it; only a CH341A can.
- **TCC offset, PL3/PL4/Psys, C-states, IA CEP:** no gain, because the cap is the ~20 W PBM, not temperature.
- **Memory:** already runs DDR4-3200 with SAGV; XMP adds nothing.
- **BIOS administrator password:** **do not set one**. The NvramDxe filter then blocks setup_var.
- **PECI, PROCHOT, thermal trips, ME, TXT, DCI, BIOS Guard:** dangerous, left untouched.

---

## Repository layout

```
docs/              reverse engineering notes (Portuguese): IFR (catalog + CSV of all 4541 options), ACPI/DTT,
                   protections, battery/charger, SendForm / hidden menus
src/               biosmod.efi (read-only pre-OS diagnostics), faseD_menu.efi, faseD_sonda.efi (C, MSVC, no CRT)
nsh/<stage>/       startup.nsh for each stage (dmpstore → write → read back → reset) + armar_*.ps1 (ESP, BootNext, task)
nsh/bios_avancada/ permanent boot entry that opens the hidden AMI menus
scripts/windows/   measurement (HWiNFO shared memory, FP64 stress, WebGL GPU) and per-stage automated tests
scripts/linux/     SPI chip backup (flashrom, read-only) and charger/EC readout
scripts/analise/   Samsung BIOS package extraction and IFR parser
results/           CSVs (1 row/s) and logs for every stage; etapa*_gravacao = before/after readouts of each write
```

**Intentionally not included:** chip dump and NVRAM dumps (they contain serial number, UUID, MAC and the Windows
key in the MSDM table), Samsung firmware (copyrighted) and third-party binaries (see the links below).

---

## Credits and tools

- [setup_var.efi](https://github.com/datasone/setup_var.efi) — datasone
- [UEFI Shell](https://github.com/pbatard/UEFI-Shell) — pbatard
- [UEFITool / UEFIExtract](https://github.com/LongSoft/UEFITool) — LongSoft
- [IFRExtractor-RS](https://github.com/LongSoft/IFRExtractor-RS) — LongSoft
- [HWiNFO](https://www.hwinfo.com/) and [ThrottleStop](https://www.techpowerup.com/download/techpowerup-throttlestop/), used for diagnostics
- The idea of using AC Loadline on CPUs with Undervolt Protection came from a discussion in the OmenMon project

## License

Code: MIT (see `LICENSE`), provided "AS IS", without warranty of any kind. Documentation: CC BY 4.0.
Use at your own risk; see the [disclaimer](#️-disclaimer).
