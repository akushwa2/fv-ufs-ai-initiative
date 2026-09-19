# Log Module — Axon (raw failure DB access, via axon-server MCP)

```yaml
log_type: axon
aka: [Axon, AXON DB, crashlog, crashdump, flexcon, content-report]
captures_layers: [PMC, fabric, HCI, OS]
analyzer_mcp: "axon-server (intel-sandbox/VE_FV_WG/mcp-servers/axon-server)"
mcp_status: available
schema_ready: no            # MCP returns AXON report JSON; we normalize to the event schema (§4)
time_base: axon-record-ts
provides_anchors: [error-record time, failure timestamp]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
**Raw AXON failure-database access** — fetch metadata, discover attached content, and pull report objects
by failure UUID or HSD sighting id. This module = the **retrieval layer**. For the smart per-failure
*analysis* (verdict, MCA decode, FSM hang detection, multi-record compare), see **`knowledge/statusscope.md`**
— a separate MCP (`statusscope-mcp`) built on the same AXON data.
Content objects reachable here: **crashlog** (`intel-hw-errors-report-v1`, `intel-crashlog-v1`),
**crashdump** (`intel-crashdump-v1`), **flexcon** (`intel-flexcon-report-v1`), **content**
(`intel-content-report-v1`), and the raw **StatusScope** report (`intel-svtools-report-v1`, best read via
`statusscope.md`'s tools).
> An earlier waveform attributed to StatusScope in sighting 16027585017 was corrected — that evidence was
> actually a **VISA** capture (see `knowledge/visa.md`).

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** whenever the failure has an AXON record (post-si validation failures) or an HSD sighting with
  linked AXON records. This log type is **queried**, not dropped in the inbox.
- **HOW (input):** provide an **AXON record-viewer URL / failure UUID** *or* an **HSD sighting id** — the
  agent calls the `axon-server` MCP (Kerberos/SSPI auth on Intel network). No manual token on-network.
- **WHY:** pulls real, structured failure content straight from the failure DB, and aggregates StatusScope
  insights across every failure linked to a sighting.

## 3. Analyzer — axon-server MCP
**`axon-server`** (FastMCP + `pyaxon`) — raw retrieval & sighting aggregation:
| Tool | Use |
|------|-----|
| `get_axon_failure_by_id(failure_id, axon_db=prod)` | full metadata: `platform.tla`, stepping, host, timestamps, tickets |
| `get_axon_content_types(failure_id)` | discover what's attached (which reports/logs) |
| `get_axon_report_content(failure_id, content_type)` | download a report (StatusScope / crashlog / crashdump …) |
| `get_status_scope_insights_for_sighting(sighting, days=30)` | **aggregate StatusScope insights across ALL AXON records linked to an HSD sighting** (Snowflake) |

- **Setup:** add to `.vscode/mcp.json` (`command: python`, `args: [.../axon-server/server.py]`); deps
  `fastmcp`, `pyaxon`, `pysvtools.axon-mining-scripts` (from intelpypi). Defaults to **axon prod**.

## 4. Normalized output → common event schema
- `ts` ← AXON record/error timestamp (`_tsDate`); `ts_base: axon-record-ts`; `layer: PMC|fabric|HCI|OS` (by content).
- Events: `{type: "crashlog-record"|"crashdump-record", severity, decoded: "<content summary>"}`.
- **Anchors it provides:** failure timestamp — align with register-dump/bsod on the timeline.

## 5. Healthy vs failing reference
- **Healthy:** no record, or record with only benign content.
- **Fault:** crashlog with MCA banks set / crashdump present; content implicating the UFS/fabric/PMC path.

## 6. BKM (best-known methods)
- **Bridge from a sighting:** start with `get_status_scope_insights_for_sighting(<our HSD id>)` — it pulls
  real AXON insights for every failure linked to the sighting we're analyzing (e.g. 16027585017), then drill
  into a specific `failure_id` with `get_axon_report_content`. For the deep verdict, hand the result to
  **`statusscope.md`**'s `analyze_failure`.
- Use `get_axon_content_types` **first** to see which reports exist before fetching.
- Confirm `platform.tla` matches the program under debug (e.g. WCL) before trusting a record.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet — populate from real AXON records)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet.)_ **Next step for 16027585017:** run `get_status_scope_insights_for_sighting("16027585017")`
  to see if AXON holds records for this sighting; if so, drill in and add a real example + signatures here.
