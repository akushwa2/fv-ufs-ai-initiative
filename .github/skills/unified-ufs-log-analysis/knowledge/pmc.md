# Log Module — PMC FW Trace (Power Management Controller)

```yaml
log_type: pmc
aka: [PMC trace, PMC FW trace, PMSync trace, pmc-trace-mcp, PMC demo trace]
captures_layers: [PMC, fabric, boot-sequence]
analyzer_mcp: pmc-trace-mcp                  # val_mcp_tools/.ai/BDC_CVE/fv-pm/pmc-mcp/server.py
analyzer_repo: intel-sandbox/val_mcp_tools
engine: pmc_agent.py                         # PMCTraceParser + PMCValidator (HAS-grounded); shipped in VE_FV_WG root
mcp_status: wired-and-run
bootstrap: self-wiring                       # agent auto-installs the MCP if absent — see §0
schema_ready: partial
time_base: PMC trace timestamp (Timestamp abs col); separate clock — anchor before correlating
provides_anchors: [PMSync req/rsp, flow.start/end, sleep-level CFI_DOWN/UP, D2D CFI Open/Closed, CPU_BOOT_STATUS, EPOC]
signature_count: 1   # golden: 471 flow events / 0 anomalies on passing NVL boot
```

## 0. Preflight / Bootstrap — agent MUST run before analyzing (self-wiring)
If the `pmc-trace-mcp` server isn't present/working, install it **first**, then analyze. Idempotent; detect before doing.

**Paths:** repo `<INIT>/val_mcp_tools`; server `<INIT>/val_mcp_tools/.ai/BDC_CVE/fv-pm/pmc-mcp`; engine `pmc_agent.py` ships in `<INIT>/VE_FV_WG/pmc_agent.py`. `<INIT> = …/Desktop/Initiatives and Innovation`.

### Phase A — DETECT (read-only)
1. Server dir + `.venv` present? `list_tools` returns the 5 tools?
2. `import pmc_agent` succeeds (has `PMCTraceParser`)? → if all yes, skip to Phase D.

### Phase B — PROVISION (ASK before clone / mcp.json edit)
1. **Clone** (sparse): `git clone --depth 1 --filter=blob:none --sparse …/val_mcp_tools.git` then `git sparse-checkout set .ai/BDC_CVE/fv-pm`.
2. **⚠ Engine gap (verified):** the repo's `pmc-mcp` **references `pmc_agent` but does NOT ship it** (`git grep PMCTraceParser` → only the import). Copy it from VE_FV_WG: `copy VE_FV_WG/pmc_agent.py → pmc-mcp/pmc_agent.py`, and add `sys.path.insert(0, str(_THIS_DIR))` in `server.py` so it imports the co-located copy.
3. **Venv:** `python -m venv --system-site-packages .venv` then `.venv\Scripts\python -m pip install "mcp==1.9.4" requests`. (`mcp==1.9.4` — server uses the mcp-1.x low-level `@server.list_tools()` API.)
4. **stdout patch:** `pmc_agent` has ~39 `print()`s. Wrap `parser.parse()` + `validator.run_all_checks()` (and `_search_entries`/`_analyze_keyword_context`) in `contextlib.redirect_stdout(sys.stderr)` so they don't corrupt the MCP stdio channel.
5. **Verify:** `import server; asyncio.run(server.list_tools())` → 5 tools.

### Phase C — REGISTER (ASK before editing `.vscode/mcp.json`) — see §3.1.

### Phase D — RUN (autonomous)
`select_project <PROJECT>` → `analyze_trace <csv>` → (optional) `search_trace <keyword>`. HAS-URL discovery hits `docs.intel.com` (needs Intel network; static fallback exists) — non-essential (reference only).

### Phase E — FALLBACK
- No network → HAS URLs are reference-only; validation still runs on `pmc_agent`'s built-in register maps.
- Minimal-column CSV (see §5) → flow-level validation only; state the limitation.

> **Guardrails:** detect-first + idempotent; auto-run only cheap/local steps; ask before clone / registry edits; never route secrets through the model; always fall back.

## 1. Identity — what it captures & UFS relevance
PMC FW trace = the **Power Management Controller firmware** event/messaging trace: PMSync register req/rsp (PCD↔Compute), boot sequence, sleep-level CFI transitions, D2D CFI open/close, sideband completions, `CPU_BOOT_STATUS`/`EPOC` boot milestones.

**UFS relevance:** the PMC gates UFS power/clock and IP-ready during boot and PKGC/S0ix. The **boot-sequence + sleep-level + D2D CFI** events are the PMC-side view of the same **fuse-pull / IP-ready / PkgC** story that `register-dump.md` (`pmc.arc.pc_histo` stuck Phase-3 waiting `ufs_ip_ready_status`), `scandump.md` (`dfx_parpmc`), and `visa.md` (`PMCMCPPMFA_ps`, UFS pg_req) cover. This module is the **PMC trace CSV** analyzer; live-silicon PMC PythonSV registers stay in `register-dump.md`.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** boot/PKGC/S0ix anomaly, PMC stuck in a boot phase, UFS IP-ready/power-gate suspicion, or to establish a passing PMC baseline.
- **HOW:** export the PMC FW trace CSV. **Full validation needs the MIPI SyS-T format** (cols: Index, Time, Source, Summary, Packet Type, **Raw**, Timestamp abs, Command, Param1, Param2 — 11+). A minimal 5-col decode (Index,Timestamp,Source,Summary,Status) works but limits analysis to **flow events only** (no PMSync register/opcode decode — needs the `Raw` column).
- **WHY:** HAS-grounded validation of PMC register/opcode/flow/sleep/D2D correctness — much stronger than generic regex.

## 3. Analyzer — MCP: `pmc-trace-mcp`
**Repo:** `intel-sandbox/val_mcp_tools` → `.ai/BDC_CVE/fv-pm/pmc-mcp/server.py` (engine `pmc_agent.py`).

### 3.1 VS Code registration (`.vscode/mcp.json`)
```json
{
  "servers": {
    "pmc-trace-mcp": {
      "type": "stdio",
      "command": "<repo>/val_mcp_tools/.ai/BDC_CVE/fv-pm/pmc-mcp/.venv/Scripts/python.exe",
      "args": ["<repo>/val_mcp_tools/.ai/BDC_CVE/fv-pm/pmc-mcp/server.py"]
    }
  }
}
```

### 3.2 MCP tools (5)
| Tool | Signature | Purpose |
|------|-----------|---------|
| `list_projects` | `()` | List silicon variants (ADP, HML, WCL, PTL, LNL, RZL, MTL, **NVL**, …). |
| `select_project` | `(project)` | Set project → discover Compute-Interface + Boot/Reset/Sx HAS URLs (dynamic, static fallback). |
| `get_required_columns` | `()` | Show required CSV columns (MIPI SyS-T). |
| `analyze_trace` | `(trace_path)` | Full HAS validation → findings by severity + HAS refs. |
| `search_trace` | `(keyword)` | Keyword search + AI-style context (PMSync, slp_lvl, flow.start, D2D_CFI, EPOC, …). Requires `analyze_trace` first. |

### 3.3 Validation checks (`PMCValidator`, HAS-grounded)
PMSync register-address validity (PCD + Compute maps) · opcode correctness (0x0–0xE) · 32/64-bit consistency · data-field ranges (temp/energy/Compute-ID) · **flow.start/end pairing + nesting** · **sleep-level req/rsp (CFI_DOWN/UP)** · **D2D CFI Open↔Closed** · timing anomalies (PMSync latency) · sideband non-posted completion · boot sequence.

> Unlike a regex classifier, this validates against the actual PMC **register maps + opcodes + boot sequence** — findings carry **HAS references**. Still adjudicate, but the check set is real validation.

## 4. Normalized output → common event schema
- `ts` ← PMC trace `Timestamp abs` (separate clock — anchor before merging).
- `layer` ← `PMC` (or `fabric` for D2D CFI / sideband).
- `event` ← PMSync reg access / `flow.start|end` / `slp_lvl_req|rsp` / `D2dCfiOpen|Closed` / `CPU_BOOT_STATUS` / `EPOC`.
- `severity` ← ERROR / WARNING / INFO (validator findings, with HAS ref).
- **Anchors:** boot-sequence milestones, sleep-level CFI transitions, D2D CFI open/close — align PMC time against ESE ROM / scan-dump / VISA timelines.

## 5. Healthy vs failing reference
### 5.1 Golden baseline — MCP-verified (NVL, `PMC_LOG.csv`, passing OS-boot-from-UFS)
`select_project NVL` → `analyze_trace PMC_LOG.csv`:

| Metric | Value |
|--------|-------|
| Total Entries | 2,202 |
| Flow Events | 471 |
| PMSync Messages | 0 *(minimal CSV — no `Raw` col)* |
| Errors / Warnings / Info | **0 / 0 / 0** |
| Verdict | **✓ No Anomalies — passes all HAS validation checks** |

> **Limitation:** `PMC_LOG.csv` is the minimal 5-column decode (empty `Raw`) → the analyzer validated the **471 flow events** (no anomalies) but could **not** do PMSync register/opcode validation. For full register-level checks, capture the **MIPI SyS-T** PMC trace (with `Raw`/`Command`/`Param` columns).

### 5.2 Failing (issue-derived) — what to look for
For `16029205689` (PMC stuck Phase-3 waiting UFS IP-ready): expect boot-sequence not advancing past the UFS-ready milestone, and cross-correlate with `register-dump.md` `pmc.arc.pc_histo` pinned `0xb0548` (Phase-3 wait) + `ufsx2_ip_ready_sts=0`. On a full-column trace, watch for missing flow.end, stuck sleep-level, or D2D CFI not opening.

## 6. Searchable keywords
`PMSync`, `PMDown`, `register`, `opcode`, `flow.start/end/milestone`, `slp_lvl_req/rsp`, `sleep_level`, `D2D_CFI`, `D2dCfiOpen/Closed`, `CPU_BOOT_STATUS`, `EPOC`, `TSC`, `PCH/PCU_MAILBOX`, `PECI`, `Boot_Reset`, `Go_S0/S3/S4/S5`, `Ack_Sx`, `Rst_Warn`, `CPU_Reset_Done`, `sideband`, `COMPLETION`.

## 7. Known signatures (learning loop)
| Signature | Appearance | Means | Confidence | Sighting IDs |
|-----------|-----------|-------|-----------|--------------|
| `471 flow events / 0 anomalies` (golden) | NVL `PMC_LOG.csv` `analyze_trace` | PMC boot flow healthy (flow-level) | Med (flow-only; no PMSync data in minimal CSV) | golden for 16029205689 |

## 8. Examples with issue background (feedback loop)
- **NVL passing OS-boot-from-UFS (2026-09-23 capture):** ran `pmc-trace-mcp` (`select_project NVL` → `analyze_trace PMC_LOG.csv`). 2,202 entries, 471 flow events, **0 errors / 0 warnings** → No Anomalies. Flow-level baseline; PMSync register validation pending a full MIPI SyS-T capture. Cross-correlates with the ESE ROM golden (`cse-ese.md`) and the fuse-pull/IP-ready signatures in `register-dump.md` / `scandump.md`.
