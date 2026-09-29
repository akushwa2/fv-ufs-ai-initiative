# Log Module — CSE/ESE (CSME/OSSE) Firmware Trace

```yaml
log_type: cse-ese
aka: [CSE trace, ESE trace, CSME FW trace, OSSE trace, ESE FWSTS, HECI trace, ROM trace]
captures_layers: [security-engine-fw, fuse-service, boot-sequence]   # NOT M-PHY; see §1 correction
analyzer_mcp: cse-ese-log-analyzer          # PRIMARY: val_mcp_tools/servers/cse-ese-log-analyzer/server.py
analyzer_mcp_alt: csme-osse-mcp             # ALT (raw-hex decode): VE_FV_WG/mcp-servers/csme-osse-mcp
analyzer_repo: intel-sandbox/val_mcp_tools
decoder_toolkit: csme-trace-decoder          # scripts/ + projects/<platform>/ (only for raw-hex decode)
standalone_analyzer: val_mcp_tools/servers/cse-ese-log-analyzer/CSE_ESE_OSSE_log_analyzer_final.py  # 491 patterns
mcp_status: wired-and-run
bootstrap: self-wiring   # agent auto-installs the MCP if absent — see §0 Preflight/Bootstrap
schema_ready: partial
time_base: firmware-event-tick (per-engine; separate clock — anchor before correlating)
provides_anchors: [fuse-pull event, ESE boot checkpoint, HECI handshake]
signature_count: 2   # golden: IFP_SEMAPHORE_GRANTED, STORAGE_INIT device=0x3 status=0x0
```

## 0. Preflight / Bootstrap — agent MUST run this before analyzing (self-wiring)
This module is **self-wiring**: if the `cse-ese-log-analyzer` MCP is not present/working on the setup, the agent installs it **first**, then analyzes. Run the phases in order; each step is **idempotent** (detect before doing).

**Paths** (this setup): repo `<INIT>/val_mcp_tools`; server `<INIT>/val_mcp_tools/servers/cse-ese-log-analyzer` where `<INIT> = …/Desktop/Initiatives and Innovation`.

### Phase A — DETECT (always; read-only, no consent needed)
1. Is the server dir present? (`servers/cse-ese-log-analyzer/server.py`)
2. Is its `.venv` present and does `python test_server.py` pass (4/4, 7 tools, 491 patterns)?
3. Can an MCP `list_tools` round-trip over stdio? → **If all yes, skip to Phase D (run).**

### Phase B — PROVISION (only if missing; **ASK the user before** clone / `mcp.json` edit)
> Cheap/local steps (venv, pip, code patch) may run automatically. Network/clone and registry edits are side effects — **get consent first**.
1. **Clone** (if repo absent, private `intel-sandbox`): `git clone --depth 1 --filter=blob:none --sparse https://github.com/intel-sandbox/val_mcp_tools.git` then `git sparse-checkout set servers/cse-ese-log-analyzer`. *(needs the user's git auth — do not route creds through the model.)*
2. **Venv** (pinned — non-negotiable): `python -m venv --system-site-packages .venv` then `.venv\Scripts\python -m pip install "mcp==1.9.4" tqdm colorama openai msal_extensions`.
   - `mcp==1.9.4` because the server uses the mcp-1.x low-level `@server.list_tools()` API (mcp 2.x removed it).
   - `--system-site-packages` so `genichat`/`codesign` see Intel-internal `svtools`/`pysvtools`.
3. **stdout patch** (required for MCP stdio): wrap the two `pre.scan(...)` calls in `_tool_scan_log` and `_tool_get_log_chunks` with `contextlib.redirect_stdout(sys.stderr)` (add `import contextlib`). Prevents `UnicodeDecodeError 0x97` corrupting JSON-RPC.
4. **Verify:** `python test_server.py` → must be 4/4.

### Phase C — REGISTER (optional; **ASK before editing** `.vscode/mcp.json`)
Add the server with its venv interpreter (see §3.1). Note: VS Code must start the server before its tools surface to the chat client — this may need a reload. **If registration isn't possible mid-session, skip it** and use Phase D's direct-stdio path instead.

### Phase D — RUN (autonomous; no Genie/auth)
`get_log_chunks` → agent adjudicates chunks (§5.3) → `build_report`. Drive `server.py` directly over MCP stdio via the venv interpreter if the VS Code registration hasn't started yet. `scan_log` alone suffices for pass/fail triage.

### Phase E — FALLBACK (degrade gracefully; never fail hard)
- No network/VPN/git auth → cannot clone: tell the user, and if the standalone analyzer is reachable locally, run `CSE_ESE_OSSE_log_analyzer_final.py --log <csv> --no-ai` instead.
- Genie/codesign auth prompt appears → **stop and hand to the user** (never enter secrets). Prefer the auth-free `get_log_chunks`→`build_report` flow.
- Server import fails on mcp version → re-pin `mcp==1.9.4` in the venv.

> **Guardrails:** detect-first + idempotent; auto-run only cheap/local/reversible steps; **ask** before clone / registry edits; **never** route auth/secrets through the model; always offer a fallback.

## 1. Identity — what it captures & which UFS layers it sees
CSE/ESE firmware trace is the **event trace of the Converged Security Engine (CSE) and Embedded Security Engine (ESE / OSSE)** — the management/security microcontrollers, **not** the UFS M-PHY.

> **Correction vs prior draft:** this log does **not** capture the UFS PHY. It captures security-engine FW execution: boot/ROM stages, HECI host↔CSE messaging, firmware-status registers (FWSTS), and — the UFS-relevant part — the **ESE fuse service (`fuse_srv`) that drives FPF fuse pulling**.

**UFS relevance (why it matters for our sightings):**
- The **ESE `fuse_srv`** handles `fuse_srv_handle_query_fuse_value_request`, `fuse_srv_handle_fuse_resensing_request`, `fuse_srv_handle_commit_fuses_request`, and `fpf_drv_commit_all` / `fpf_drv_resense_arrays`. This is the firmware side of the **UFS fuse-pull handshake** that sighting `16029205689` (WCL Phase-3 IP-ready / fuse-pull CDC race) hinges on.
- ESE boot checkpoints + FWSTS gate when the UFS subsystem's fuses are considered "landed" — cross-correlate against the scan-dump fuse-puller FSM (`scandump.md`) and the PythonSV Fuse Controller history (`register-dump.md`).

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** when a UFS fuse-pull / IP-ready anomaly is suspected (fuses not landing, bridge "Fuse Pull Request" not received, ESE boot stall), or any CSE/ESE boot/HECI/FWSTS failure in the power-on→OS window.
- **HOW:** collect the CSME/CSE/ESE FW trace. In `NVL Logs` these arrive **already decoded** as `CSE_LOG.csv` / `ESE_LOG.csv` (Index,Timestamp,Source,Summary,Status) — analyze directly with `cse-ese-log-analyzer` (§3). For **raw hex** traces, decode first via the ALT `csme-osse-mcp` `decode_trace` (§3.5).
- **WHY:** yields firmware-level truth on fuse-service execution, ROM/BUP boot progress, HECI handshakes, and FWSTS — the only view of the ESE side of the fuse-pull contract.

## 3. Analyzer — MCP: `cse-ese-log-analyzer` (primary)

**Repo:** `intel-sandbox/val_mcp_tools` → `servers/cse-ese-log-analyzer/server.py`
(wraps `CSE_ESE_OSSE_log_analyzer_final.py` — **491-pattern** catalog, co-located `genichat/` + `codesign.py` backends). Logs to **stderr** (keeps the MCP stdio channel clean). Use this for **already-decoded** `CSE_LOG.csv` / `ESE_LOG.csv` (Index,Timestamp,Source,Summary,Status).

> For **raw hex** traces that still need decoding, use the ALT server `csme-osse-mcp` (§3.5) — its `decode_trace` runs the `csme-trace-decoder` first.

### 3.1 VS Code registration (`.vscode/mcp.json`) — uses a dedicated venv (see §3.4)
```json
{
  "servers": {
    "cse-ese-log-analyzer": {
      "type": "stdio",
      "command": "<repo>/val_mcp_tools/servers/cse-ese-log-analyzer/.venv/Scripts/python.exe",
      "args": ["<repo>/val_mcp_tools/servers/cse-ese-log-analyzer/server.py"]
    }
  }
}
```

### 3.2 MCP tools (7)
| Tool | Signature | Purpose |
|------|-----------|---------|
| `list_known_patterns` | `()` | Dump the 491-pattern failure catalog (name, regex, severity, desc). |
| `redact_text` | `(text)` | Apply redaction rules to a snippet. |
| `scan_log` | `(log_path, context_window=5, max_hits_returned=50, use_cuda=False)` | Streaming pattern scan, **no AI**. Fast triage → counts + top hits. |
| `analyze_log` | `(log_path, backend="codesign", no_ai=False, redact=False, output_path, ...)` | Full pipeline scan+AI+HTML/TXT (subprocess). Default backend **`codesign`** = IDSID/password, non-interactive (no browser). |
| `read_report` | `(report_path, max_chars=200000)` | Read back a generated report. |
| `get_log_chunks` | `(log_path, chunk_size=500, context_window=5, redact=False, max_chunks=20)` | **Autonomous flow:** scan → return chunks + `cache_key` + `system_prompt`. **No AI/auth.** The calling agent analyzes the chunks. |
| `build_report` | `(log_path, cache_key, ai_results_json, output_path)` | Render HTML from cached scan + the agent's adjudicated results (`ai_backend="copilot"`). |

### 3.3 Autonomous flow (BKM — no Genie, no browser auth) ⭐
This is the self-contained path used to analyze the NVL logs:
1. `get_log_chunks(log_path=ESE_LOG.csv, chunk_size=500, max_chunks=0)` → `cache_key` + chunks + `system_prompt`.
2. **Agent (Copilot) analyzes each chunk** against the `system_prompt` (adjudicate real-vs-benign — see §5.3).
3. `build_report(log_path, cache_key, ai_results_json=<agent JSON>, output_path)` → self-contained HTML.

`scan_log` alone is enough for fast pass/fail triage (no AI).

### 3.4 Install / venv BKM (discovered — not in repo docs)
The server needs an mcp-1.x + Intel-internal env. Reproducible recipe:
```powershell
python -m venv --system-site-packages .venv        # inherits svtools/pysvtools from global
.venv\Scripts\python -m pip install "mcp==1.9.4" tqdm colorama openai msal_extensions
```
- **Pin `mcp==1.9.4`** — the server uses the mcp-1.x low-level `@server.list_tools()` API; mcp 2.x removed it (`AttributeError: 'Server' has no attribute 'list_tools'`).
- **`--system-site-packages`** so `genichat`/`codesign` find Intel-internal `svtools`/`pysvtools`.
- Validate: `python test_server.py` (4 smoke tests: imports, analyzer load = 491 patterns, tool list = 7, redact+patterns).
- **stdout fix (applied):** `_tool_scan_log` and `_tool_get_log_chunks` call `LogPreFilter.scan()` which prints `[SCAN]`/tqdm (incl. a cp1252 `—` = `0x97`) to **stdout** — this corrupts the MCP JSON-RPC channel (`UnicodeDecodeError 0x97`). Wrap both `pre.scan(...)` calls in `contextlib.redirect_stdout(sys.stderr)`.

### 3.5 ALT server — `csme-osse-mcp` (raw-hex decode only)
`VE_FV_WG/mcp-servers/csme-osse-mcp` — tools `list_platforms`, `decode_trace(trace_path, decoder, platform)`, `analyze_trace`. Decoders: CSME, CSME_EXT, **EFW** (=ESE), FWSTS, HECI, ROM, SimicsHCI (platform required for CSME/CSME_EXT/EFW). `analyze_trace` forces `ai_backend="genie"` (interactive browser sign-in) — prefer `cse-ese-log-analyzer`'s autonomous flow instead.

### 3.6 Analysis pipeline (what `scan_log` / Phase-1 does)
`LogPreFilter.scan()` runs the 491 regex signatures on every line, severity-tagged (CRITICAL / HIGH / MEDIUM / LOW / UNKNOWN) with line numbers + context ring-buffer. **Caveat:** the richer catalog **over-flags** on passing logs — always adjudicate CRITICAL/HIGH against the actual line (§5.3).

## 4. Normalized output → common event schema
- `ts` ← firmware event tick (per-engine; **separate clock** — anchor to a shared event before merging onto the unified timeline).
- `layer` ← `security-engine-fw` (CSE) or `security-engine-fw/ese` (ESE `fuse_srv`).
- `event` ← decoded FW event / pattern name (e.g. `fuse_srv_handle_commit_fuses_request`, `fpf_drv_commit_all`, `ROM_FW_FAIL`, `ESE_INIT_FAIL`).
- `severity` ← CRITICAL / HIGH / MEDIUM / LOW / UNKNOWN.
- **Anchors:** fuse-pull request/commit events, ESE boot checkpoints (FWSTS), HECI handshake completion — use these to align ESE FW time against PMC/scan-dump/register timelines.

## 5. Healthy vs failing reference

### 5.1 Golden baseline — MCP-verified (NVL-Hx / NVL-P A0, corp image+IFWI, passing to OS-boot-from-UFS)
Analyzed with the `csme-osse-mcp` analyzer (`LogPreFilter.scan`, `ai_backend=none`) over `NVL Logs/CSE_LOG.csv` + `ESE_LOG.csv`:

| Log | Lines | Hits | Pattern breakdown | CRITICAL/HIGH | Verdict |
|-----|-------|------|-------------------|---------------|---------|
| `CSE_LOG.csv` | 611 | 55 | `ERROR_CODE` ×52 (MEDIUM, generic hex catch-all) + 3 UNKNOWN | **0** | healthy CSME runtime (CM0-PG PM cycling, HECI PM events, storage ED) |
| `ESE_LOG.csv` | 979 | 37 | `ERROR_CODE` ×26 (MEDIUM) + 11 UNKNOWN | **0** | healthy ESE ROM boot |

> `ERROR_CODE` here is the analyzer's generic hex-value regex, **not** a real failure — it matches the fuse-value hex dumps (`ROM_EV_FUSES_VALUE ...`). Zero CRITICAL/HIGH across both logs = clean boot.

**Golden ESE ROM boot chain** (source `SSE_PCD`; runs twice ~25.82s & ~29.46s, byte-identical, all `status=0x0`) — this is the UFS-relevant fuse-controller → storage handshake:
```
HECI link reset → "heci fw is ready" (link_reset_required=0)
ROM_EV_MAIN_START            valid_sram_banks_mask=0x7f
ROM_EV_FUSES_VALUE           lo=0x80034403 mid=0xff272e81 hi=0x7f hw_cfg=0x2a0131
ROM_EV_KEYS_FUSES_VALUE / ROM_EV_TRIP_FUSES_VALUE / ROM_EV_SOFT_AND_HARD_STRAPS_VALUE (soft=0x28008 hard=0x0)
ROM_EV_IFP_REQUESTING_SEMAPHORE   "About to request semaphore to access fuse controller"
ROM_EV_IFP_SEMAPHORE_GRANTED      "Fuse controller IFP semaphore granted"     ← fuse-controller access OK
ROM_EV_BOOT_PATH_TAKEN       path_type=0x3
ROM_EV_SECURITY_FUSES_DEBUG_ONLY  count=0x90 is_locked=0
ROM_EV_FUSE_INTEGRITY_CHECKED     "Security fuses integrity check has passed"  ← fuses valid
ROM_EV_STORAGE_INIT          device=0x3   → ROM_EV_STORAGE_INIT_RESULT status=0x0
ROM_EV_STORAGE_VALIDATE_PART_RESULT status=0x0 partition=0x1
ROM_EV_NVM_READ / ROM_EV_STORAGE_READ_RESULT   status=0x0  (repeated — boot image read)
ROM_EV_INIT_BOOT_PARTITION status=0x0 → ROM_EV_SELECT_DEVICE_AND_PART boot_device=0x3 partition=0x1
manifest validation (HMAC, PUB_KEY_MATCH, XMSS sig, RSA KAT, 3K-PSS)  all status=0x0
ROM_EV_LOAD_MODULE_RESULT / ROM_EV_LOAD_FW_MODULE_RESULT  status=0x0 entry-point=0x40000
ROM_EV_CALL_ENTRYPOINT       "ROM is calling loadable FW"
```
> **Medium caveat (verified — UNCONFIRMED & contradictory):** the logs contain **no literal "UFS" string** (analyzer `UFS_ERR` never fired) and no PHY-load event. `device=0x3` in `ROM_EV_STORAGE_INIT` is printed **raw** (decoder applies no enum). Two candidate enums disagree: (a) the storage-named `STORAGE_DEVICE` list in `csme_fwsts_decode.py` = `[EMMC=0, UFS=1, SPI=2, DRAM=3, NONE=4]` → `0x3`=**DRAM**, UFS=1; (b) ESE `pcd_nvl_h/autogen_ip_load_cfg.py` `IP_LOAD_IP_SPHY_UFS=3` (different namespace) → 3=UFS. The Intel spec (Debug MCP) could not return the `ROM_EV_STORAGE_INIT.device` enum. **Therefore the boot medium is NOT confirmed from the logs; UFS is user-setup context only, and the in-log 0x3 is ambiguous (even maps to DRAM under the storage-named enum).** Resolving it needs the ESE ROM `rom_storage_device_t` enum. The chain below is medium-agnostic boot-storage evidence. The **IFP semaphore request→granted** pair is the ESE-side fuse-controller access handshake.

### 5.2 Failing (issue-derived) — what to look for
For `16029205689` (fuse-controller / IP-ready CDC race), the golden invariants in §5.1 break as: `ROM_EV_IFP_SEMAPHORE_GRANTED` missing after request, `ROM_EV_FUSE_INTEGRITY_CHECKED` failing, or `ROM_EV_STORAGE_INIT_RESULT status != 0x0` / no `ROM_EV_CALL_ENTRYPOINT`. Correlate against controller-ready-low-vs-PHY-ready-high on the scan side (`scandump.md`).

### 5.3 Known-benign false positives — 491-pattern catalog on a PASSING NVL ESE boot ⚠️
The `cse-ese-log-analyzer` (491 patterns) flags CRITICAL/HIGH on `ESE_LOG.csv` that are **all benign** on a passing boot. MCP-verified (`scan_log` + `get_log_chunks`): severity_counts `{CRITICAL:4, HIGH:2, MEDIUM:35, UNKNOWN:954}`. **Always adjudicate against the actual line** before trusting a CRITICAL/HIGH:

| Pattern (sev) | Hits | Actual line (benign) | Why false positive |
|---------------|------|----------------------|--------------------|
| `OSSE_BOOT_FAIL`, `OSSE_INIT_FAIL` (CRITICAL) | 2 | `ROM_EV_REC_INIT ... rec_enabled=1 error_event=0` | recovery init, **error_event=0** = no error |
| `OSSE_DEBUG_FAIL`, `DEBUG_UNLOCK_DENY` (CRITICAL/HIGH) | 2 | `ROM_EV_SECURITY_FUSES_DEBUG_ONLY ... read successfully ... is_locked=0` | debug fuses read **successfully**; expected on corp/prod part |
| `HECI_ERR` (HIGH) | 7 | `[INFO][heci] ... link reset done - heci fw is ready` / `... status=0, link_reset_required=0` | INFO-level healthy HECI link reset + valid header |
| `ERROR_CODE` (MEDIUM) | 26 | `ROM_EV_FUSES_VALUE ... lo=0x.. mid=0x..` | generic hex-value catch-all on fuse dumps |

> BKM: on a healthy NVL ESE boot these six CRITICAL/HIGH hits are expected. A **real** ESE failure shows the §5.1 chain breaking (missing IFP grant / non-zero status / no CALL_ENTRYPOINT) — not these lines.

## 6. Pattern library (KNOWN_PATTERNS categories)
Boot & ROM · CSE/ME Core · **ESE/OSSE** (`ESE_ASSERT`, `ESE_INIT_FAIL`, `ESE_FATAL`, `ESE_TIMEOUT`, `OSSE_FAIL`, `OSSE_CERT_FAIL`, `OSSE_TIMEOUT`) · BUP/Bring-Up · Crypto/Secure-Boot/Key-Mgmt · ACM/TXT/SGX · Storage/Flash/SPI · Power/Thermal · Watchdog/Hang · Debug/DAM/JTAG · FW-Update/Recovery · **OEM/SMIP/Config** (`FPF_ERR` = Field Programmable Fuse error — UFS-relevant) · Measured/Secure-Boot · Memory · Generic catch-alls.
> Full catalog: call the `list_known_patterns` MCP tool (491 entries), or see `val_mcp_tools/servers/cse-ese-log-analyzer/CSE_ESE_OSSE_log_analyzer_final.py` → `KNOWN_PATTERNS`.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| `IFP_SEMAPHORE_GRANTED` (golden) | ESE `SSE_PCD`: `ROM_EV_IFP_REQUESTING_SEMAPHORE` → `ROM_EV_IFP_SEMAPHORE_GRANTED` | ESE ROM got fuse-controller access; fuse pull can proceed | High (MCP-verified passing baseline) | golden for 16029205689 |
| `STORAGE_INIT device=0x3 status=0x0` (golden) | ESE `SSE_PCD`: `ROM_EV_STORAGE_INIT` → `_RESULT status=0x0` | boot-storage init succeeded; **medium unconfirmed** — `0x3` is ambiguous (`STORAGE_DEVICE` enum → DRAM; `IP_LOAD SPHY` → UFS), not decoded in-log | init proven High; **medium attribution LOW/unconfirmed** | golden for 16029205689 |
| `ERROR_CODE` (noise) | analyzer generic hex regex on `ROM_EV_FUSES_VALUE` dumps | **not a failure** — hex-value catch-all | High | — |

## 8. Examples with issue background (feedback loop)
- **NVL-Hx / NVL-P A0 passing OS-boot-from-UFS (2026-09-23 capture):** ran the **`cse-ese-log-analyzer`** MCP (autonomous `get_log_chunks` → agent adjudication → `build_report`, no Genie/auth) over `ESE_LOG.csv`, and the ALT `csme-osse-mcp` Phase-1 over `CSE_LOG.csv`. The ESE ROM chain in §5.1 completed cleanly (IFP semaphore granted, fuse integrity passed, `STORAGE_INIT device=0x3 status=0x0`, all reads `status=0x0`, `CALL_ENTRYPOINT` reached). The 491-pattern catalog raised 4 CRITICAL / 2 HIGH — **all adjudicated benign** (§5.3). `build_report` → `ESE_LOG_report.html`, `failures_found=0`. Golden reference for `16029205689` (§5.2).
