# Log Module — Axon (crashlog + StatusScope)

```yaml
log_type: axon
aka: [Axon, axonsv, record-viewer, crashlog, StatusScope]
captures_layers: [PMC, fabric]
analyzer_mcp: <axon / axonsv>
mcp_status: todo
schema_ready: no
time_base: <TODO>
provides_anchors: [error-record time, captured signal event]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
Umbrella for **Axon-based captures** — two flavors:
- **Crashlog** — platform crash/error records captured at/after the failure (listed in this sighting's
  HSD `debug_tools`). `TODO(owner): confirm exact scope/source.`
- **StatusScope** — Axon **record-viewer** (`axonsv`) signal captures.
> Note: an earlier waveform attributed to StatusScope in sighting 16027585017 was corrected — that
> evidence was actually a **VISA** capture (see `knowledge/visa.md`). No confirmed StatusScope use yet.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** crashlog at/after the failure; StatusScope when an Axon record capture is needed.
- **HOW:** `TODO(wiki): crashlog collection procedure` · `TODO(wiki): StatusScope (axonsv record-viewer) capture & share`.
- **WHY:** crashlog = captured error records; StatusScope = recorded signal states.

## 3. Analyzer — MCP (todo)
`TODO(wiki): Axon/axonsv decode reference + MCP for crashlog records and StatusScope captures.`

## 4. Normalized output → common event schema
- `ts` ← `TODO`; `layer: PMC|fabric`. Events: crashlog error-records / StatusScope signal events.
- **Anchors it provides:** error-record time; captured signal event.

## 5. Healthy vs failing reference
- `TODO: expected clean vs error signature (crashlog records; StatusScope signal states).`

## 6. BKM (best-known methods)
- `TODO(owner): Axon crashlog + StatusScope capture BKMs.`
- Before attributing a waveform to StatusScope, confirm it isn't actually a **VISA** capture (past mix-up).

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet.)_
