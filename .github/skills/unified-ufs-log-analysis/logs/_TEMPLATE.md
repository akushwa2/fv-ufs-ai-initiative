# Log Module — <Log name>

> Copy to `logs/<log-name>.md`. Fill every section. `TODO(...)` = an honest gap for an SME — never guess.
> **Golden rule:** this module reads the log **against an issue**, never standalone. §8 is what makes it
> smart over time — every real analysis adds an example with its issue background.

```yaml
log_type: <canonical-name>            # controlled; must match manifest `type` + logs/index.jsonl
aka: [<other names>]
captures_layers: [<HCI|UniPro|M-PHY|fabric|PMC|OS|BIOS>]
analyzer_mcp: <mcp name / url / none>  # the Layer-1 decoder
mcp_status: <available|gap|todo>       # gap = no MCP yet → skill-guided analysis
schema_ready: <yes|no>                 # emits the common event schema?
time_base: <native clock of this log>  # e.g. os-uptime, tsc, visa-sample-clock, fth-cycle
provides_anchors: [<events this log can sync on>]
signature_count: <n>
```

## 1. Identity — what it captures & which UFS layers it sees
## 2. Capture — WHEN / HOW / WHY
> WHEN (stage/trigger) · HOW (procedure, TODO(wiki) if unknown) · WHY (what it yields).
## 3. Analyzer — MCP (or GAP: skill-guided decode)
> Which MCP decodes it + install/usage; if GAP, how to read it manually (cite glossary / register spec).
## 4. Normalized output → common event schema
> Field mapping to `{source, ts, ts_base, layer, type, severity, raw, decoded}`; which field is the
> timestamp; which events this log can **anchor** on for cross-log alignment.
## 5. Healthy vs failing reference
## 6. BKM (best-known methods)
> Clean-capture tips, pitfalls, gotchas, golden reference. Log-specific.
## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
## 8. Examples with issue background (feedback loop)
> Real cases: **issue context → what THIS log showed → how it fit the correlated RCA.** Cite sighting IDs.
