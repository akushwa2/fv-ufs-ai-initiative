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

## Intake contract — where you put logs
Drop collected logs in the **gitignored** working area, one folder per failure event, with a manifest:
```
ufs-log-inbox/<case-id>/
  manifest.yaml            # issue context + per-log entries + time_anchors  (see _MANIFEST_TEMPLATE.yaml)
  bsod/ MEMORY.DMP   visa/ capture.csv   fth/ ...   bios/ bioslog.txt   regdump/ ...
```
Then tell me the **case-id**. I read the manifest (issue context first), route each log to its analyzer,
merge on anchors, and return ranked RCA. Raw logs stay local — never committed.

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
