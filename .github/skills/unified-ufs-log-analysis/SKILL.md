---
name: unified-ufs-log-analysis
description: "Unified UFS Log Analysis — capture, decode, and CROSS-CORRELATE every UFS validation log onto one timeline to produce a ranked, evidence-backed root cause. USE WHEN: an engineer has a UFS log SET (BIOS log, VISA, FTH trace, BSOD dump, register dump, CSE/ESE PHY, driver ETL, PSF/PA/MCA/ACPI/Solar) and needs it analyzed AGAINST the issue and correlated, OR needs the exact HOW to capture/read one log, OR wants to feed a newly seen log + its analysis back into the catalog. TRIGGER PHRASES: analyze my logs, correlate logs, log set, one timeline, root cause from logs, BIOS log, VISA, FTH trace, BSOD dump, register dump, CSE/ESE, driver ETL, PSF trace, PA, WinDbg, PythonSV, MCA decode, IS_ register, SBFES, HCFES, UECPA, PMC pwr_sts, ACPI dump, Solar, ufs-log-inbox, case manifest. ANALYZE LOGS WITH REFERENCE TO THE ISSUE, never standalone. PAIRS WITH: ufs-history-sighting-intelligence (decides WHICH logs a sighting needs + holds whole-issue fingerprints; THIS skill captures, correlates, and reasons over the log set)."
---

# Unified UFS Log Analysis

The **capture → correlate → reason** layer for UFS debug. Companion skill
`ufs-history-sighting-intelligence` decides *which* logs a sighting needs and holds whole-issue
fingerprints; **this skill captures each log, fuses the set on one timeline, and returns a ranked,
evidence-backed root cause.**

## Golden rule — never analyze a log standalone
Always analyze logs **with reference to the issue.** A log alone is ambiguous; the same log read
against the symptom, config, and (if known) the sighting record is decisive. Every analysis **starts**
from the case manifest (issue context) and **ends** by feeding what was learned back into the record +
this skill.

## Architecture — 3 layers (skill + MCP, not either/or)
| Layer | Job | Home |
|-------|-----|------|
| **1. Decode** | parse each raw log/binary into structured events | **MCPs** (one per log type; some are GAPs) |
| **2. Merge** | normalize clocks, align on anchors → one ordered timeline | deterministic **merge MCP** (skill-guided until built) |
| **3. Correlate + RCA** | match fingerprints, build evidence chain, rank causes, cite history/glossary | **THIS skill (reasoning)** |

- Decoders never live in the skill (no LLM hand-parsing of binaries); RCA judgment never lives in an MCP.
- **Gaps today (no MCP):** VISA, register-dump → analyzed skill-guided (glossary + register spec) until built.

> **Current operating mode (be honest):** most Layer-1 MCPs and the Layer-2 merge MCP are **not wired yet**
> — today the skill runs in **skill-guided manual mode**: the agent reads each log (image/text) directly,
> normalizes by hand to the event schema, and correlates by reasoning. Per-module `mcp_status`/`schema_ready`
> tell you what's real. As MCPs land, they slot into Layer 1/2 without changing Layer 3.

## Common event schema + correlation artifacts
The cross-log "brains" live in **`correlation/`** (not scattered across per-log modules):
- **`correlation/event-schema.md`** — the concrete common event schema + example normalized instances.
- **`correlation/anchor-catalog.md`** — the shared **time-sync anchors** that recur across logs (align ≥2 logs).
- **`correlation/correlation-patterns.md`** — cross-log **signal chains** (e.g. the fabric-timeout chain).
- **`correlation/worked-example.md`** — one end-to-end case fused on a single timeline → ranked RCA (the proof).

Schema (summary): `{ source, ts, ts_base, layer(HCI|UniPro|M-PHY|fabric|PMC|OS|BIOS), type, severity, raw, decoded }`.
Correlation is impossible without a shared timeline → align clocks on **anchor events** present in ≥2 logs.

## Intake contract — minimal user input
**The user does only two things: (1) drop logs in a folder, (2) give the sighting id.** No manifest authoring.
```
ufs-log-inbox/<case-folder>/       # just the logs; typed subfolders optional
  bsod/ MEMORY.DMP   visa/ capture.csv   bios/ bioslog.txt   regdump/ ...
```
**Invocation prompt the user uses:**
> **“Analyze the UFS logs in `ufs-log-inbox/<case-folder>` for sighting `<HSD id>`.”**
> (No sighting id? Give the symptom instead — the agent asks at most one clarifying question.)

**The agent then auto-builds the manifest — the user never writes one:**
1. Discover the files; **infer each log's `type`** from name/extension/folder (mapping below).
2. Pull the **issue context + fingerprint** from the sighting record `issues/<id>.md`
   (via `ufs-history-sighting-intelligence`) — symptom, config, expected registers/signals.
3. Derive the cross-log **`time_anchors`** from that fingerprint + what the logs actually contain.
4. Write `manifest.generated.yaml` in the case folder (transparency), then decode → merge → correlate
   → ranked RCA. Raw logs stay local — never committed.

### Log-type inference (folder / filename → log_type)
| Hint | log_type |
|------|----------|
| `bsod/`, `*.dmp`, `MEMORY.DMP`, `*minidump*` | bsod-dump |
| `visa/`, `visa*`, monitor-port `*.csv` | visa |
| `bios/`, `bioslog*`, `serial*` | bios-log |
| `fth/`, `fth*`, `psf*` | fth-trace |
| `regdump/`, `reg*`, `*regs*`, ITP/PythonSV dumps | register-dump |
| `acpi*` | bios-log (BIOS log includes ACPI/D0-D3) |
| `cse*`, `ese*` | cse-ese |
| `*.etl`, `etw*` | driver-etl |
| `solar*` | solar |
| `socwatch*`, `soc_watch*`, `soc-watch*` | socwatch |
| `crashlog*`, `statusscope*`, `axon*`, `axonsv*` | axon |
| unrecognized | agent asks once, or adds a new `knowledge/<name>.md` module |

**Handled by external analyzers (no module here):**
- **MCA / PythonSV logs** → the **PythonSV GPT Agent** decodes these; reference its output, don't build a module.
- **Protocol Analyzer (PA)** → a **dedicated MCP** is being built; route PA captures there.

**Fetched, not dropped (DB-backed log types):**
- **`axon`** is **queried live** via the `axon-server` MCP, not placed in the inbox. Input = an **AXON
  record-viewer URL / failure UUID** *or* an **HSD sighting id** (→ `get_status_scope_insights_for_sighting`,
  a direct bridge from a sighting record to its real AXON failures). See `knowledge/axon.md`.

## Per-log knowledge modules (extensible registry)
One module per log type under **`knowledge/<name>.md`**, all following `knowledge/_TEMPLATE.md`;
`knowledge/index.jsonl` is the registry (log_type, analyzer_mcp, mcp_status, signature_count).
**Adding a new log = add one module + one registry line. No restructure.** The log list is non-exhaustive.
- **Create modules lazily** — add a `knowledge/<type>.md` when a log type is **first actually analyzed**
  (or when you're about to feed it), not eagerly for every conceivable log. A stub with no content is debt.

## Correlation playbook (Layer 3)
1. Read the manifest — anchor on the **issue** (symptom, config, sighting_id).
2. If `sighting_id` known → pull its record fingerprint from `ufs-history-sighting-intelligence`.
3. Route each log → its `knowledge/<type>.md` analyzer (MCP or skill-guided); normalize to the event schema.
4. Merge on `time_anchors` (see `correlation/anchor-catalog.md`) → one timeline.
5. Match against each module's **Known signatures**, the **`correlation/correlation-patterns.md`** chains, and
   the sighting fingerprint.
6. Return **ranked hypotheses**, each with the cross-log evidence chain + confidence + citations.
   (See `correlation/worked-example.md` for the reference output.)

## Learning loop — new failure signatures
- **Per-log signature** (pattern in one log) → append to that module's **Known signatures** table
  (signature → appearance → meaning → confidence → linked sighting IDs).
- **Whole-issue fingerprint** (spans logs) → goes to `ufs-history-sighting-intelligence`, not here.
- Tag confidence; track recurrence. This is how the skill evolves every analysis.

## Feedback loop — with the sighting skill (bi-directional)
- Whenever a **sighting analysis** meets a log, write a contribution into `knowledge/<type>.md`:
  a BKM, a Known-signature row, and an **Example-with-issue-background** entry. Requires the actual log content.
- Links: sighting record §5 ↔ `knowledge/<type>.md` (Examples) — neither side can go stale without the other.

## Maintenance rules
- **One module per log type** (`knowledge/`); new sightings add new log *types*, not duplicates. Create lazily.
- Every module: Capture WHEN/HOW/WHY · Analyzer(MCP/GAP) · Schema mapping · Healthy-vs-Fault · **BKM** ·
  **Known signatures** · **Examples-with-issue-background**.
- Unknown procedures = **`TODO(wiki)`/`TODO(owner)`** — never guess a command.
- Keep tool commands **verbatim** once confirmed by someone who ran them.
- `knowledge/index.jsonl` is derived from module frontmatter — regenerate with `build_index.py`, don't hand-edit.
