# Log Module — Scan Dump (DFT scan-chain state extraction)

> Reads the log **against an issue**, never standalone. §5 is trained from a **known-good/passing** capture;
> §7–§8 are trained from **failing** sightings. The **delta** between the two (on the §5 watchlist) is the detector.

```yaml
log_type: scandump
aka: [DFT scan dump, scandump_csv, Nanoscope scan dump, scan state extraction]
captures_layers: [HCI, UniPro, M-PHY, fuse-PGCB]   # RTL-internal FSM/flop state, per IP partition
analyzer_mcp: none                                  # pysvtools.nanoscope decodes; exported CSVs read directly
mcp_status: gap
schema_ready: no
time_base: n/a                                      # point-in-time snapshot of flop/FSM state, NOT a timeline
provides_anchors: [FSM state at hang, ip_ready flop state, fuse-puller/bridge FSM state]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
A **DFT scan-chain extraction**: the raw value of (nearly) every flop/FSM bit in an IP at a single instant,
decoded to `signal_path,0xVALUE` pairs. It sees **RTL-internal state the register interface cannot** —
FSM encodings, gasket/CDC flops, puller/bridge handshake bits.
- **One CSV per IP partition:** `export/scandump_csv2/dfx_par<ip>_scandump.csv` (e.g. `dfx_parpmc`, `dfx_parcse`,
  `dfx_parufsphy`, …). ~15–17k signals per UFS partition.
- **`dfx_parufsphy` is the WHOLE UFS partition, not PHY-only** `[confirmed]`: despite the "phy" in the name,
  the single UFS scan partition (16,934 signals) covers the **UFS controller + IOSF2OCP bridge + fuse-puller +
  M-PHY** together. There is **no separate UFS-controller partition**. Signal categorization (verified on
  16029205689's dump):

  | Block token in signal path | # signals | Role |
  |---|---|---|
  | `scc_ufs_top` | 16,235 | UFS SCC top wrapper (nearly everything nests under it) |
  | `mphy` | 7,850 | **M-PHY** (PHY layer) |
  | `dwc_ufshc` | 4,260 | **DesignWare UFS host controller** (the controller) |
  | `pgcb` | 1,162 | **PGCB** (power-gate/clock — the CDC block at fault) |
  | `iosf2ocp` / `scc_iosf2ocp` | 1,128 / 1,109 | **IOSF2OCP bridge** |
  | `fuse_puller` | 103 | fuse puller |
  | `btrs` | 33 | buttress |
  | `i_fp_ip_fsm` | 25 | fuse-puller FSM |
  | **partition total (`ufsphy`)** | **16,934** | **whole UFS subsystem** |

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** **at the hang, before ANY reset.** Scan is destructive to run-state; take it once, last.
- **HOW:** scan-dump the failing setup (produces the `dfx_par*_scandump.csv` export set). `TODO(wiki): exact
  scan-dump trigger/collection procedure + `pysvtools.nanoscope` decode command.`
- **WHY:** it is the **only reliable evidence for a timing race** — IOSF-SB trace / VISA perturb and mask the
  bug, but a post-hang scan dump freezes the true FSM state. This is what caught the fuse-puller/bridge stall
  in 16029205689 when live tracing couldn't.

## 3. Analyzer — GAP (skill-guided decode)
No MCP. Two paths:
1. **Decode raw scan** → `pysvtools.nanoscope` (maps scan chain → named signals). Needs the project scan spec.
2. **Read the already-exported CSVs** (fastest) → grep `dfx_par<ip>_scandump.csv` for the §5 watchlist signal
   paths; each line is `full.signal.path,0xVALUE`. FSM-state signals decode via the RTL state enum (ask the IP
   owner / RTL for the encoding — scan gives the *number*, not the state name).

## 4. Normalized output → common event schema
- No native `ts` — stamp with the **hang instant** (merge anchor) so it lands on the timeline.
- Emit one event per decisive watchlist signal: `{source: scandump, layer, type: "FSM-state"|"flop-state",
  severity, raw: 0xVALUE, decoded: "<state name>"}`.
- **Anchors it provides:** fuse-puller FSM state, IOSF2OCP bridge FSM state, `ip_ready` flop — align with the
  register-dump `ufsx2_ip_ready_sts` and the PMC FW-trace "waiting UFSX2".

## 5. Healthy vs failing reference — WATCHLIST (the detector)
> **The trained core.** Fault column = **verbatim reads from the 16029205689 dump** (`dfx_parufsphy`,
> `dfx_parpmc`). Healthy column = fill from a **UFS-boot passing scan dump** (to be provided), captured at a
> comparable stage; tag each golden value stable/variable. `TODO(golden-log)`.
>
> **Two fuse pullers exist — this is the crux.** A **PGA/PHY-side** puller (`…/mtl_mpphy_x4_pga/…/fuse_puller`)
> and an **IOSF2OCP-bridge-side** puller (`…/scc_iosf2ocp_top/…/FUSE_ENABLE_1.i_fuse_puller`). The sighting's
> "`ufs_pga` served but IOSF2OCP-bridge request never received" maps onto these two.
> **Common root `…/` = `dfx_parufsphy/parufsphy_pwell_wrapper/ufs/scc_ufs_top/`.**

| Watchlist signal | IP block | Healthy | Fault @ hang (verbatim) | Meaning | Sighting |
|---|---|---|---|---|---|
| `…/mtl_mpphy_x4_pga/ufs_mipix2_buttress_top/phy_vnn/fuse_puller/i_fp_ip_fsm/state` | PGA fuse-puller FSM | `TODO` | `0x0` | PGA puller FSM (raw enum; `0x0`=Idle per decode) | 16029205689 |
| `…/scc_iosf2ocp_top/iosf_ocp_top/i_iosf_ocp_br/i_iosfsb_handler/FUSE_ENABLE_1.i_fuse_puller/i_fp_ip_fsm/state` | bridge fuse-puller FSM | `TODO` | `0x0` | bridge puller FSM — not mid-pull at snapshot | 16029205689 |
| `…/phy_vnn/fuse_pull_gasket/puller_done` **vs** `…/fuse_puller/i_fp_ip_fsm/puller_done` | PGA gasket vs FSM | `TODO` | gasket=`0x1`, FSM=`0x0` | **CDC mismatch** — synced gasket says done, source FSM says not done | 16029205689 |
| `…/phy_vnn/fuse_pull_gasket/ip_ready_ff` | PGA gasket | `TODO` | `0x0` | controller-path IP-ready flop never latched | 16029205689 |
| `…/fuse_pull_gasket/fp_gst_fpvar20.ctech_doublesync…iprdy/…/sync{0,1}` **vs** `…/ip_ready_ff` | PGA gasket sync | `TODO` | sync{0}=sync{1}=`0x1`, ip_ready_ff=`0x0` | **CDC mismatch** — ip_ready synced through as 1 but flop reads 0 | 16029205689 |
| `…/phy_vnn/fuse_pull_gasket/fuse_pull_prgs` | PGA gasket | `TODO` | `0x0` | no pull in progress at snapshot | 16029205689 |
| `…/mtl_mpphy_x4_pga/pia_top/pia_pwrclk_ctrl/pia_pwrctrl/pia_aic_ip_ready` | PGA AIC | `TODO` | `0x1` | PGA/PHY side **IS** ready (the "PHY ready" half of the split) | 16029205689 |
| `…/phy_vnn/cri_ctrl_cfg2/cpc_fuse_glue_if_gen.cpc_cri_fuse_bulk_glue/o_fuse_err_h` / `o_fusevalid_h` | fuse glue | `TODO` | err=`0x0`, valid=`0x1` | no fuse error, fuse valid — data path fine, pull just not completed | 16029205689 |
| `dfx_parpmc/…/pmcieppgdrv1/pmc_ip_pg_ack_b.UFSX2_PGD0` / `.UFSPW1_PGD0` | PMC power-gate ack | `TODO` | both `0x1` | UFS controller + PHY both powered/ungated (rules out power-gating) | 16029205689 |

> **Honest interpretation notes:**
> - **Controller-vs-PHY IP-ready split is visible natively in the scan:** PGA `pia_aic_ip_ready=0x1` (ready)
>   vs gasket `ip_ready_ff=0x0` (controller path not ready) — mirrors register-dump `ufsx2_ip_ready_sts=0` /
>   `ufspw1_ip_ready_sts=1`.
> - **Both `i_fp_ip_fsm/state` read `0x0`.** The sighting prose "bridge FSM **stuck in Fuse Pull Request**" is
>   a **higher-level decode**, not directly equal to this signal — `state=0x0` decodes to *Idle*. Reconcile the
>   exact FSM/enum with the RTL owner before treating "stuck request" as a raw-signal fact. `[gap: FSM enum]`
> - **The CDC-metastability fingerprint is the cross-domain flop disagreement** (gasket `puller_done=1` vs FSM
>   `puller_done=0`; double-sync=1 vs `ip_ready_ff=0`). Source-vs-synced direction needs RTL confirmation, but
>   disagreeing CDC flops are exactly the expected symptom of the PGCB/CDC async-reset race.

## 6. BKM (best-known methods)
- **Stage-align the comparison.** A scan dump is a *snapshot*; its values are meaningless unless the **boot/PM
  stage at capture is the same** for golden and failing. A passing "at OS-idle" dump vs a failing "at `PC:0005`
  hang" dump differ for thousands of signals for legitimate reasons. Compare at the **same stage**, or restrict
  cross-stage comparison to **invariants** (e.g. "no FSM stuck mid-handshake", "`ip_ready` must be 1 once past
  fuse-pull").
- **One passing log is a sample, not a spec.** Tag each golden value **stable** (must always hold) vs
  **variable** (board/BKC/config-specific). Prefer invariants in signatures.
- **Config matters.** UFS-enabled (3★) vs NVMe/UFS-disabled (4★/5★) have different "normal" — record the config
  with every golden capture.
- **Watchlist, not raw diff.** ~17k signals/partition — curate the decisive set per IP; don't diff everything.
- **Scan gives numbers, not names.** FSM-state values are raw encodings; get the enum→name map from RTL/IP owner.
- **Provenance per golden capture:** platform, stepping, BKC/IFWI, config, capture-stage, date.
- **Don't commit raw CSVs** — they're large/sensitive; distill into this watchlist. Raw dumps stay local.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| fusepull-cdc-flop-mismatch | both `i_fp_ip_fsm/state=0x0` (Idle) + PGA gasket `puller_done=0x1` vs FSM `puller_done=0x0` + double-sync=`0x1` vs `ip_ready_ff=0x0` + `o_fuse_err_h=0x0`/`o_fusevalid_h=0x1` | boot-time fuse-pull lost to a PGCB/CDC async-reset race (cross-domain flop disagreement, no fuse error) | confirmed | 16029205689 |

## 8. Examples with issue background (feedback loop)
- **16029205689 — PMC stuck Phase-3 waiting UFS IP_ready (fuse-pull CDC race).** *Issue:* WCL warm-reset
  cycling, ~1/1000+ boots hang at `PC:0005`; live SB-trace/VISA masked it. *What the scan dump showed
  (`dfx_parufsphy`, `dfx_parpmc`, verbatim):* both fuse-puller FSMs `i_fp_ip_fsm/state=0x0` (PGA puller and
  bridge puller); PGA gasket `puller_done=0x1` while FSM `puller_done=0x0`; PGA gasket ip_ready double-sync
  `sync{0}=sync{1}=0x1` but `ip_ready_ff=0x0`; `fuse_pull_prgs=0x0`; PGA `pia_aic_ip_ready=0x1` (PHY ready)
  vs gasket `ip_ready_ff=0x0` (controller not ready); fuse glue `o_fuse_err_h=0x0`, `o_fusevalid_h=0x1`; PMC
  `pmc_ip_pg_ack_b.UFSX2_PGD0=0x1` and `.UFSPW1_PGD0=0x1` (both powered). *How it fit the RCA:* powered + no
  fuse error + fuse valid, yet the ip_ready flop never latched despite the synchronizer passing `1`, and the
  gasket/FSM `puller_done` disagree — a textbook **cross-domain flop disagreement** = the PGCB/CDC async-reset
  metastability fingerprint. Scan was **decisive** precisely because it survives the Heisenbug that hides from
  live traces. *Discrepancy to reconcile:* the raw `i_fp_ip_fsm/state=0x0` (Idle) does **not** literally equal
  the debug-owner's "bridge FSM stuck in Fuse Pull Request" prose — that decode needs the RTL FSM enum to
  confirm which FSM/state it refers to.
