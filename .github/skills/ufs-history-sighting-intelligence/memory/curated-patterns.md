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
