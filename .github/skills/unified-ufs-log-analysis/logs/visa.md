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
