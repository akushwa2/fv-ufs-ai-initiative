# Log Module — CSE/ESE Trace

```yaml
log_type: cse-ese
aka: [CSE trace, ESE trace, UFS PHY trace]
captures_layers: [M-PHY]
analyzer_mcp: <mcp?>       # an MCP exists for CSE/ESE analysis — confirm + wire
mcp_status: todo
schema_ready: no
time_base: <TODO>
provides_anchors: [PHY event]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
CSE/ESE firmware trace covering the **UFS PHY** — PHY-level events/telemetry.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** `TODO(owner): when in the flow CSE/ESE PHY trace is decisive.`
- **HOW:** `TODO(wiki): CSE/ESE PHY trace capture procedure.`
- **WHY:** `TODO: what PHY-level detail it yields.`

## 3. Analyzer — MCP (todo)
`TODO(wiki): CSE/ESE analysis MCP name/location + usage.` (An MCP is understood to exist — wire it here.)

## 4. Normalized output → common event schema
- `ts` ← `TODO`; `layer: M-PHY`. Events: `TODO`. **Anchors:** `TODO`.

## 5. Healthy vs failing reference
- `TODO: PHY healthy baseline vs failing signature.`

## 6. BKM (best-known methods)
- `TODO(owner): CSE/ESE PHY capture BKMs.`

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet — add when a CSE/ESE PHY trace is analyzed against an issue.)_
