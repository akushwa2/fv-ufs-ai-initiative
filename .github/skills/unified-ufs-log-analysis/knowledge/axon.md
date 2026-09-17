# Log Module — Axon (crashlog + StatusScope, via axon-server MCP)

```yaml
log_type: axon
aka: [Axon, axonsv, record-viewer, crashlog, crashdump, StatusScope, HW-errors]
captures_layers: [PMC, fabric, HCI, OS]
analyzer_mcp: "axon-server (intel-sandbox/VE_FV_WG/mcp-servers/axon-server) + statusscope-mcp for deep analysis"
mcp_status: available
schema_ready: no            # MCP returns AXON report JSON; we normalize to the event schema (§4)
time_base: axon-record-ts
provides_anchors: [error-record time, MCA/HW-error time, failure timestamp]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
The **AXON failure database** view of a failure — a *fetched* record (by UUID or via HSD sighting), not a
dropped file. Content objects per record:
- **StatusScope** (`intel-svtools-report-v1`) — structured HW failure insights (`HW.HANG`,
  `HW.STUCK_TRANSACTION`, `HW.MCE.*`, `HW.CFG`) + MCA register data.
- **Crashlog / HW-errors** (`intel-hw-errors-report-v1`, `intel-crashlog-v1`) — MCA/HW error summary + raw crashlog.
- **Crashdump** (`intel-crashdump-v1`), **Flexcon** (`intel-flexcon-report-v1`), **Content** (`intel-content-report-v1`).
> An earlier waveform attributed to StatusScope in sighting 16027585017 was corrected — that evidence was
> actually a **VISA** capture (see `knowledge/visa.md`). StatusScope here = the AXON insight report, not a waveform.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** whenever the failure has an AXON record (post-si validation failures) or an HSD sighting with
  linked AXON records. This log type is **queried**, not dropped in the inbox.
- **HOW (input):** provide an **AXON record-viewer URL / failure UUID** *or* an **HSD sighting id** — the
  agent calls the `axon-server` MCP (Kerberos/SSPI auth on Intel network). No manual token on-network.
- **WHY:** pulls real, structured failure insights + MCA + crashlog straight from the failure DB, and
  aggregates them across every failure linked to a sighting.

## 3. Analyzer — axon-server MCP (+ statusscope-mcp)
**`axon-server`** (FastMCP + `pyaxon`) — raw retrieval & sighting aggregation:
| Tool | Use |
|------|-----|
| `get_axon_failure_by_id(failure_id, axon_db=prod)` | full metadata: `platform.tla`, stepping, host, timestamps, tickets |
| `get_axon_content_types(failure_id)` | discover what's attached (which reports/logs) |
| `get_axon_report_content(failure_id, content_type)` | download a report (StatusScope / crashlog / crashdump …) |
| `get_status_scope_insights_for_sighting(sighting, days=30)` | **aggregate StatusScope insights across ALL AXON records linked to an HSD sighting** (Snowflake) |

**`statusscope-mcp`** (deeper analysis on top of the same AXON data) — use for the *smart* pass:
`analyze_failure` (categorized insights + verdict + **MCA decode + FSM hang**), `compare_records`
(2–10 records → SAME_BUG/RELATED/DIFFERENT), `generate_triage_report` (HTML).

- **Setup:** add to `.vscode/mcp.json` (`command: python`, `args: [.../axon-server/server.py]`); deps
  `fastmcp`, `pyaxon`, `pysvtools.axon-mining-scripts` (from intelpypi). Defaults to **axon prod**.
- **MCA note:** AXON carries MCA JSON (`intel-mca-json-v2`); our external rule still routes deep MCA decode
  to the **PythonSV GPT Agent**, but StatusScope's MCA decode is a fast first look.

## 4. Normalized output → common event schema
- `ts` ← AXON record/error timestamp (`_tsDate`); `ts_base: axon-record-ts`; `layer: PMC|fabric|HCI|OS` (by insight).
- Events: `{type: "hw-hang"|"stuck-transaction"|"mca"|"cfg", severity, decoded: "<insight message>"}`,
  `{type: "crashlog-record", ...}`.
- **Anchors it provides:** failure timestamp, MCA/HW-error time — align with register-dump/bsod on the timeline.

## 5. Healthy vs failing reference
- **Healthy:** no record, or record with only benign/`SW` insights.
- **Fault:** `HW.HANG` / `HW.STUCK_TRANSACTION` / `HW.MCE.*` insights; a crashlog with MCA banks set;
  affected-component mapping implicating the UFS/fabric/PMC path.

## 6. BKM (best-known methods)
- **Bridge from a sighting:** start with `get_status_scope_insights_for_sighting(<our HSD id>)` — it pulls
  real AXON insights for every failure linked to the sighting we're analyzing (e.g. 16027585017), then drill
  into a specific `failure_id` with `get_axon_report_content`.
- Use `get_axon_content_types` **first** to see which reports exist before fetching.
- For a fast verdict + MCA/FSM decode use `statusscope-mcp analyze_failure`; for raw content use `axon-server`.
- Confirm `platform.tla` matches the program under debug (e.g. WCL) before trusting a record.
- Don't mistake StatusScope (insight report) for a signal waveform — that's VISA.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet — populate from real AXON records)_ | | | | |

## 8. Examples with issue background (feedback loop)
- _(none yet.)_ **Next step for 16027585017:** run `get_status_scope_insights_for_sighting("16027585017")`
  to see if AXON holds StatusScope/crashlog records for this sighting; if so, drill in and add a real
  example + signatures here.
