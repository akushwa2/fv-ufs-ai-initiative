# Log Module — SoC Watch

```yaml
log_type: socwatch
aka: [SoCWatch, soc watch, PnP power trace, residency log]
captures_layers: [PMC, OS]
analyzer_mcp: <socwatch analyzer>
mcp_status: todo
schema_ready: no
time_base: socwatch-timestamp
provides_anchors: [PkgC residency window, S0ix entry/exit, wakeup event, device D-state]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
Intel **SoC Watch** power/PnP trace — package & core **C-state / P-state / S0ix residency**, **wake
reasons**, and device **D-states** over a run. Answers "how deep did we go, how long, and **what woke
us**." Overlaps Solar (residency) but adds **wakeup-cause** attribution — useful to see whether **UFS**
is the IP blocking deep PkgC/S0ix or the one waking the system.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** during power characterization / when PKGC or S0ix isn't reaching its target, or to attribute wakeups.
- **HOW:** `TODO(wiki): SoC Watch collection command + session config for UFS/PKGC/S0ix.`
- **WHY:** quantifies residency and names the wake source — points at the IP starving deep power.

## 3. Analyzer — MCP (todo)
`TODO(wiki): SoC Watch summary/CSV decoder + MCP; emit residency %, wake counts/causes, D-state timeline.`

## 4. Normalized output → common event schema
- `ts` ← SoC Watch timestamp; `ts_base: socwatch-timestamp`; `layer: PMC|OS`.
- Events: `{type: "pkgc-residency", decoded: "C10=..%"}`, `{type: "s0ix-entry|exit"}`, `{type: "wakeup", decoded: "<source>"}`, `{type: "d-state", decoded: "UFS D3"}`.
- **Anchors it provides:** PkgC/S0ix residency windows, wakeup events, device D-state transitions — align
  with BIOS-log PkgC config, VISA PkgC exit, and ACPI D0/D3.

## 5. Healthy vs failing reference
- **Healthy:** package reaches the target deep state (e.g. PKGC10 / S0i2.x) with expected residency; no
  abnormal wake source.
- **Fault:** residency **stuck shallow** (never reaches deep PKGC/S0ix), or **frequent wakeups attributed
  to UFS**, or UFS not entering D3 — i.e., UFS is the IP blocking/breaking deep power.

## 6. BKM (best-known methods)
- Read residency **with** wake-cause — "low residency" only matters once you know **who** is waking it.
- Cross-check SoC Watch D-state vs ACPI `_PS3` and VISA `pg_req_b` — they should agree on when UFS is gated.
- For the blunt-vs-refined LTR fix, SoC Watch shows the residency cost (deep-S0ix blocked) that Solar summarizes.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet — add when a SoC Watch trace is analyzed against an issue; e.g. to show UFS blocking deep
  PKGC/S0ix or waking the package around the `ufs-fabric-timeout-on-pkgc` window.)_
