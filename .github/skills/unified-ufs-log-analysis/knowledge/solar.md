# Log Module — Solar (regression / residency logging)

```yaml
log_type: solar
aka: [Solar app, residency log]
captures_layers: [PMC]
analyzer_mcp: Solar app
mcp_status: todo
schema_ready: no
time_base: wall-clock
provides_anchors: [cycle boundary, S0ix residency window]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
Power **regression + S0ix-residency** logging across cycles — used for **fix validation**, not initial debug.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** during **fix validation** — the full regression (S0ix/S4/S5/WR/CR). Version seen `3.25.204.0`.
- **HOW:** `TODO(wiki): Solar app setup & log capture.`
- **WHY:** proves the fix holds over many cycles and quantifies residency cost.

## 3. Analyzer — MCP (todo)
`TODO(wiki): Solar log/residency interpretation + MCP.`

## 4. Normalized output → common event schema
- `ts` ← wall-clock; `ts_base: wall-clock`; `layer: PMC`. Events: `{type: "cycle-pass"|"residency", decoded}`.
- **Anchors it provides:** cycle boundaries / residency windows (validation-time, not failure-time).

## 5. Healthy vs failing reference
- **Pass:** clean cycles + S0ix residency (~**85–88%** in the fixed case).
- **Fail:** hung/failed cycles or collapsed residency.

## 6. BKM (best-known methods)
- Report residency **with** the pass count — a "pass" at poor residency means the blunt fix (e.g. 650µs
  LTR blocking deep S0ix) rather than the refined one.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(validation metric, not a fault)_ | | | | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017.** *Issue:* validating the LTR workaround. *What Solar showed:* **100 cycles pass**
  (S0ix/S4/S5/WR/CR), S0ix residency ~85–88%. *How it fit the RCA:* evidence the refined
  ignore-LTR-on-D3 mitigation restored deep residency while staying stable.
