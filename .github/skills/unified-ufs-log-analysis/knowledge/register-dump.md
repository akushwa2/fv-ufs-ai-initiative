# Log Module — Register Dump (UFS host-controller & PMC PythonSV register/command database)

```yaml
log_type: register-dump
aka: [ITP register read, PythonSV register dump, HCI/UniPro/M-PHY/Device regs]
captures_layers: [HCI, UniPro, M-PHY, PMC, fuse-PGCB]
analyzer_mcp: none
mcp_status: gap            # no MCP today — skill-guided decode (glossary + register spec)
schema_ready: no
time_base: n/a             # point-in-time snapshot, not a timeline; anchors other logs at the hang instant
provides_anchors: [IS_ SBFES set, IS_ HCFES set, PMC ufs pwr_sts, PKGC entry counters, ufsx2_ip_ready_sts=0, fuse-puller FSM Idle]
signature_count: 3
```

> **What this file is (merged):** it is BOTH (a) the **register-dump log module** — how to capture the
> point-in-time register snapshot at the hang and what it anchors — AND (b) the cross-cutting
> **PythonSV register/command database**: every register/command we've used to debug a UFS
> system-level issue, what it accesses, **WHEN** to read it, and **what its value means** (healthy vs
> fault), sourced from real sightings. §3 is the command catalog; §4–§8 are the module's timeline
> anchors, signatures, and worked examples. **Append-only:** every new sighting/analysis that uses a
> register/command adds/updates a row in §3 — never delete a historical entry, only add
> confidence/sighting refs. Other modules (`visa.md`, sighting records) link into §3 instead of
> duplicating register detail.
>
> **Confidence legend:** `confirmed` (seen working in a real debug) / `platform-confirmed` (validated
> namednode from the PythonSV register index via `CodeWithRegistersTool`, on a specific platform — the
> UFSHCI/UniPro IP block is shared across client platforms, so these are the best-available reference
> until live-verified on the sighting's own platform) / `inferred` (reasoned, not directly observed) /
> `spec` (from register spec / MindShare, not yet PythonSV-confirmed) / `gap` (searched for and **not
> found** in the register index — an honest unknown, not a guess).

---

## 1. Identity — what it captures & which UFS layers it sees
A **point-in-time snapshot** of decisive UFSHCI + PMC + fuse/PGCB registers at the failure instant. Not
a timeline — its value is the **state at the hang**, which anchors the other (time-series) logs.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** **at the hang, before ANY reset/recovery** (recovery clobbers these). Halt cores first if a
  watchdog reset is imminent.
- **HOW:** ITP/PythonSV register reads — the exact command per register is in the **§3 catalog** below.
  `TODO(wiki): generic ITP/PythonSV register-read setup for UFS host controller & PMC.`
- **WHY:** the fatal `IS_` bits (fabric-timeout class) and the fuse-pull/IP-ready state (fuse-pull-CDC
  class) are the definitive confirmations of *which* UFS system-level bug you're on.

---

## 3. Command / register catalog — which command → checks what → WHEN → value
The heart of this file. Organized by subsystem. Each row: exact PythonSV command/namednode → when to
read → value meaning (healthy vs fault, with the real observed value) → sighting → confidence.

### 3.1 Host-controller interrupt / error registers (`IS_`, `IE`, UniPro error counters)

| Register / field | PythonSV namednode | When to read | Value meaning | Notes | Sighting(s) | Confidence |
|---|---|---|---|---|---|---|
| **`IS_` bit 17 — `SBFES`** (System Bus Fatal Error Status) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.is_.sbfes` (full reg: `...is_`) | At the hang, **before any reset** (recovery clears it) | `1` = **unrecoverable system-bus/OCP-fabric error**; DWC_ufshc core stops, `UTRRSR`/`UTMRRSR` cleared to 0 | Companion enable bit `SBFEE` in `IE` (offset `24h`). Validated on **PTL A0**; UFSHCI IP shared with WCL — live-verify path on WCL | 16027585017 | platform-confirmed (PTL) |
| **`IS_` bit 16 — `HCFES`** (Host Controller Fatal Error Status; sightings write "HBFES") | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.is_.hcfes` | At the hang, before reset | `1` = **host-controller fatal, unrecoverable**; must reset DWC_ufshc core | Full bit-level decode → `reference/ufs-glossary.md` (sighting skill). Validated on PTL A0 | 16027585017 | platform-confirmed (PTL) |
| **`UECPA`** (PHY Adapter Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecpa` — read `.err`, decode `.ec` if set | At/after a UniPro-layer error or CATERROR | `err=1` ⇒ PHY Adapter error; `ec` bits = which lane (0-3) or generic line-reset | Often reads 0/unreadable under CATERROR — absence isn't "clean" | 16027585017 | platform-confirmed (PTL) |
| **`UECDL`** (Data Link Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecdl` — `.err` / `.ec` | Same as above | `ec` bits: NAC received, replay/AFC/FC timer expiry, CRC error, RX overflow, wrong seq #, frame-syntax errors | | 16027585017 | platform-confirmed (PTL) |
| **`UECN`** (Network Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecn` — `.err` / `.ec` | Same as above | `ec` bits: unsupported header type, bad DeviceID encoding, LHDR trap packet dropping | | 16027585017 | platform-confirmed (PTL) |
| **`UECT`** (Transport Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uect` — `.err` / `.ec` | Same as above | `ec` bits: unsupported header type, unknown CPortID, no connection RX, bad TC, E2E credit overflow | | 16027585017 | platform-confirmed (PTL) |

### 3.2 PMC power-gating status registers

| Register | PythonSV access | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|---|
| **`ufsx2_pwr_sts`** | `socket0.soc.pmc.pmu.ip_pwr_sts_1.ufsx2_pwr_sts` (bit 28) — full register: `soc.pmc.pmu.ip_pwr_sts_1.show()` | At the hang, to check UFS power-gate state | `0x1` = **not power-gated** (controller/clock still up). `.show()` decodes every IP in the register (e.g. `cnvi_pwr_sts`, `lpc_pwr_sts`, `gbe_pwr_sts`, ...) in one call | 16027585017, 16029205689 | confirmed (WCL, cross-validated across 2 sightings) |
| **`ufspw1_pwr_sts`** | `socket0.soc.pmc.pmu.ip_pwr_sts_0.ufspw1_pwr_sts` (bit 07) | Same as above | `0x1` = not power-gated | 16027585017 | confirmed (WCL) |

### 3.3 PMC IP-ready status (`ufs_ip_ready_status`)

| Register / field | PythonSV namednode | When to read | Value meaning | Notes | Sighting(s) | Confidence |
|---|---|---|---|---|---|---|
| **`ufs_ip_ready_status`** (PMC-visible UFS **controller** ready bit) | `soc.pmc.pmu.ip_ready_sts_1.ufsx2_ip_ready_sts` (bit 28, `rw/1c/v`). Full register: `soc.pmc.pmu.ip_ready_sts_1.show()` | Whenever PMC is suspected stuck waiting on an IP at boot | "IP has completed its fuse/softstrap pull and is ready for IP's `prim_rst_b` deassertion." In the hang: **`ufsx2_ip_ready_sts = 0`** (controller never ready) while the companion **`ufspw1_ip_ready_sts` (bit 07) = 1** (UFS **PHY** side ready) — the exact controller-vs-PHY split described in the sighting | The **core fault bit** for the fuse-pull-CDC class | 16029205689 | confirmed (WCL) |

### 3.4 Package C-state (PKGC) commands

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`pm_tools.cstate.get_pkgc_entry_counters()`** | At/around a suspected power-state hang; read **twice, consecutively** | Returns per-state entry counts (C6_1, C6_2, C10_1, C10_2, C10_3). **Identical values across two reads = system frozen** (not just shallow); e.g. C10_1 reached, C10_2/C10_3=0 → stuck at PKGC10.1 | 16027585017 | confirmed |
| **`pm_tools.cstate.get_pkgc_current_state()`** | At a suspected boot/PM hang | Returns current package C-state FSM name, e.g. `PKGC_IDLE_ON_C0`. In the fuse-pull-CDC hang this stayed `PKGC_IDLE_ON_C0` (never deep-sleeping — consistent with an **early-boot** stall, not a runtime power-state stall) | 16029205689 | confirmed |

### 3.5 PMC ARC / bootflow program counter & flow trace

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`soc.pmc.arc.pc_histo()`** | PMC suspected stuck in a boot phase (Phase-3 etc.) | Returns a histogram of the PMC ARC program counter over a sample window. A **single PC value dominating** (e.g. 65% at `0xb0548`) = **PMC looping/stuck** at that instruction (here, mapped to `PC:0005` = Phase-3 bootflow waiting `ufs_ip_ready_status`) | 16029205689 | confirmed (WCL) |
| **`socpmctrace.print_fw_trace(pmc_xml=r"<path to soc.strings.xml>")`** | At/after a suspected PMC boot-flow stall — **decisive**, shows the exact flow step where PMC is stuck | Prints the full PMC firmware flow trace (timestamped): boot-reset flow, `Phase3BootFlow` start, per-IP wake/PG-exit/side-POK/IP-ready sequencing. **Decisive line in this bug:** `HOST IP READY - still waiting for the following IP(s): IpMask(1:10000000)[UFSX2]` — i.e. **every other IP reached IP-ready except UFSX2**, named explicitly by the trace | Needs the platform's `soc.strings.xml` path (varies by build). Single most direct piece of evidence for "PMC is specifically waiting on UFS" | 16029205689 | confirmed (WCL) |

### 3.6 Fuse-pull / PGCB / IOSF2OCP bridge FSM (boot-time UFS init)

| Command / register | PythonSV namednode | When to read | Value meaning | Notes | Sighting(s) | Confidence |
|---|---|---|---|---|---|---|
| **`udr.ucie_pma_checkers()`** | (call returns a table; no single namednode) | At a suspected fuse-pull / PGCB-CDC hang, before reset | **Full table has 41 rows** (CFI PCD / Display PCD columns). Key ones seen in the bug: `Fuse Valid=0x1`, `UCIe FW Survivability DONE=0x0`, `infra_clk_ack_status=0x1`, `lclk_ack_status=0x0`, **`SB PMA FSM STATE=SB_FSM_FUSE_PUSH_DONE`**, Q-channel states `Q_STOPPED`, **`MB PMA FSM STATE=PMA_FSM_RESET`**, **`pgfsm_fsm_state=StateReset`**, plus PGCB timing constants (`PGFSM PWR GD Delay=0x30`, `Ramp Delay=0x78`, `Reset propagation delay=0x40`, `Min L0/L1 Residency=0x8`, `ucie_phy_pll_ratio=0x28`) | Full 41-row list preserved verbatim in sighting record `16029205689` §6b | 16029205689 | confirmed (WCL) |
| **`doctor.cgpg.parufsphy_pcg_clk_req_status()`** | At the hang, to check UFS PHY partition clock-request health | Table of PARUFSPHY partition clock requests: `ufs_scc_cci_ocp_clkreq`, `ufs_btrs_cci_sclk_clkreq`, `ufs_pgcb_clkreq`, `ufs_btrs_cci_ip_clkreq`, `ufs_scc_cci_xsoc_clkreq`, `ufs_pia_soc_aux_clk_req`, `ufs_scc_cci_prim_clkreq`, `ufs_scc_cci_sb_clkreq` (all **Active**) vs **`ufs_iosf_sb_power_req_ack_side_clkreq` = De-Asserted** | The **one de-asserted clock request** among an otherwise-all-Active table is the anomaly to chase — it's the sideband power-request-ack clock, directly relevant to the PGCB/CDC sideband handshake | 16029205689 | confirmed (WCL) |
| **`soc.ufs.scc_ufs_top.scs_iosf2ocp_sb_pvt.fuse_strap_cpl_status.show()`** | At the hang, to check for reported fuse/strap-pull errors | Fields: `fuse_err_code`, `strap_pull_err`, `fuse_g3_pull_err`, `fuse_g2_pull_err`, `fuse_g1_pull_err`, `fuse_g0_pull_err` | In the bug, **all error bits read 0 — "No Errors on fuse_pull"** despite the pull being stuck. Important negative finding: don't expect this register alone to catch the hang — it only rules out an *explicit* fuse error | 16029205689 | confirmed (WCL) |
| **`UFS_FUSE_REG1`** | `soc.ufs.scc_ufs_top.scs_iosf2ocp_sb_pvt.fuse1.fuse1_reg` (raw 32-bit; `.show()`; IOSF-sideband gated on `FUSE_REG_READ_MATCH_SAI == FUSE_REG_WRITE_MATCH_SAI`). Companions: `.fuse2.fuse2_reg`, `.fuse3.fuse3_reg`. Decoded UFS-PCI-device-number bits → `sv.sockets.soc.fuses.ufs.ufsdevid_0` (3 bits, reset `2`) | Post-mortem / WA verification | Holds the value used to derive the UFS Device ID. **Live WCL value seen pre-WA: `0x001c1000`** (only `fuse1` held a value; `fuse2/3 = 0`). The **interim Solution-1 WA** wrote **`0x3800`** to the raw `fuse1_reg` so PMC could match the PCIe endpoint device-ID without a real fuse pull — **now superseded**: the shipping **Solution-2** WA (~20 µs PGCB guard band) does **not** touch this register | The 3-bit decoded `ufsdevid_0` field ≠ `0x3800` directly — Solution-1 wrote the **raw register**; only relevant when analyzing pre-Solution-2 captures | 16029205689 | confirmed (WCL) |
| **Fuse-pull FSM** (fuse-puller state, prose `fuse_pull_ready(001)`/`fuse_pull_done(006)`) | **Gap as a *named* PythonSV enum/namednode.** The sighting's own PythonSV session does **not** show a register read returning literal `001`/`006` — that phrasing is the debug-owner's description of the flow, backed instead by `fuse_strap_cpl_status` (no error) + the fact `ufsx2_ip_ready_sts` never sets. Treat `001`/`006` as **conceptual state names**, not a confirmed field to query | At the hang | `001` = pull requested, `006` = pull done, conceptually | If you need the literal FSM encoding, ask the RTL/silicon owner — it may only exist as an internal (non-PythonSV-modeled) state | 16029205689 | gap (as a literal query) |
| **IOSF2OCP bridge FSM** (prose "stuck in Fuse Pull Request") | **Gap as a named FSM-state namednode** — this description comes from **scandump** interpretation, not a PythonSV register read in the retrieved comments. Closest **register** proxy: `scs_iosf2ocp_sb_pvt.iosfsts` — `.dniosfur`, `.dnocperr`, `.prim_rd_pend` | At the hang | Bridge fuse-request state; "stuck" = bridge's request never reached the fuse puller (CDC-race fingerprint) | `iosfsts` corroborates bridge health but is not the FSM-state enum itself; the true source may be scandump-only | 16029205689 | gap (scandump-derived, not PythonSV-confirmed) |
| **Fuse Controller history** (last 15 fuse requests) | **DMR-confirmed namednode** — `sv.sockets.cbbs.base.fuses.fuse_controller.intel_fuse_ss_pull_details_0_0` (word .0; companions `intel_fuse_ss_pull_details_1_*` / `_2_*`; slots N-0..N-15), `intel_fuse_pull_summary`, `intel_soft_strap_pull_summary`. Alt alias hierarchy: `sv.sockets.cbbs.base.fuse_base0_top_reg.fusectl_reg.*`. BAR4, IOSF-SB CRRd/CRWr `0x06/0x07`; offsets `0x3010–0x3108` (details), `0x3000` (fuse summary), `0x3004` (soft-strap summary). Fields per slot: `valid`, `sb_portid`, `ep_number`, `group_num`, `rsp_type`, `cmp_type` | At the hang, before reset | Log of last 15 fuse-pull requests + which were served. In the bug: `ufs_pga` request served, **IOSF2OCP-bridge request never received** — pinpoints the lost requester. Decode `sb_portid`/`ep_number` to identify the requester (UFS controller vs UFS PGA). ⚠ **`summary_reset` (bit 31 of `intel_fuse_pull_summary`) is destructive** — clears all detail+summary history; read-only usage | Namednode resolved via `CodeWithRegistersTool` on **DMR** (`cbbs.base` = DMR CBB base-die node); **WCL path unconfirmed** — likely a different root (e.g. `sv.sockets.soc.fuse...`), live-verify on WCL. WCL **SB_PORTID→IP map** not yet established | 16029205689 | platform-confirmed (DMR) · WCL = gap |
| **Fuse-puller debug override** (`sr_fuse_debug`) — ⚠ write-capable, not a passive read | `sv.sockets.soc.tcss.tcss_tscc_save_restores.save_restore_regs.sr_fuse_debug` — `.ip_ready` (force IP ready), `.no_wait` (skip waiting for puller done), `.puller_done` (force done), `.puller_error` (force error), `.repull` (force repull) | Only for controlled debug (forcing/bypassing), never as a "read" of fuse-pull state | Writing `puller_done=1`/`ip_ready=1`/`no_wait=1` forces the condition — how you'd manually unstick a hung fuse-pull for experimentation | ⚠ Confirm with the register owner before writing | 16029205689 | platform-confirmed (PTL) |

### 3.7 MCA (cross-reference only — do not duplicate analysis here)

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`debug.mca.analyze()`** | Immediately after MCA/CATERROR/three-strike, **before power-cycle** | Identifies failing bank/core (e.g. THREE_STRIKE on CORE2 MLC). **May return empty even in a genuine failing capture** — absence does not rule out the fault class | 16027585017 | confirmed |

> **Deep MCA decode is routed to the PythonSV GPT Agent** (per skill convention) — this row is kept here
> only so the command itself is indexed in the same database; do not re-build MCA analysis logic here.

---

## 4. Normalized output → common event schema
- No native `ts` — stamp with the **hang instant** (from the merge anchor) so it lands on the timeline.
- Emit one event per decisive bit: `{layer: HCI, type: "SBFES-set"|"HCFES-set", severity: fatal, decoded}`;
  for the fuse-pull class: `{layer: PMC, type: "ufsx2_ip_ready=0", severity: fatal, decoded}`.
- **Anchors it provides:** `IS_ SBFES set` / `HCFES set` (align with VISA `int_sts` hang), PMC pwr_sts,
  PKGC counter state, `ufsx2_ip_ready_sts=0`, fuse-puller FSM Idle.

## 5. Healthy vs failing reference
- **Healthy:** `IS_` no fatal bits; UEC* readable/clean; PKGC counters advancing; `ufsx2_ip_ready_sts=1`;
  fuse-pull completes (`ufs_ip_ready` sets).
- **Fault (fabric-timeout class):** **`IS_` SBFES + HCFES set**; UEC* unreadable/0 under CAT error;
  PMC pwr_sts `0x1` (UFS not gated); PKGC counters **frozen** (identical across two reads).
- **Fault (fuse-pull-CDC class):** `ufsx2_ip_ready_sts=0` while `ufspw1_ip_ready_sts=1`; `fuse_strap_cpl_status=0x0`
  (no error) yet pull stuck; `pc_histo` pinned at `0xb0548`; `PKGC_IDLE_ON_C0`; one de-asserted PARUFSPHY clkreq.

## 6. BKM (best-known methods)
- Read **before** any reset — fatal bits + MCA are lost on power-cycle.
- Take **two consecutive reads** of PKGC counters — identical values prove "frozen/stuck" vs "still moving."
- Record `IS_` raw hex, not just bit names, so bit positions can be re-verified against the spec.
- For a suspected fuse-pull hang, capture the §3.5 + §3.6 set together (PC + FW trace + `ucie_pma_checkers`
  + `fuse_strap_cpl_status` + fuse-controller history) — no single register is decisive alone.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| is-sbfes-hcfes-fatal | `IS_` bits 17+16 set | OCP/system-bus fatal → core stopped, needs reset | confirmed | 16027585017 |
| pkgc-counters-frozen | C10_1 reached, C10_2/3=0, identical across 2 reads | system stuck at capture (not merely shallow) | confirmed | 16027585017 |
| fusepull-cdc-ipready-split | `ufsx2_ip_ready_sts=0` + `ufspw1_ip_ready_sts=1`, `fuse_strap_cpl_status=0x0`, `pc_histo` pinned `0xb0548` | boot-time fuse-pull lost to a PGCB/CDC race; PMC stuck Phase-3 | confirmed | 16029205689 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* WCL UFS-primary hang when PKGC enabled.
  *What the register dump showed (evidence `Comment_3.png`):* `IS_` **SBFES + HCFES** set;
  PKGC counters **C10_1=532, C10_2=C10_3=0**, identical across two reads (frozen); `debug.mca.analyze()`
  came back **empty** in one capture. *How it fit the RCA:* the SBFES/HCFES pair is the definitive
  confirmation of the **OCP fabric timeout**; the frozen counters proved the system was stuck at PKGC10.1;
  empty-MCA proved MCA is *not mandatory* for this signature.
- **16029205689 — PMC stuck Phase-3 waiting UFS IP_ready (fuse-pull CDC race).** *Issue:* WCL warm-reset
  cycling, ~1/1000+ boots hang at `PC:0005`. *What the register set showed:* `pc_histo` pinned 65% at
  `0xb0548`; `print_fw_trace` names `[UFSX2]` as the only IP not IP-ready; `ufsx2_ip_ready_sts=0` vs
  `ufspw1_ip_ready_sts=1`; `ufsx2_pwr_sts=1` (not gated); `ucie_pma_checkers` `SB_FSM_FUSE_PUSH_DONE`;
  `fuse_strap_cpl_status=0x0` (no error); `fuse1_reg=0x001c1000` (only fuse1 set); fuse-controller history
  `ufs_pga` served but IOSF2OCP-bridge request never received. *How it fit the RCA:* no fuse *error* + IP-ready
  split + lost bridge request = the fuse-pull never completed → PGCB/CDC async-reset metastability. The
  register set is decisive **as a set** (no single register flags the hang alone).

---

## 9. How to add a new entry
1. Find the exact PythonSV command/register path used in the debug (quote it verbatim).
2. Add a row in the matching §3 subsection with: **When to read** (the trigger/stage), **Value meaning**
   (healthy vs fault, with the actual observed value), **Sighting(s)**, **Confidence**.
3. If the register already has a full bit-level spec decode, link it (`reference/ufs-glossary.md`) rather
   than repeating the offsets/access-type table here — this file is the **debug-usage** angle, not the
   spec-reference angle.
4. If the new capture reveals a repeatable pattern, also add a row to §7 (signatures) and a worked
   example to §8, and bump `signature_count` in the frontmatter + the `index.jsonl` line.
