# Log Module — StatusScope (deep AXON failure analysis, via statusscope-mcp)

```yaml
log_type: statusscope
aka: [StatusScope, intel-svtools-report-v1, AXON analysis, MCA decode, FSM hang]
captures_layers: [PMC, fabric, HCI, OS]
analyzer_mcp: "statusscope-mcp (intel-sandbox/VE_FV_WG/mcp-servers/statusscope-mcp)"
mcp_status: available
schema_ready: no            # returns structured insights/verdict JSON; normalize to the event schema (§4)
time_base: axon-record-ts
provides_anchors: [failure timestamp, MCA time, FSM-hang detection time]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
The **smart analysis layer** on top of AXON's StatusScope report (`intel-svtools-report-v1`) — not raw
retrieval (that's `knowledge/axon.md`). Recursively extracts insights from 2000+ sub-analyzers, categorizes
by severity (`HW.HANG`, `HW.STUCK_TRANSACTION`, `HW.MCE.*`, `HW.CFG`, `HW`, `SW`), auto-decodes MCA
signatures + FSM hang state, and can compare 2–10 records for cross-failure correlation. Complements our
own correlation layer (`correlation/`) at the *single-record* level; use `correlation/` for cross-log-type fusion.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** once you have an AXON record-viewer URL / failure UUID (from `axon.md` or directly).
- **HOW (input):** call `statusscope-mcp` tools with the AXON link/UUID.
- **WHY:** turns thousands of raw insights into a categorized verdict + MCA/FSM decode + affected-IP list,
  without hand-parsing the StatusScope report.

## 3. Analyzer — statusscope-mcp
| Tool | Use |
|------|-----|
| `get_failure_metadata(axon_link)` | platform/stepping, host, tickets, content types |
| `get_content_types(axon_link)` | discover attached reports |
| `get_statuscope_report(axon_link)` | raw `intel-svtools-report-v1` JSON (sub_reports, insights, tables) |
| `analyze_failure(axon_link)` | **primary tool** — categorized insights + verdict + integrated MCA decode |
| `generate_triage_report(axon_link)` | full AI HTML report (verdict, RCA, MCA table, timeline, affected components, next steps) → Desktop |
| `compare_records(axon_links=[...])` | 2–10 records → common/unique insights, failure cards, `SAME_BUG\|RELATED_BUGS\|DIFFERENT_BUGS` verdict |
| `get_sighting_insights(sighting_id, days=30)` | aggregate insights across all AXON records for an HSD sighting |

**Recommended order:** `get_failure_metadata` → `analyze_failure` (primary) → `generate_triage_report` if a
shareable artifact is needed. For multi-record: `compare_records`.

**Integrated MCA flow** (inside `analyze_failure`/`generate_triage_report`): fetches `intel-mca-json-v2` →
extracts MCA signatures (`MCACOD=`, `IA32_MCi_STATUS=`, bank refs) → decodes bank type (IFU/DCU/DTLB/MLC/
PCU/…) + error type (Cache/TLB/Bus-Interconnect/Internal) → looks up related registers → AI RCA → checks for
**FSM hang** (decodes FSM state on hang/stuck/timeout insights).
> Our external rule still routes **deep, from-scratch** MCA/PythonSV decode to the **PythonSV GPT Agent**;
> StatusScope's MCA decode is a fast, AXON-integrated first look, useful to triage before invoking that agent.

- **Setup:** add to `.vscode/mcp.json` (`command: python`, `args: [.../statusscope-mcp/server.py]`); deps
  `mcp`, `requests`, `requests-negotiate-sspi` (Windows Kerberos/SSPI, auto on Intel network); uses
  `vertex_bridge.py` for the AI HTML report.

## 4. Normalized output → common event schema
- `ts` ← AXON record timestamp; `ts_base: axon-record-ts`; `layer` per insight category (HCI for HW.HANG/
  STUCK_TRANSACTION on a controller, PMC/fabric for power/interconnect insights, OS for SW).
- Events: `{type: "hw-hang"|"stuck-transaction"|"mca"|"cfg"|"fsm-hang", severity, decoded: "<insight/verdict>"}`.
- **Anchors it provides:** failure timestamp, MCA time, FSM-hang detection — align with register-dump/VISA/bsod.

## 5. Healthy vs failing reference
- **Healthy:** `analyze_failure` verdict = no HW.HANG/STUCK_TRANSACTION/MCE; only `SW`/benign insights.
- **Fault:** verdict names a hardware hang/stuck-transaction/MCE class, with affected components listed
  (e.g. GT, D2D UCIe, PM, IOC, Display — watch for UFS/fabric/PMC equivalents in our domain).

## 6. BKM (best-known methods)
- Use `analyze_failure` as the **primary** tool — don't hand-parse `get_statuscope_report`'s raw JSON unless
  you need a specific sub-report.
- For "is this the same bug as X", use `compare_records` rather than eyeballing two reports.
- Cross-check the verdict's **affected components** against our fingerprint's expected layer (fabric/PMC/HCI)
  before accepting it as this sighting's class.
- Don't mistake a StatusScope **insight report** for a signal **waveform** — waveforms are VISA (`visa.md`).

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| ufs-stuck-txn->lock-fsm-stop_core->uncore-hang | `analyze_failure` verdict = **HW Hang**; headline `cNCU_IDI_Bridge:LockFSM_Stuck:Stop_Core_Cmp`. Chain: `UFS:Stuck_Transaction` + `Downstream PSF Completion Tracker ≠ 0 PSF0.PSF4→PSF4.UFS` → `CCF 2 valid entries (cbo0,cbo3)` → `cNCU/sNCU lock_trk FSM = Stop_Core / Stop_Core_Cmp / LKFSM_STOP_REQ_1_CNCU` → `core hung with valid TOR` + `non posted transactions are stuck`. Collateral: `PM_PSTATE_TRANSITION` 12-domain mismatch, IOAPIC EOI-missing VTd int. | a stuck non-posted **UFS** read stalls the fabric above PSF0 and **blocks an in-flight LOCK/atomic flow that already quiesced the cores** → cores can't resume → **uncore hang** → THREE_STRIKE / DPC_WATCHDOG. The deep-PkgC / missing-LTR fabric-timeout class (Pattern P1). | confirmed (axon MCP) | 16027135581, 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027135581 / 16027585017 — UFS-primary DPC_WATCHDOG on PkgC6/C10 (Pattern P1 `ufs-fabric-timeout-on-pkgc`).**
  *Record:* axon `019633cb-887d-78d1-97c2-cdb3d1bfc8b8` (linked to **both** sightings). *How pulled:*
  `analyze_failure("019633cb-…")` — 53 insights, verdict **Hardware Hang**. *What it showed:* the full
  escalation chain above — stuck UFS non-posted txn (`access to device: UFS is stuck`, addr `0x10813338020`),
  PSF completion tracker not draining `PSF0.PSF4→PSF4.UFS`, CCF `cbo0`/`cbo3` valid, and the **lock FSM wedged**
  `Stop_Core` → `Stop_Core_Cmp` (`cNCU_IDI_Bridge`) / `LKFSM_STOP_REQ_1_CNCU` (`sNCU`), C-die NOC `memss` ports
  Rx-disconnecting, IOC `NP_FSM_CPL_WAIT`. *How it fit the RCA:* this is the concrete "one stuck UFS read →
  whole-SoC hang" mechanism behind the THREE_STRIKE CORE2 / DPC_WATCHDOG — richer than the HSD comment
  paraphrase (adadi, comment `1666624165`). *Trap:* record **platform label = `PTL A0`** is a PythonSV-config
  artifact (insight: *"pantherlake Python SV nightly > 21 days out of date"*); DUT is **WCL** (`BAWCLNUC012`).
  See sighting record `issues/16027135581.md` §5a.
