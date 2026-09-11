---
name: unified-ufs-log-analysis
description: "Unified UFS Log Analysis — the single source of truth for HOW to capture, decode, and interpret every log/trace/register used in UFS IP validation debug. USE WHEN: someone needs the exact procedure to capture or read a UFS-related log (PSF trace, VISA, protocol analyzer/PA, WinDbg, PythonSV/MCA decode, ITP register reads, ACPI dump, crashlog, Solar, StatusScope), what a healthy vs failing capture looks like, when in the debug flow to take it, or which tool/owner/wiki to go to. TRIGGER PHRASES: how to capture, how to take log, PSF trace, VISA, protocol analyzer, WinDbg, PythonSV, debug.mca.analyze, MCA decode, ITP, IS_ register, SBFES, HBFES, UECPA, PMC pwr_sts, ACPI dump, crashlog, Solar, StatusScope, UFS log. DELEGATES TO: how-to-capture-logs/ sub-skill (per-log procedures). PAIRS WITH: ufs-history-sighting-intelligence (that skill decides WHICH logs to take for a sighting; THIS skill says HOW to take each one)."
---

# Unified UFS Log Analysis

The **HOW** layer for UFS debug logging. The companion skill
`ufs-history-sighting-intelligence` tells you *which* logs a given sighting needs and *when*;
**this skill tells you exactly how to capture, decode, and read each one.**

## Structure

| Path | Purpose |
|------|---------|
| `how-to-capture-logs/SKILL.md` | **Sub-skill** — the HOW catalog: one entry per UFS log/trace/register, each with WHEN, HOW (with wiki placeholder), decode/interpretation, healthy-vs-fault, tool owner. |

## How to use

1. You already know *which* log you need (from the sighting skill, or the symptom).
2. Open `how-to-capture-logs/SKILL.md` and jump to that log's entry.
3. Follow **HOW** to capture; use **Decode** to interpret; check **Healthy vs Fault** to know if the
   capture is meaningful.
4. If the **wiki/tool link is a `TODO` placeholder**, fill it in once verified — this catalog is the
   team's single source of truth for capture procedure.

## Maintenance rules

- **One canonical entry per log type.** New sightings add *new log types* here, not duplicates.
- Every entry must have: **WHEN, HOW, Decode, Healthy-vs-Fault, Tool/Owner, Wiki link**.
- Unknown procedures get a **`TODO(wiki)` / `TODO(owner)` placeholder** — never leave it blank or
  guess a command. Placeholders are honest gaps for an SME to fill.
- Keep tool commands **verbatim** once confirmed by someone who ran them.
