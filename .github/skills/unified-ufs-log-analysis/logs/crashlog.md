# Log Module — Crashlog (platform crash/error log)

```yaml
log_type: crashlog
aka: [platform crashlog, PMC crashlog]
captures_layers: [PMC, fabric]
analyzer_mcp: <crashlog decoder>
mcp_status: todo
schema_ready: no
time_base: <TODO>
provides_anchors: [error-record time]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
Platform crash/error log — captured error records at/after the failure (listed in this sighting's HSD
`debug_tools`). `TODO(owner): confirm exact scope/source.`

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** at/after the failure.
- **HOW:** `TODO(wiki): crashlog collection procedure & tooling.`
- **WHY:** `TODO: what error records it yields.`

## 3. Analyzer — MCP (todo)
`TODO(wiki): crashlog decode reference + MCP.`

## 4. Normalized output → common event schema
- `ts` ← `TODO`; `layer: PMC|fabric`. Events: `TODO`. **Anchors:** error-record time.

## 5. Healthy vs failing reference
- `TODO: expected clean vs error signature.`

## 6. BKM (best-known methods)
- `TODO(owner): crashlog BKMs.`

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet.)_
