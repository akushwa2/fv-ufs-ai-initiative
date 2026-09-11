---
name: how-to-capture-logs
description: "Sub-skill of unified-ufs-log-analysis — the per-log HOW catalog for UFS debug. One entry per log/trace/register: WHEN to take it, HOW to capture (with wiki placeholder), how to DECODE it, HEALTHY-vs-FAULT reference, and tool/owner. USE WHEN you need the exact procedure for a specific UFS log: PSF trace, VISA, PA, WinDbg, PythonSV/MCA, ITP register reads (IS_/SBFES/HBFES, UECPA/UECDL/UECN/UECT, PMC pwr_sts), ACPI dump, crashlog, Solar, StatusScope."
---

# How to Capture UFS Logs — Procedure Catalog

Each entry is the single source of truth for that log type. `TODO(...)` markers are **honest gaps**
for an SME to fill — do not guess commands. Log types below were seeded from sighting `16027585017`
(pattern `ufs-fabric-timeout-on-pkgc`); add new log types as new sightings introduce them.

> Legend — **WHEN**: the debug stage/trigger to capture · **HOW**: capture procedure ·
> **DECODE**: how to read it · **HEALTHY vs FAULT**: baseline vs failing signature ·
> **TOOL/OWNER**: who owns it · **WIKI**: authoritative procedure link.

---

## 1. PSF trace (Primary Scalable Fabric transaction trace)
- **WHEN:** Arm **BEFORE** triggering the repro (power-state/fabric bug suspected). Useless if armed
  after the hang — it must capture the failing signature at the moment of the stall.
- **HOW:** `TODO(wiki): exact PSF trace arm/capture procedure & tool invocation.` Arm on the failing
  signature, then run the boot/sleep-wake cycle that repros; save with the failing cycle ID.
- **DECODE:** `TODO(wiki): how to read PSF trace output / decoder.` Look for the last outstanding
  transaction and where it stalled (e.g., **PSF4 → UFS**).
- **HEALTHY vs FAULT:** Healthy = transactions complete with matching completions. Fault = last
  transaction to `IS_` register **stuck / no completion**; downstream non-posted read to UFS hung.
- **TOOL/OWNER:** `TODO(owner): PSF trace SME / team.`
- **WIKI:** `TODO(wiki-link)`

## 2. VISA capture (monitor-port signal visibility)
- **WHEN:** Set up **first**, before the failing cycle — captures whether UFS is alive *during* the hang,
  and across the PKGC-exit window to catch the wake/hang transition.
- **HOW:** `TODO(wiki): VISA monitor-port setup & signal selection for UFS.` Capture UFS monitor-port
  signals across the repro; watch PMC/UFS power + ISM signals.
- **DECODE:** `TODO(wiki): VISA signal decode reference.` Key signals observed: `ufs_prim_clkreq`, `req_sa`,
  `ufspw1_pmc_pgd0_pg_req_b`, `ufsx2_pmc_pgd0_pg_req_b`, `pmcm_cstate_ea`, `PMCMCPPMFA_ps`,
  `prim_ism_agent_in/fabric_in/fabric_out`.
- **HEALTHY vs FAULT:** Fault-case datapoint: UFS **still active and accepting requests** during the
  failure (rules out "device fell off the bus"). Decisive fault signature (observed): **upstream cycle
  asserts `ufs_prim_clkreq` + `req_sa=1` to force a PkgC exit**, then **downstream `int_sts` read hangs**,
  measured gap **~804.432 µs**.
- **TOOL/OWNER:** `TODO(owner): VISA SME / team.`
- **WIKI:** `TODO(wiki-link)`

## 3. PA — Protocol Analyzer (UFS link protocol capture)
- **WHEN:** Only once **signal-integrity is a live hypothesis** — run to *close* SI, not to open debug.
- **HOW:** `TODO(wiki): PA hookup & capture procedure for UFS M-PHY/UniPro link.`
- **DECODE:** `TODO(wiki): PA trace interpretation (link states, errors).`
- **HEALTHY vs FAULT:** In sighting 16027585017 the PA showed **no SI suspect** — a door to close early.
- **TOOL/OWNER:** `TODO(owner): PA / SI debug SME.`
- **WIKI:** `TODO(wiki-link)`

## 4. WinDbg (Windows kernel debug — OS-side stack)
- **WHEN:** At the BSOD/DPC_WATCHDOG; **attach live BEFORE the repro** (post-mortem full dumps were
  unreliable for this bug).
- **HOW:** `TODO(wiki): KD/WinDbg live-attach setup for UFS-boot target.` Then `kv`, `.frame`,
  `!error`, `!storagekd.storadapter`.
- **DECODE:** Read the DPC stack. Fault signature: `storufs!UfsResetBusDpc → UfsResetBus →
  UfsIntelLkfResetBus → UfsStopAdapter → storport!StorPortStallExecution` (UFS bus reset >20s → watchdog).
- **HEALTHY vs FAULT:** Healthy = no long-running DPC in storufs reset path. Fault = watchdog assertion
  (`nt!KeAccumulateTicks`) with storufs reset path stalled.
- **TOOL/OWNER:** `TODO(owner): Windows storage/UFS driver SME.`
- **WIKI:** `TODO(wiki-link)`

## 5. PythonSV — MCA decode & silicon register access
- **WHEN:** Immediately after an MCA/CATERROR/three-strike, **BEFORE power-cycle** (MCA banks lost on reset).
- **HOW:** `TODO(wiki): PythonSV env setup & connection.` Then `debug.mca.analyze()`; collect pysvlogs.
- **DECODE:** `TODO(wiki): MCA bank decode reference.` Identify bank/core. Fault signature seen:
  **THREE_STRIKE on CORE2 MLC bank**.
- **HEALTHY vs FAULT:** Healthy = no MCA logged. Fault = THREE_STRIKE tied to stuck non-posted read to UFS.
  **Nuance (observed):** `debug.mca.analyze()` may return **empty (no machine-check errors)** even in a
  failing PKGC-hang capture — MCA is **not mandatory** for the `ufs-fabric-timeout-on-pkgc` signature.
- **TOOL/OWNER:** `TODO(owner): PythonSV / silicon debug SME.`
- **WIKI:** `TODO(wiki-link)`

## 5b. PythonSV — PKGC entry counters
- **WHEN:** at/around the hang, to see which package C-states were actually reached.
- **HOW:** PythonSV `pm_tools.cstate.get_pkgc_entry_counters()`. `TODO(wiki): pm_tools setup.`
- **DECODE:** returns per-state entry counts (C6_1, C6_2, C10_1, C10_2, C10_3).
- **HEALTHY vs FAULT:** Fault datapoint seen: **C10_1=532 reached, C10_2=C10_3=0** (reaches PKGC10.1, never
  deeper); **identical across two consecutive reads → counters frozen** = system stuck at capture.
- **TOOL/OWNER:** `TODO(owner): power-management SME.`
- **WIKI:** `TODO(wiki-link)`

## 6. ITP / register reads — UFS host controller & PMC registers
- **WHEN:** **At the hang, before ANY reset/recovery** (recovery clobbers these). Halt cores first.
- **HOW:** `TODO(wiki): ITP/PythonSV register-read procedure for UFS host controller & PMC.`
- **DECODE / key registers:**
  - `IS_` (Interrupt Status Register) → check **SBFES** & **HBFES** (fabric-error status bits).
  - `UECPA`, `UECDL`, `UECN`, `UECT` (UFS error registers) → may be **unreadable/return 0 under CATERROR**.
  - PMC: `socket0.soc.pmc.pmu.ip_pwr_sts_1.ufsx2_pwr_sts`, `...ip_pwr_sts_0.ufspw1_pwr_sts`
    → `0x1` = **not power-gated** (controller/clock still up).
  - `TODO(wiki): full register offset/field decode reference for UECPA/UECDL/UECN/UECT.`
- **HEALTHY vs FAULT:** Healthy = `IS_` no fatal bits; error regs readable/clean. Fault = **SBFES+HBFES
  set**; error regs unreadable/0 under CAT error.
- **TOOL/OWNER:** `TODO(owner): ITP / silicon register SME.`
- **WIKI:** `TODO(wiki-link)`

## 7. ACPI dump (OS power-management / device state)
- **WHEN:** Early, during OS-behavior characterization (before going to silicon).
- **HOW:** `TODO(wiki): ACPI dump capture procedure on failing boot.`
- **DECODE:** `TODO(wiki): ACPI dump interpretation.` Look at D0/D3 transition traffic to UFS.
- **HEALTHY vs FAULT:** Fault-case = abnormal **flood of D0/D3 calls** to UFS (symptom, not root cause).
- **TOOL/OWNER:** `TODO(owner): platform/ACPI SME.`
- **WIKI:** `TODO(wiki-link)`

## 8. Crashlog (platform crash/error log)
- **WHEN:** At/after the failure (listed in the HSD `debug_tools` field for this sighting).
- **HOW:** `TODO(wiki): crashlog collection procedure & tooling.`
- **DECODE:** `TODO(wiki): crashlog decode reference.`
- **HEALTHY vs FAULT:** `TODO: expected clean vs error signature.`
- **TOOL/OWNER:** `TODO(owner): crashlog SME.`
- **WIKI:** `TODO(wiki-link)`

## 9. Solar (regression/residency logging app)
- **WHEN:** During **fix validation only** — across the full regression (S0ix/S4/S5/WR/CR), not initial debug.
- **HOW:** `TODO(wiki): Solar app setup & log capture.` (version seen: `3.25.204.0`).
- **DECODE:** `TODO(wiki): Solar log/residency interpretation.`
- **HEALTHY vs FAULT:** Pass = clean cycles + S0ix residency (~85–88% in the fixed case).
- **TOOL/OWNER:** `TODO(owner): Solar / power validation SME.`
- **WIKI:** `TODO(wiki-link)`

## 10. StatusScope (Axon record-viewer captures)
- **WHEN:** `TODO`: not yet confirmed for any sighting in this database (earlier attribution of a
  waveform to StatusScope was corrected — that evidence was actually a **VISA capture**, see entry 2).
- **HOW:** `TODO(wiki): StatusScope capture & share procedure.` (axonsv record-viewer).
- **DECODE:** `TODO(wiki): StatusScope interpretation.`
- **HEALTHY vs FAULT:** `TODO`.
- **TOOL/OWNER:** `TODO(owner): StatusScope / silicon debug SME.`
- **WIKI:** `TODO(wiki-link)`

---

## Template for adding a new log type
```
## N. <Log name> (<what it is>)
- **WHEN:** <stage/trigger to capture>
- **HOW:** TODO(wiki): <capture procedure> · <tool invocation>
- **DECODE:** TODO(wiki): <how to read it>
- **HEALTHY vs FAULT:** <baseline> vs <failing signature>
- **TOOL/OWNER:** TODO(owner): <SME/team>
- **WIKI:** TODO(wiki-link)
```
