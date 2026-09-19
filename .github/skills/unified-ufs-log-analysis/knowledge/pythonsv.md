# PythonSV Register & Command Database — UFS System-Level Debug

> **What this is:** a growing database of every **PythonSV command / register** we've used to debug a
> UFS system-level issue — what it accesses, **WHEN** to read it, and **what its value means** (healthy
> vs fault), sourced from real sightings. This is a **reference asset**, not a per-log-type module — it
> is not in `index.jsonl`; other modules (`register-dump.md`, `visa.md`, sighting records) link into it.
> **Append-only:** every new sighting/analysis that uses a PythonSV command adds/updates a row here —
> never delete a historical entry, only add confidence/sighting refs.
>
> Legend: **Confidence** = `confirmed` (seen working in a real debug) / `platform-confirmed` (validated
> namednode from the PythonSV register index via `CodeWithRegistersTool`, on a specific platform — the
> UFSHCI/UniPro IP block is shared across client platforms, so these are the best-available reference
> until live-verified on the sighting's own platform) / `inferred` (reasoned, not directly observed) /
> `spec` (from register spec / MindShare, not yet PythonSV-confirmed) / `gap` (searched for and **not
> found** in the register index — an honest unknown, not a guess).

---

## 1. Host-controller Interrupt / Error registers (`IS_`, `IE`, UniPro error counters)

| Register / field | PythonSV namednode | When to read | Value meaning | Notes | Sighting(s) | Confidence |
|---|---|---|---|---|---|---|
| **`IS_` bit 17 — `SBFES`** (System Bus Fatal Error Status) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.is_.sbfes` (full reg: `...is_`) | At the hang, **before any reset** (recovery clears it) | `1` = **unrecoverable system-bus/OCP-fabric error**; DWC_ufshc core stops, `UTRRSR`/`UTMRRSR` cleared to 0 | Companion enable bit `SBFEE` in `IE` (offset `24h`). Validated on **PTL A0**; UFSHCI IP shared with WCL — live-verify path on WCL | 16027585017 | platform-confirmed (PTL) |
| **`IS_` bit 16 — `HCFES`** (Host Controller Fatal Error Status; sightings write "HBFES") | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.is_.hcfes` | At the hang, before reset | `1` = **host-controller fatal, unrecoverable**; must reset DWC_ufshc core | Full bit-level decode → `reference/ufs-glossary.md` (sighting skill). Validated on PTL A0 | 16027585017 | platform-confirmed (PTL) |
| **`UECPA`** (PHY Adapter Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecpa` — read `.err`, decode `.ec` if set | At/after a UniPro-layer error or CATERROR | `err=1` ⇒ PHY Adapter error; `ec` bits = which lane (0-3) or generic line-reset | Often reads 0/unreadable under CATERROR — absence isn't "clean" | 16027585017 | platform-confirmed (PTL) |
| **`UECDL`** (Data Link Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecdl` — `.err` / `.ec` | Same as above | `ec` bits: NAC received, replay/AFC/FC timer expiry, CRC error, RX overflow, wrong seq #, frame-syntax errors | | 16027585017 | platform-confirmed (PTL) |
| **`UECN`** (Network Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uecn` — `.err` / `.ec` | Same as above | `ec` bits: unsupported header type, bad DeviceID encoding, LHDR trap packet dropping | | 16027585017 | platform-confirmed (PTL) |
| **`UECT`** (Transport Layer UniPro error) | `sv.sockets.soc.ufs.scc_ufs_top.scs_dwc_ufshc_c0_mmio.uect` — `.err` / `.ec` | Same as above | `ec` bits: unsupported header type, unknown CPortID, no connection RX, bad TC, E2E credit overflow | | 16027585017 | platform-confirmed (PTL) |
| **`ufs_ip_ready_status`** (PMC-visible UFS controller ready bit) | **GAP — no confirmed namednode found.** Searched PTL register index; only unrelated `ip_ready_sts` fields on other IPs and a reserved `ufs_idle_indication.reserved_31_1` came back — **not** valid evidence for this bit. Do **not** substitute those | Whenever PMC is suspected stuck waiting on an IP at boot | PMC polls this at **Phase-3 bootflow**; never asserting = controller-side init (fuse-pull) never completed | Distinguish from **PHY** IP_ready, which can assert independently. Ask silicon/PMC-FW owner for the real path | 16029205689 | gap |

## 2. PMC power-gating status registers

| Register | PythonSV access | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|---|
| **`ufsx2_pwr_sts`** | `socket0.soc.pmc.pmu.ip_pwr_sts_1.ufsx2_pwr_sts` | At the hang, to check UFS power-gate state | `0x1` = **not power-gated** (controller/clock still up) | 16027585017 | confirmed |
| **`ufspw1_pwr_sts`** | `socket0.soc.pmc.pmu.ip_pwr_sts_0.ufspw1_pwr_sts` | Same as above | `0x1` = not power-gated | 16027585017 | confirmed |

## 3. Package C-state (PKGC) commands

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`pm_tools.cstate.get_pkgc_entry_counters()`** | At/around a suspected power-state hang; read **twice, consecutively** | Returns per-state entry counts (C6_1, C6_2, C10_1, C10_2, C10_3). **Identical values across two reads = system frozen** (not just shallow); e.g. C10_1 reached, C10_2/C10_3=0 → stuck at PKGC10.1 | 16027585017 | confirmed |
| **`pm_tools.cstate.get_pkgc_current_state()`** | At a suspected boot/PM hang | Returns current package C-state FSM name, e.g. `PKGC_IDLE_ON_C0`. In the fuse-pull-CDC hang this stayed `PKGC_IDLE_ON_C0` (never deep-sleeping — consistent with an **early-boot** stall, not a runtime power-state stall) | 16029205689 | confirmed |

## 4. PMC ARC / bootflow program counter

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`soc.pmc.arc.pc_histo()`** | PMC suspected stuck in a boot phase (Phase-3 etc.) | Returns a histogram of the PMC ARC program counter over a sample window. A **single PC value dominating** (e.g. 65% at `0xb0548`) = **PMC looping/stuck** at that instruction (here, mapped to `PC:0005` = Phase-3 bootflow waiting `ufs_ip_ready_status`) | 16029205689 | confirmed |

## 5. UCIe / PGCB fuse-pull & IOSF2OCP bridge FSM (boot-time UFS init)

| Command / register | PythonSV namednode | When to read | Value meaning | Notes | Sighting(s) | Confidence |
|---|---|---|---|---|---|---|
| **`udr.ucie_pma_checkers()`** | (call returns a table; no single namednode) | At a suspected fuse-pull / PGCB-CDC hang, before reset | Table of UCIe RDI/FDI checker bits per domain (CFI PCD / Display PCD): `Fuse Valid`, `UCIe FW Survivability DONE`, `Gated domain VCCIO PWR Good`, `infra_clk_ack_status`, `lclk_ack_status`, `ucie_sb_link_clk_ack_status`, **`SB PMA FSM STATE`**, `sb_remote_wake_in_status`, `sb_rm_qreqn_status`, `sb_rm_qch_state`, `sb_upma_q*_status`, `sb_ls_qch_state`, `mb_remote_wake_in_status`, `mb_rm_p*`. In the bug: **`SB PMA FSM STATE = SB_FSM_FUSE_PUSH_DONE`**, Q-channel states `Q_STOPPED` | consistent with the sideband stuck mid-handshake | 16029205689 | confirmed |
| **Fuse-pull FSM** (fuse-puller state) | **GAP** — no confirmed namednode for `fuse_pull_ready`/`fuse_pull_done`. Closest proxy: `UFS_FUSE_REG1` (below), which shows fuse data visibility, not the FSM state itself | At the hang | States: `fuse_pull_ready (001)` → `fuse_pull_done (006)`. **Stuck at `001`** = fuse pull requested but never completed | Ask silicon owner for the internal RTL FSM-state node | 16029205689 | gap |
| **IOSF2OCP bridge FSM** | **GAP** — no confirmed FSM-state namednode. Closest proxy: `sv.sockets.soc.ufs.scc_ufs_top.scs_iosf2ocp_sb_pvt.iosfsts` — `.dniosfur` (IOSF error resp.), `.dnocperr` (OCP error fwd.), `.prim_rd_pend` (outstanding upstream reads, Channel 0) | At the hang | Normal = idle/progressing. **Stuck "Fuse Pull Request"** while fuse-puller shows **Idle** = the bridge's fuse request never reached the puller (CDC-race fingerprint). Non-zero, non-draining `prim_rd_pend` = bridge holding outstanding reads | `iosfsts` is a status read, not the FSM state itself — corroborating evidence only | 16029205689 | platform-confirmed (PTL, proxy only) |
| **`UFS_FUSE_REG1`** | `sv.sockets.soc.ufs.scc_ufs_top.scs_iosf2ocp_sb_pvt.fuse1.fuse1_reg` (raw 32-bit; IOSF-sideband gated on `FUSE_REG_READ_MATCH_SAI == FUSE_REG_WRITE_MATCH_SAI`); decoded UFS-PCI-device-number bits → `sv.sockets.soc.fuses.ufs.ufsdevid_0` (3 bits, reset `2`) | Post-mortem / WA verification | Holds the value used to derive the UFS Device ID. Workaround writes **`0x3800`** to the raw `fuse1_reg` so PMC can match the PCIe endpoint device-ID without a real fuse pull | The 3-bit decoded `ufsdevid_0` field ≠ `0x3800` directly — the WA writes the **raw register**; cross-check both when verifying | 16029205689 | platform-confirmed (PTL) |
| **Fuse Controller history** (last 15 fuse requests) | `TODO(pythonsv)` — not resolved via register-index search | At the hang, before reset | Log of last 15 fuse-pull requests + which were served. In the bug: `ufs_pga` request served, **IOSF2OCP-bridge request never received** — pinpoints the lost requester | Ask silicon/fuse-controller owner for the exact namednode | 16029205689 | gap |
| **Fuse-puller debug override** (`sr_fuse_debug`) — ⚠ write-capable, not a passive read | `sv.sockets.soc.tcss.tcss_tscc_save_restores.save_restore_regs.sr_fuse_debug` — `.ip_ready` (force IP ready), `.no_wait` (skip waiting for puller done), `.puller_done` (force done), `.puller_error` (force error), `.repull` (force repull) | Only for controlled debug (forcing/bypassing), never as a "read" of fuse-pull state | Writing `puller_done=1`/`ip_ready=1`/`no_wait=1` forces the condition — how you'd manually unstick a hung fuse-pull for experimentation | ⚠ Confirm with the register owner before writing — same convention as any PythonSV write | 16029205689 | platform-confirmed (PTL) |

## 6. MCA (cross-reference only — do not duplicate analysis here)

| Command | When to read | Value meaning | Sighting(s) | Confidence |
|---|---|---|---|---|
| **`debug.mca.analyze()`** | Immediately after MCA/CATERROR/three-strike, **before power-cycle** | Identifies failing bank/core (e.g. THREE_STRIKE on CORE2 MLC). **May return empty even in a genuine failing capture** — absence does not rule out the fault class | 16027585017 | confirmed |
> **Deep MCA decode is routed to the PythonSV GPT Agent** (per skill convention) — this row is kept here
> only so the command itself is indexed in the same database; do not re-build MCA analysis logic here.

---

## How to add a new entry
1. Find the exact PythonSV command/register path used in the debug (quote it verbatim).
2. Fill: **When to read** (the trigger/stage), **Value meaning** (healthy vs fault, with the actual
   observed value), **Sighting(s)**, **Confidence**.
3. If the register already has a full bit-level spec decode, link it (`reference/ufs-glossary.md`) rather
   than repeating the offsets/access-type table here — this file is the **debug-usage** angle, not the
   spec-reference angle.
