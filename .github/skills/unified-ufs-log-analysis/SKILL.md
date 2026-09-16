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

## Common event schema (make-or-break)
Every Layer-1 output normalizes to:
`{ source, ts, ts_base, layer(HCI|UniPro|M-PHY|fabric|PMC|OS|BIOS), type, severity, raw, decoded }`
Correlation is impossible without a shared timeline → align clocks using **anchor events** present in
≥2 logs (e.g., `PkgC10 entry` in BIOS+VISA; `IS_ SBFES set` in regdump+VISA). Anchors come from the manifest.

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
| unrecognized | agent asks once, or adds a new `logs/<name>.md` module |

**Handled by external analyzers (no module here):**
- **MCA / PythonSV logs** → the **PythonSV GPT Agent** decodes these; reference its output, don't build a module.
- **Protocol Analyzer (PA)** → a **dedicated MCP** is being built; route PA captures there.

## Per-log modules (extensible registry)
One module per log type under `logs/<name>.md`, all following `logs/_TEMPLATE.md`; `logs/index.jsonl`
is the registry (log_type, analyzer_mcp, mcp_status, signature_count). **Adding a new log = add one
module + one registry line. No restructure.** The log list is deliberately non-exhaustive.

## Correlation playbook (Layer 3)
1. Read the manifest — anchor on the **issue** (symptom, config, sighting_id).
2. If `sighting_id` known → pull its record fingerprint from `ufs-history-sighting-intelligence`.
3. Route each log → its `logs/<type>.md` analyzer (MCP or skill-guided); normalize to the event schema.
4. Merge on `time_anchors` → one timeline.
5. Match against each module's **Known signatures** + the sighting fingerprint.
6. Return **ranked hypotheses**, each with the cross-log evidence chain + confidence + citations.

## Learning loop — new failure signatures
- **Per-log signature** (pattern in one log) → append to that module's **Known signatures** table
  (signature → appearance → meaning → confidence → linked sighting IDs).
- **Whole-issue fingerprint** (spans logs) → goes to `ufs-history-sighting-intelligence`, not here.
- Tag confidence; track recurrence. This is how the skill evolves every analysis.

## Feedback loop — with the sighting skill (bi-directional)
- Whenever a **sighting analysis** meets a log, write a contribution into `logs/<type>.md`:
  a BKM, a Known-signature row, and an **Example-with-issue-background** entry. Requires the actual log content.
- Links: sighting record §5 ↔ `logs/<type>.md` (Examples) — neither side can go stale without the other.

## Maintenance rules
- **One module per log type** (`logs/`); new sightings add new log *types*, not duplicates.
- Every module: Capture WHEN/HOW/WHY · Analyzer(MCP/GAP) · Schema mapping · Healthy-vs-Fault · **BKM** ·
  **Known signatures** · **Examples-with-issue-background**.
- Unknown procedures = **`TODO(wiki)`/`TODO(owner)`** — never guess a command.
- Keep tool commands **verbatim** once confirmed by someone who ran them.
- `logs/index.jsonl` is derived from module frontmatter — regenerate, don't hand-edit.
