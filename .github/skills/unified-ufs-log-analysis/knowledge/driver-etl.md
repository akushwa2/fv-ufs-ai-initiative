# Log Module — Driver ETL (Windows storufs ETW trace)

```yaml
log_type: driver-etl
aka: [ETW trace, storufs ETL, storport trace]
captures_layers: [OS]
analyzer_mcp: <WPA / xperf>
mcp_status: todo
schema_ready: no
time_base: qpc
provides_anchors: [D3 entry, hibernate call, reset start, _PS3]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
Windows **ETW/ETL** trace of the storufs/storport driver — the OS driver's timed view of D-state,
hibernate, and reset activity. Bridges ACPI (what) and BSOD (crash) with **timestamps**.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** across the failing cycle (boot + sleep-wake).
- **HOW:** `TODO(wiki): ETW/xperf capture for storufs (providers + session).`
- **WHY:** gives a **timestamped** OS-side sequence for correlation (SW hibernate → `_PS3` → reset).

## 3. Analyzer — MCP (todo)
`TODO(wiki): WPA/xperf-based ETL decoder MCP; emit driver events with QPC timestamps.`

## 4. Normalized output → common event schema
- `ts` ← QPC; `ts_base: qpc`; `layer: OS`. Events: `{type: "d3-entry"|"sw-hibernate"|"reset-start"}`.
- **Anchors it provides:** SW-hibernate/`_PS3`/reset timing — align with ACPI D0/D3 and BSOD DPC fire.

## 5. Healthy vs failing reference
- **Healthy:** D3/hibernate/reset sequence completes.
- **Fault:** reset started but stalls (dovetails with the BSOD storufs reset >20s). `TODO: concrete lines.`

## 6. BKM (best-known methods)
- The ETL is the best place to see **OS hibernate cadence** (SW-H8 vs AH8) that decides whether the
  failing timing window opens — pair with the hibernate-mode analysis.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet — add when a driver ETL is analyzed against an issue; especially to pin the SW-H8 vs AH8
  cadence discussed in sighting 16027585017.)_
