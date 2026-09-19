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
