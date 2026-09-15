# Log Module — PA (Protocol Analyzer, UFS link)

```yaml
log_type: pa-protocol-analyzer
aka: [PA capture, UFS protocol analyzer, M-PHY/UniPro link capture]
captures_layers: [UniPro, M-PHY]
analyzer_mcp: <vendor PA tool>
mcp_status: todo
schema_ready: no
time_base: pa-capture-clock
provides_anchors: [link state change, device transaction]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
The **UFS link** protocol/electrical capture (M-PHY/UniPro) — used to rule signal-integrity in or out.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** only once **signal-integrity is a live hypothesis** — run to *close* SI, not to open debug.
- **HOW:** `TODO(wiki): PA hookup & capture for UFS M-PHY/UniPro link.`
- **WHY:** confirms whether the link/SI is at fault vs the fabric/power path.

## 3. Analyzer — MCP (todo)
`TODO(wiki): PA trace interpretation (link states, errors) + MCP.`

## 4. Normalized output → common event schema
- `ts` ← PA clock; `ts_base: pa-capture-clock`; `layer: UniPro|M-PHY`. Events: link-state / device txn.
- **Anchors it provides:** device transaction timing (weakly) — usually used to exclude, not to align.

## 5. Healthy vs failing reference
- **Healthy / this class:** **no SI suspect** — clean link. A good early door to close.
- **Fault (other classes):** link errors / retrain / SI issues (not this sighting).

## 6. BKM (best-known methods)
- Use PA to **exclude** the link early; if PA is clean, stop chasing SI and move to fabric/power logs.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none — used to exclude SI)_ | | | | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017.** *Issue:* UFS-primary PKGC hang. *What PA showed:* initial analysis = **no SI suspect**.
  *How it fit the RCA:* ruled out link/signal-integrity, redirecting focus to the fabric power-state path.
