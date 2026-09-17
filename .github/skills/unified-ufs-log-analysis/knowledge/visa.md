# Log Module — VISA (monitor-port signal capture)

```yaml
log_type: visa
aka: [VISA capture, monitor-port trace, ODLA]
captures_layers: [fabric, PMC, HCI]
analyzer_mcp: none
mcp_status: gap            # no MCP today — analyzed skill-guided (signal decode below)
schema_ready: no
time_base: visa-sample-clock
provides_anchors: [PkgC exit/entry, ufs_prim_clkreq assert, req_sa assert, int_sts read]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
On-die **monitor-port signal visibility** — PMC/UFS power + ISM/fabric handshake signals sampled over
time. Sees the **fabric ↔ PMC ↔ host-controller** handshake around PkgC/S0ix transitions. The only log
that proves whether UFS is *alive and transacting* during a hang (vs "fell off the bus").

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** set up **first**, before the failing cycle; capture across the PKGC-exit window to catch the
  wake→hang transition.
- **HOW:** `TODO(wiki): VISA monitor-port setup & signal selection for UFS.` Select UFS/PMC monitor
  signals; capture across the repro. **BKM caveat below** re: clock-gating visibility.
- **WHY:** shows the *exact* upstream wake request and the hung downstream read, with a measurable gap —
  the decisive fabric-timing evidence.

## 3. Analyzer — GAP (skill-guided decode)
No MCP. Read manually. Key signals: `ufs_prim_clkreq`, `req_sa`, `ufspw1_pmc_pgd0_pg_req_b`,
`ufsx2_pmc_pgd0_pg_req_b`, `pmcm_cstate_ea`, `PMCMCPPMFA_ps` (0x0→0x4→0x0),
`prim_ism_agent_in/fabric_in/fabric_out`, `int_sts`. Cross-reference `reference/ufs-glossary.md`
(sighting skill) for `IS_`/fabric meaning. **Building a VISA analyzer MCP is a known gap.**

## 4. Normalized output → common event schema
- `ts` ← VISA sample index/time; `ts_base: visa-sample-clock`; `layer: fabric|PMC`.
- Emit an event per meaningful edge: `{type: "clkreq-assert"|"req_sa"|"pkgc-exit"|"int_sts-read-hang", ...}`.
- **Anchors it provides:** `PkgC exit`, `ufs_prim_clkreq` assert, `IS_/int_sts` access — align these with
  BIOS-log PkgC entry and register-dump `SBFES` set.

## 5. Healthy vs failing reference
- **Healthy:** upstream request → downstream `int_sts` read **completes**; PkgC exits cleanly.
- **Fault:** UFS **still active/accepting requests** during failure; **upstream cycle asserts
  `ufs_prim_clkreq` + `req_sa=1` to force PkgC exit**, then **downstream `int_sts` read hangs**;
  measured gap **~804.432 µs**.

## 6. BKM (best-known methods)
- **Clock-gating blind spot:** when clocks are gated, VISA may not be visible on **ODLA** — may need a
  **VISA rework** to reliably observe. Plan signal routing that survives gating.
- Arm before the cycle; a VISA armed after the hang is useless.
- Capture PMC power + ISM signals together so the wake→hang handoff is on one capture.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| fabric-wake-then-hung-int_sts | `ufs_prim_clkreq`+`req_sa=1` force PkgC exit → `int_sts` read hangs, ~804µs gap | UFS upstream wake mid-PKGC, resources late → OCP fabric timeout | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* WCL, UFS primary, BSOD/hang when PKGC/S0ix
  enabled. *What VISA showed (evidence `Comment_10.png`):* UFS alive and accepting requests; upstream
  `ufs_prim_clkreq`+`req_sa=1` forced a PkgC exit, then the driver's downstream `int_sts` read hung —
  **~804.432 µs** between wake and hang. *How it fit the RCA:* the smoking gun for **OCP fabric timeout
  from missing LTR** — proved the fault is fabric power-state timing, not the UFS data path.

## 9. VISA signal dictionary (accumulating)
> **Every VISA analysis appends here:** signal → block → observed value(s) → meaning → the condition it
> flags. This is the growing reference of *which VISA signals we watch and what their values mean*. Add
> rows each time a new capture is analyzed; cite the sighting. Values are the raw waveform states as seen.

**Timebase note:** captures are on the VISA sample clock; the axis is wall-ms (e.g. 19393–19396 ms in
`Comment_10.png`) and the two cursors delimit the decisive interval (there: **804.432 µs**).

### PMC power-management block — `socket0/pcd/…/pmc_pwell1/pmcmunit_wrapper1`
| Signal | Value(s) seen | Meaning | Condition / how to read | Sighting |
|--------|---------------|---------|-------------------------|----------|
| `pmcm_cstate_ea` | `1` (pulses high) | PMC C-state enable/active | high = package in/entering a deep C-state window | 16027585017 |
| `PMCMCPPMFA_ps` | `0x0`→**`0x4`**→`0x0` | PMC CPPM-FA power-state FSM | `0x0` idle/normal; **`0x4` = PkgC-exit transition** driven by the UFS wake | 16027585017 |
| `pmcm_pmcisus_sci_sts_set` | `1` | SCI status set | context (SCI pending) | 16027585017 |
| `ufspw1_pmc_pgd0_pg_req_b` | `1` | UFS PW1 power-gate request (active-low `_b`) | **`1` = NOT requesting gate → UFS powered/awake** during the hang | 16027585017 |
| `ufsx2_pmc_pgd0_pg_req_b` | `1` | UFS-x2 power-gate request (active-low) | **`1` = UFS not gated** (device alive, matches "still accepting requests") | 16027585017 |
| `tcss_pmc_pgd0_pg_req_b` | `1` | TCSS power-gate request | context: TCSS not gated | 16027585017 |
| `tbtlsx / thc0 / thc1 / u3fpw1 / usbr0 _pmc_pgd0_pg_req_b` | `0` | other-IP power-gate requests | `0` = those IPs gated/idle (baseline context) | 16027585017 |

### UFS PHY / fabric block — `parufsphy/…/scc_pgcb` + `scc_ufs_top`
| Signal | Value(s) seen | Meaning | Condition / how to read | Sighting |
|--------|---------------|---------|-------------------------|----------|
| `prim_ism_agent_in` | `0x0`↔`0x3`, **stuck `0x3`** at hang | UFS primary ISM (idle-state-machine) agent input | cycling `0x0/0x3` = normal handshake; **stuck `0x3` = downstream read hung** (the failure point) | 16027585017 |
| `prim_ism_fabric_in` | `0x0`↔`0x3` | ISM fabric-in state | tracks the fabric handshake into the agent | 16027585017 |
| `prim_ism_fabric_out` | `0x0`↔`0x3` | ISM fabric-out state | tracks the fabric handshake out of the agent | 16027585017 |
| `scc_ufs_top/SCS_UFS_CONTROLLERS[0]` | `0x0`↔`0x3` | UFS controller ISM/state | mirrors controller idle/active transitions | 16027585017 |
| `Monitor[17]`, `Monitor[18]` | `0` / pulse | monitor-port taps | pulses mark UFS activity on the monitor port | 16027585017 |

### Derived / annotated signals (interpretation on the capture)
| Signal | Value(s) seen | Meaning | Condition / how to read | Sighting |
|--------|---------------|---------|-------------------------|----------|
| `ufs_prim_clkreq` | asserted | UFS primary clock request | **assert = UFS upstream cycle waking PkgC** | 16027585017 |
| `req_sa` | `1` | service / PkgC-exit request | **`1` = force PkgC exit** (paired with clkreq assertion) | 16027585017 |
| `int_sts` (driver read) | hung | driver's Interrupt Status read on the fabric | **read never completes = downstream stuck** (804.432 µs after the wake) | 16027585017 |
