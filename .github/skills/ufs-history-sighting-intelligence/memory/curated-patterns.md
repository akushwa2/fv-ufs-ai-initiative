# Curated Memory — UFS Sighting Patterns

Cross-issue rollups distilled from the database. Each pattern links to source record IDs.
When a new sighting matches a pattern's **triggers/fingerprint**, apply its **first moves** and
**log order**, then read the linked record(s) for full detail.

---

## Pattern P1 — UFS fabric/resource timeout on deep power-state entry
**Source records:** 16027585017 (cluster: 22021069833, 16027667860, 14025261732, 14023947750)
**Programs seen:** WCL · prior art referenced on PTL and LKF-era (class is long-standing)
**Recurrence:** 1 confirmed sighting/cluster (WCL). ← bump this + add programs/ticket IDs each time the pattern is seen again.

**Triggers**
- UFS as **primary storage** + **PKGC / S0ix enabled**.
- **Intel Gfx driver installed** (required — without it the platform stays PKGC0 and won't fail).
- Failure after boot or after sleep-exit.

**Fingerprint (how to confirm it's this class)**
- Host-controller `IS_` register has **SBFES + HBFES** set; last `IS_` read stuck in PSF trace.
- **VISA capture:** upstream cycle asserts **`ufs_prim_clkreq` + `req_sa=1` for PkgC exit**, then
  **downstream `int_sts` read hangs** (~**800 µs** gap observed).
- **PKGC counters** (`pm_tools.cstate.get_pkgc_entry_counters()`) frozen at PKGC10.1 (C10_2/C10_3 = 0).
- OR **MCA THREE_STRIKE** (e.g., CORE2 MLC) with non-posted read stuck **PSF4 → UFS** — but **MCA is NOT
  mandatory**; `debug.mca.analyze()` has returned **empty** in a confirmed failing capture.
- OR Windows **DPC_WATCHDOG_VIOLATION** with `storufs!UfsResetBus*` reset path taking >20s.
- Windows shows a **flood of D0/D3** calls to UFS beforehand (`_PS3`↔`_PS0` in the power-state trace).

**First moves (fastest discriminators)**
1. Limit PKGC to **C0/C1** → if stable, it's this power-state class (not the data path).
2. Uninstall Gfx driver → if failure vanishes, trigger is confirmed as deep-PKGC entry.
3. Do **not** chase the D0/D3 flood or disable PEP — proven not to help.

**Log order + WHEN to capture (decisive first)**
> WHEN matters as much as HOW: several captures are worthless if taken at the wrong moment.
1. **BEFORE triggering the repro:** arm **VISA** + **PSF trace** on the failing signature and attach **WinDbg** live (post-mortem dumps were unreliable). PSF armed *after* the hang captures nothing.
2. **AT the hang, before ANY reset/power-cycle:** halt cores, then read **`IS_` (SBFES/HBFES)**, **PMC `ufs*_pwr_sts`**, and **MCA decode** (`debug.mca.analyze()`). Reset/CATERROR clobbers these — capture them first.
3. **EARLY / OS-characterization stage:** **ACPI dump** (D0/D3 flood) and **WinDbg** stack (`storufs!UfsResetBus*` reset-path/watchdog).
4. **ONLY to close SI hypothesis:** **PA** (historically clean — run late, not first).
5. **DURING fix validation only:** **Solar** logs across the 100-cycle S0ix/S4/S5/WR/CR regression + residency.

**Likely root cause**
- **OCP/Sonics fabric timeout waiting for system resource**; the UFS IP **does not request LTR to
  the PMC**, so resources arrive too late during deep C-state → fabric timeout → `IS_` FATAL →
  stuck downstream read → BSOD/MCA/hang; OS reset overruns DPC watchdog.
- **Class:** design-rtl (missing LTR reporting), long-standing since LKF.

**Known fix / workaround**
- **BIOS:** report **UFS LTR ≈ 650µs**, but **selectively ignore/disqualify LTR on UFS-D3 / S0ix
  entry and re-qualify on D0 / S0ix exit** (plain 650µs alone blocks S0i2.1/S0i2.2).
- Verified by 100-cycle regression across S0ix/S4/S5/WR/CR; S0ix residency ~85–88%.
- IP/RTL fix was **declined** (won't-fix) — treat BIOS workaround as the accepted resolution on WCL.

**Prevention checklist (apply to new UFS bring-ups)**
- Confirm the UFS IP **reports LTR to PMC** before enabling PKGC with UFS as boot device.
- Add **`IS_` SBFES/HBFES + OCP-fabric-timeout** monitors and **MCA capture** default-on.
- Put **UFS-primary + S0ix + Gfx-driver-installed** in the default validation matrix.

**Open unknowns for this pattern**
- Exact BSOD bugcheck/minidump and full MCA status not preserved.
- Decisive traces referenced but not retrievable via HSD tooling — hold filenames/owners.
- Whether a later stepping ships an IP LTR fix (vs permanent BIOS workaround) is unconfirmed.

---

## Pattern P2 — UFS boot-time fuse-pull CDC race (PMC stuck at Phase-3 waiting IP_ready)
**Source records:** 16029205689 (clone chain: 22021505280, 16028605475; fix: 16029333243, 18044008985; prior-art: 1406831804)
**Programs seen:** WCL (A0 & A1). PTL & LNL do **not** see it — they static-disable UFS.
**Recurrence:** 1 confirmed sighting/cluster (WCL). ← bump + add programs/IDs each time seen again.

**Triggers**
- **Warm-reset cycling** (DPMO/QS reliability), UFS **brought up at boot then PHY power-gated**.
- WCL (does not static-disable UFS). **Sporadic — ~1 in 1000+ cycles.**

**Fingerprint (how to confirm it's this class)**
- PMC stuck at **Phase-3 bootflow `PC:0005`** polling **`ufs_ip_ready_status`** (never set); PMC SRAM
  trace shows **only WDT-expired**; **no MCA, no reset**; `PKGC_IDLE_ON_C0`.
- UFS **PHY** IP_ready asserted but **controller** IP_ready not.
- **Fuse-pull FSM stuck `fuse_pull_ready (001)`** (not `fuse_pull_done (006)`); **IOSF2OCP bridge FSM
  stuck "Fuse Pull Request"**, fuse-puller FSM **Idle**.
- **Fuse-Controller history:** `ufs_pga` request served but **IOSF2OCP-bridge request NOT received**.
- **Heisenbug:** enabling **IOSF-SB-trace / VISA masks it** (no repro with observability on).

**First moves (fastest discriminators)**
1. At the `PC:0005` hang, **do NOT reset** and **do NOT arm SB-trace/VISA** (they hide it).
2. **Scan dump** the hung setup; read **fuse-pull FSM** + **IOSF2OCP bridge FSM** — stuck `001`/"Fuse
   Pull Request" confirms this class.
3. PythonSV: `soc.pmc.arc.pc_histo()` (stuck `0xb0548`), `pm_tools.cstate.get_pkgc_current_state()`,
   `udr.ucie_pma_checkers()` (SB_PMA_FSM_STATE), Fuse-Controller history.

**Log order + WHEN to capture (decisive first)**
1. **AT the hang, before reset:** **scan dump** + PythonSV fuse/bridge FSM + Fuse-Controller history.
2. **Useful:** StatusScope dump (IOSF2OCP FSM illegal states); PMC SRAM / PMU (WDT, waiting IP_ready).
3. **Avoid as primary:** IOSF-SB-trace / VISA — they perturb the race (use only if it still repros).
4. **DURING fix validation:** high-volume WR/CS/S4 cycling across 3★/4★/5★ configs.

**Likely root cause**
- **PGCB / clock-domain-crossing (CDC) race** on IP-wake: PMC PGCB de-asserts SB reset while UFS PGCB
  exits WARMRST forcing the SB clock on — **unsynchronized** → reset edge asynchronous to PGCB clock →
  **metastability** (glitch on `fscan_mode`) → **fuse-pull request lost** → IP_ready never asserts.
- **Class:** design-rtl (CDC), same class as prior **HSD 1406831804**. IP_Request→IP_Ready window ~26µs.

**Known fix / workaround**
- **PMC-FW WA v3** (`...RemoveUFSIpReadyStatusCheck_v3`): PMC **ignores `UFS IP_Ready_STS`** (incl. the
  **PM Dashboard list** — the v2 miss) **and writes `0x3800` to `UFS_FUSE_REG1`** (device-ID). Not
  reproducible on A0/A1 across 12K+ SIV cycles. (v2 failed: missed the dashboard-list entry.)
- **Root-cause WA (Solution 2):** PMC-FW **~20µs / 50-PGCB-cycle guard band** between IP-wake and
  side-reset de-assert. RC2/WW51.2.

**Prevention checklist (apply to new UFS bring-ups)**
- CDC-review reset-vs-clock synchronization on IP-wake (guard band by design).
- Add **fuse-pull-completion + IP_ready timeout** monitors; default-on **scandump on Phase-3 stall**.
- Run **high-volume WR cycling** (sporadic bug needs volume; don't rely on SB-trace/VISA which mask it).

**Open unknowns for this pattern**
- `fscan_mode` glitch is the leading theory — not silicon-confirmed.
- Vnn/VnnAon droop check result and final guard-band (RC2) validation not captured.

---

## Pattern P3 — UFS recovery soft-hang on vendor endpoint-reset mismatch
**Source records:** 16029554884 (Issue#1 lost-READ tracked in a separate, not-yet-filed HSD)
**Programs seen:** WCL-U (A1), Windows 25H2.
**Recurrence:** 1 confirmed sighting (WCL). ← bump + add programs/IDs each time seen again.

**Triggers**
- HLK **Connected Standby IO Stress** (RapidFileVerify + ConnectedStandby + SCSICompliance, Driver Verifier on) with **UFS as primary** storage.
- **Windows 25H2** (24H2 does NOT repro). **Gfx + Wifi drivers installed** (clean OS alone won't assert CS).
- Failure during **S0ix entry/exit**, after a few successful recoveries.

**Fingerprint (how to confirm it's this class)**
- A **SCSI READ(06)** hits a **10 s unit-timeout** (`SRB.TimeOutValue = 0xa`, QueueTag 0x03); OS runs the hierarchical reset (`storufs!UfsResetBus → storport!RaidAdapterResetBus`).
- **FTH:** good ops end (`DBR Cleared → All Cmds Served Successfully`), then `CHK_BAD : Loop Starts Here`, a **~10 s dead gap**, then a recovery loop **polling UTRLDBR (0x58)** and **writing UTRLCLR (0x5C = 0xFDFFFFFF)**; **later** a databook-**illegal `UICCMD 0x39 = DME_ENABLE`**.
- **VISA @ PSF4/PSF0:** no transaction at UFS, none pending → the READ is **lost above PSF0** (D2D/compute).
- **Register compare after `DME_ENDPOINTRESET`:** **failing device (SK hynix HN8T15DEHKX075)** = link up, **`HCS.DP=1`, `IS_` clean**; **recovering device (Samsung KLUEG8UHGC-B0E1)** = link lost, **`DP=0`, `IS_.DFES` + `ULLS` set**.
- Bugchecks: `UNEXPECTED_STORE_EXCEPTION 0x154`, `KERNEL_DATA_INPAGE_ERROR 0x7A`; **no dumps** generated.

**First moves (fastest discriminators)**
1. Swap storage: **NVMe primary + UFS secondary** → if it vanishes, it's the UFS-primary recovery path.
2. Check **24H2 vs 25H2** → 25H2-only points here (OS recovery-flow change).
3. Force a dump with an **eng driver breakpoint at UFS reset** (live WinDbg **masks** it — Heisenbug).
4. **Do NOT** rechase PHY eq / PGCB / gear / PKGC — all disproven (see rule-outs).

**Log order + WHEN to capture (decisive first)**
1. **Eng-driver breakpoint at UFS reset** to force a memdump (WinDbg-attached passes 3/3).
2. **FTH + VISA @ PSF4/PSF0** synced to the dump across the 10 s window.
3. **PMC trace + D2D-CFI trace** across the timeout (for Issue#1, the lost READ above PSF0).
4. **PythonSV `hcs`/`is_`** register compare across the two vendor devices post-Endpoint-Reset.
5. **Avoid as primary:** PA (auto-stops with errors); Event Viewer (empty post-crash).

**Likely root cause**
- **Issue#2 (root-caused):** vendor **spec-implementation gap** — SK hynix keeps the link up with `IS_` clean after `DME_ENDPOINTRESET`, so storufs takes a path that **never HCE-toggles / re-inits** the link → recovery spins → **soft hang**; Samsung reports link-lost + `IS_.DFES` → HCE-toggle path → recovers.
- **Issue#1 (open):** a SCSI READ is **lost above PSF0** (D2D/compute) causing the unit-timeout that starts recovery. Root cause unknown; tracked separately.
- **Class:** spec-gap (device-fw vs OS recovery flow); fix lands in the **OS driver**.

**Known fix / workaround**
- **MSFT private driver** that forces a **controller reset (HCE toggle) after `DME_ENDPOINTRESET` & `DME_RESET`** → soft hang no longer reproduces on **either** Samsung or SK hynix. Productization under MSFT discussion (interim subset possible; part of the "2x2" ask). ACPI-based variant discussed but not present on any platform today.

**Prevention checklist (apply to new UFS bring-ups)**
- Qualify each **UFS device's `DME_ENDPOINTRESET` behavior** (link-lost + `IS_.DFES` vs link-up + clean) against the OS recovery flow **before** device sign-off.
- Ensure OS recovery **HCE-toggles regardless** of device error-status reporting.
- Put **UFS-primary + Win25H2 + Gfx/Wifi + HLK CS IO-stress** concurrency in the default matrix.

**Rule-out vs P1 (critical — don't confuse them)**
- **P3 repros with PKGC DISABLED**; P1 (`ufs-fabric-timeout-on-pkgc`) is PKGC-gated.
- P3 loses the transaction **above PSF0 with `IS_`/fabric clean**; P1 shows **`IS_` SBFES/HBFES OCP-fabric errors** with a stuck PSF4→UFS non-posted read.
- Both share the platform surface (UFS-primary/S0ix) and the `storufs!UfsResetBus` OS path — the PKGC-disabled test + the `IS_`/PSF read are the deciders.

**Open unknowns for this pattern**
- Issue#1 root cause (where the SCSI READ is lost above PSF0) — unknown; CFI/D2D analysis pending.
- The separate HSD ID for the unit-timeout — not yet filed.
- Whether MSFT ships the full HCE-toggle change or an interim subset.
- Why `DME_ENABLE` and the PMC user-data `0x15B0–0x15B5` writes appear in the recovery path.

---

## Pattern P4 — P2SB sideband EOI bypasses MSI completion → IOAPIC RIRR stuck (line-based interrupts)
**Source records:** 16030172470 (cluster: 16025859186 root-cause IP bug, 14027442505, 16030673570, 16028974551, 16030803619, 13015782827, 16031730035)
**Programs seen:** WCL, PTL (fixed in NVL; WCL-R/MNL also named). ← bump + add programs/IDs each recurrence.
**Recurrence:** 1 confirmed sighting/cluster (WCL).

> **This is NOT a UFS fault.** UFS is only the *exposer* — a heavy-I/O, **line-based level-triggered**
> interrupt device. The bug is in the **P2SB bridge**. Any IP on legacy line-based (level) interrupts is
> exposed. Do not chase UFS link/PHY/protocol; the UFS `IS_` is clean apart from a normal completion.

**Triggers**
- **S4-hibernate resume** or **warm-reset** cycling with **heavy UFS I/O**.
- UFS (or any IP) using **legacy line-based, level-triggered** interrupts (WCL UFS has **no MSI generation**).
- **Corp config** (UFS enabled); **x1 SDHC expedites**. Repro within **< 100 WR/S4 cycles**.

**Fingerprint (how to confirm it's this class)**
- **IOAPIC `rte_line_25.remote_irr` (RIRR, bit14) = 1 STUCK** + `delivery_status`=1, `trigger_mode`=1 (level), `polarity`=1 — the decisive read.
- UFS **`IS_` shows ONLY `utrcs`=1**; **`SBFES`/`HCFES`/`DFES` = 0** → no UFS fault.
- **VISA:** `servicePCmdValid[3]`→`[0]`, `itss/msigen/w2sbsm_ps` `0x3→0x5→0x0` → EOI/posted prioritized over MSI completion to ITSS.
- Symptom: HCI completes (CNR set, doorbell cleared) but **ISR never fires** → 30 s StorPort `UnitTimeout` → reset-cascade **LUN→DEVICE→BUS** → recovers (polling) → **repeats** → `0x9F` (DRIVER_POWER_STATE_FAILURE). Event logs **500** (Unit Timeout) + **550** (hierarchical reset).
- **Proof it's the P2SB bug:** on NVL, set chicken bit `pcd.p2sb0.cfg.p2sbc.ccpeome = 0x1` (disables the NVL fix) → issue reproduces.

**First moves (fastest discriminators)**
1. At the hang, read **`rte_line_25` (RIRR)** + UFS **`IS_`** together → RIRR stuck + IS clean = this class.
2. Do **not** chase **NAC-bad**, **UFS PHY equalization** (−6 dB sweep), or a driver doorbell-multi-write theory — all proven dead ends.
3. A bare `set_eoi` does **not** recover a wedged line — don't conclude EOI "worked" from it.

**Log order + WHEN to capture (decisive first)**
1. **AT the hang, before any reset:** halt, read `rte_line_25.remote_irr` + UFS `IS_`.
2. **To prove ordering:** VISA `servicePCmdValid[3]/[0]` + `w2sbsm_ps` (trigger FTH on StartCpl→CplDone > 5 µs).
3. **To localize:** PSF-OBS around the last-good vs failing ISR (UTRLDBR `0x58`, EOI vec `0x81` @ `0xFEC00040`).
4. **OS side:** WinDbg 0x9F + event logs 500/550; PA only to close the UFS-clean hypothesis (late).

**Likely root cause**
- **P2SB PCIe posted-vs-non-posted ordering-rule implementation bug** (fixed NVL, missed WCL/PTL): `MWr`→`CrWr` fill the **sbep FIFO**; an **EOI (posted)** bypasses the **MSI completion** into the FIFO (`selectedPMaster` flips 3→0, `servicePCmdValid[3]&[0]` asserted). The IOAPIC completion that sets **RIRR=1 arrives after the EOI**; EOI seen while RIRR=0 is **discarded**; the late completion sets **RIRR=1 permanently** → level line wedged.
- **Class:** design-rtl.

**Known fix / workaround**
- **NVL:** HW fix in P2SB (`16025859186`) — EOI special-write cannot pass the MSI completion.
- **WCL/WCL-R/MNL (no HW fix; SoC BugEco `16030673570` rejected):** **OS mitigation** — Root-OS **IOAPIC `IOREGSEL` read immediately before the EOI write** (fences the late completion; works Hyper-V on/off, no HV change). Shipped in **25H2'7D**. **Must be UFS-scoped** — an all-IP backport caused **IOMMU_INTERRUPT_REMAPPING_FAULT (0x1fb)** / `pc:Ab04` / UCSI-9F regressions.
- **Alt WA:** move UFS IRQ **level → edge** (UFS IP team: no impact).
- **Long-term:** UFS IP → **MSI** in **HammerLake** (PCR `16030590109`).

**Prevention checklist (apply to new bring-ups)**
- **Enable UFS in Corp config** validation (4/5-star, Platform + CVE) — the detection gap here (AR `16031730035`); the bug was **Pre-Si detectable**.
- Add **`rte_line_N.remote_irr`-stuck** + **IOAPIC EOI/RIRR ordering** monitors for any **line-based level-triggered** heavy-I/O IP.
- Prefer **MSI/edge** for heavy-I/O IPs where possible.

**Open unknowns for this pattern**
- `16030803619` (`pc:Ab04` S4 hang) is **open** — WA-regression vs independent issue not fully closed.
- Errata `13015782827` write-up still empty.
- Residual brief UFS 100%-usage peak after 7D — expected or not — unanswered.
