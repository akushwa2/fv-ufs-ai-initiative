---
name: ufs-history-sighting-intelligence
description: "UFS History Sighting Intelligence — curated memory + database of past UFS IP functional-validation sightings (HSD tickets). USE WHEN: a new UFS issue/sighting/bug appears and you need to know how to triage it, which logs/traces to collect, how to reproduce it, whether it has been seen before on any program, and its likely root cause. TRIGGER PHRASES: UFS, UniPro, M-PHY, UTP/UPIU, link training, PKGC, S0ix, D0/D3, LTR, OCP fabric timeout, DPC_WATCHDOG, MCA THREE_STRIKE, storufs, IS_ register, SBFES, HBFES, UECPA/UECDL/UECN/UECT, BSOD booting from UFS, UFS primary storage. DO NOT USE FOR: non-UFS storage (NVMe-only), general Windows debugging unrelated to UFS, or writing new UFS test content."
---

# UFS History Sighting Intelligence

Curated memory + searchable database of past UFS IP validation sightings. Given a **new** UFS
symptom, this skill answers four questions:

1. **Has this been seen before** (on this or any other program)?
2. **How do I triage it first** — the fastest discriminators?
3. **Which logs/traces do I collect, in what order**?
4. **What is the likely root cause and known fix/workaround**?

## Scope & boundaries (what this skill is / is NOT)

This skill is **curated memory + intelligence distilled from PAST issues** — nothing more. It is one
of several skills a debug agent draws on. Keep it focused; do not absorb the others' jobs.

- ✅ **This skill owns:** the record of every past sighting, the patterns that recur across them, and
  answering "have we seen this before, and what did we learn?"
- ❌ **Does NOT own — defer to:**
  - **HOW to capture/decode a log** → `unified-ufs-log-analysis` skill.
  - **General UFS/UniPro/M-PHY domain facts** → `ufs-knowledge-base` skill.
  - **First-principles reasoning on a *novel* issue with no past match** → the **debug agent**, which
    orchestrates this skill + the others. When nothing matches here, say so plainly and hand back to
    the agent; do not invent a generic decision tree inside this skill.

## Dual-mode usage (standalone + agent)

Same data, two front doors — no separate machinery:
- **Standalone (human):** open the skill, describe a symptom, read the answer from the record prose +
  `curated-patterns.md`.
- **Agent (machine):** the debug agent queries the **record frontmatter + `issues/index.jsonl`** (the
  structured surface) and joins on `signature` / `ufs_layer` / `failure_mode` / `root_cause_class` /
  `key_registers` / `programs` / `linked_ids`.

The prose and the frontmatter/index are the **same facts in two renderings**; the frontmatter is
authoritative for any field the agent joins on.

## How this skill is organized

| Path | Purpose |
|------|---------|
| `issues/` | The **database** — one Markdown record per sighting/cluster, with YAML frontmatter (queryable) + full dossier + conversational debug story. |
| `issues/index.jsonl` | Fast lookup index for the agent — one JSON line per record (`id`, `signature`, `ufs_layer`, `failure_mode`, `root_cause_class`, `programs`, `status`, `key_registers`, `linked_ids`). **Derived from the record frontmatter — single source of truth is the record; regenerate this file whenever a record is added or edited.** |
| `issues/_TEMPLATE.md` | The schema every new record must follow. |
| `memory/curated-patterns.md` | **Curated memory** — cross-issue pattern rollups (the distilled "if you see X, do Y"). Each pattern links back to source record IDs. |
| `reference/ufs-glossary.md` | Primer for engineers new to UFS — terms, stack, normal-vs-fault. Consult when a record uses unfamiliar jargon. |
| `reference/taxonomy.md` | **Controlled vocabulary** for `signature`/`ufs_layer`/`failure_mode`/`root_cause_class`/`confidence`. Records MUST use these values. |
| `reference/contacts.md` | SME / owner contacts by area & program — *who to ask* when the ticket is thin. |

**Companion skill — `unified-ufs-log-analysis`:** this skill decides *which* logs a sighting needs
and *when*; that skill holds the **HOW** (capture/decode procedure) for every log type. Always defer
HOW to it rather than duplicating procedure in a record.

## Workflow: triaging a NEW sighting

Follow these steps in order.

### 1. Normalize the symptom into a signature
Extract: **UFS layer** (App / UPIU / UTP transport / UniPro / M-PHY / interconnect-fabric),
**failure mode** (hang / BSOD / MCA / timeout / data-integrity / link-error), and **trigger
condition** (power-state entry, link training, reset, gear/rate, boot). Produce a short
`signature` tag (e.g., `ufs-fabric-timeout-on-pkgc`).

### 2. Search the database and curated memory
- Grep `issues/index.jsonl` for matching `signature`, `ufs_layer`, `root_cause_class`, and
  key registers/symptoms.
- Read `memory/curated-patterns.md` for any matching pattern.
- Rank matches by closeness (same signature > same layer+trigger > same register signature).

### 3. Emit the triage plan
For the closest match(es), produce:
- **First discriminators** — the quickest include/exclude checks (pull from record §3).
- **Log collection plan** — for each log give **WHEN** (the trigger/stage to capture it — e.g.
  "arm before repro", "at the hang before any reset", "only during fix validation"), **HOW**, and
  **WHY**, ordered decisive-first (pull from record §5). WHEN is as important as HOW: several
  captures (PSF trace, `IS_`/MCA/PMC regs) are worthless if taken at the wrong moment.
- **Debug flow** — the typical narrowing path (record §6).
- **Prior art** — matching IDs + programs, and the historical root-cause distribution.
- **Known fix/workaround** — if the root cause matches (record §8).

### 4. State the unknowns honestly
HSD ticket quality is inconsistent. Always output a **"Gaps / ask the debugger"** section
listing what the historical record could NOT confirm (attachments, exact codes, final
disposition), so the team can chase the original owner.

### 5. Record the sighting & self-learn (memory grows over time)
- **New issue:** create `issues/<ID>.md` from `_TEMPLATE.md`, then **regenerate the index** with `python build_index.py`.
- **Known issue recurs** (a match was found): don't duplicate — append the new occurrence's ticket ID to the matched record's `linked_ids` and bump the pattern's **recurrence** note in `memory/curated-patterns.md` (which programs it's now been seen on). This is how the memory sharpens itself each time it's used.
- **New class emerged:** add a new pattern to `memory/curated-patterns.md`.

## Rules for building/maintaining records

- **⛔ PREFLIGHT GATE (do first — see `issues/_TEMPLATE.md` top):** before ANY analysis or record-writing,
  **retrieve the whole sighting** (every field + **every comment**). **Use THE 100% method:**
  `GET /rest/article/{id}?fields=comments` (hsdes.intel.com; Kerberos/SSO-cookie; whole thread in one field,
  size-immune) via `tools/hsd-comments.ps1 -Id <id>`. Do NOT trust the co-design/GENI agents (truncate) or the
  web Comment tab (503-flaky). **Review the comment `id`s in chronological/thread order** (the parsed
  `++++<id> <idsid>` list) to catch gaps, **follow the ticket graph**
  (dump/RTL/debug analysis often lives on linked/promoted/parent tickets, not the sighting), and **retrieve
  every attached log**. **Anything you cannot pull** — image/snapshot comments, login-gated pages, unsupported
  tenants, truncated `comments` fields, remote-share dumps — **must be reported to the user with the EXACT
  comment `id`s + owning ticket (and attachment filenames) BEFORE building the record**, with a request to
  supply it. Never say “I can't get this data” without listing the precise IDs the user must paste/attach. Do
  not silently proceed on a partial pull.
- **One canonical record per bug**, even when it spans multiple HSD tickets/tenants. List all
  ticket IDs under §10 with their role (origin / IP-debug / disposition / fix / prior-art).
- **Mark every unretrievable or missing field `UNKNOWN`** — gaps are signal.
- **Use controlled vocabulary** from `reference/taxonomy.md` for `signature`/`ufs_layer`/
  `failure_mode`/`root_cause_class`. Reuse an existing `signature` if the mechanism matches; add a new
  taxonomy value there *before* using it. Never coin free-text tags inline.
- **Tag confidence** on non-obvious facts (`[confirmed]` / `[inferred]` / `[agent-paraphrased]`) and
  record `source_ticket_urls` so any claim can be verified against the raw ticket.
- **Rank logs** as `decisive` / `useful` / `noise`; for HOW to capture each, defer to the
  `unified-ufs-log-analysis` skill instead of duplicating procedure.
- **Attachments are not retrievable via HSD tooling** — record filenames + who holds them, and list the
  owner in `contacts` / `reference/contacts.md`.
- **Capture losslessly — structure must not cost content.** Transfer *all* specifics from analysis into
  the record; do NOT paraphrase decisive data into a summary phrase. Paste **verbatim tables**
  (e.g., parameter sweeps with their result column) rather than describing them as a "boundary map."
- **Note the non-text blind spot.** HSD text tooling recovers pasted-text tables (alignment may be lost)
  but **cannot retrieve or detect images, screenshots, pasted-as-picture tables, waveforms, or diagrams.**
  Flag this in §11 whenever a ticket likely contains such content.
- **`index.jsonl` is derived, not authored.** The record frontmatter is the single source of truth;
  regenerate the whole index by running **`python build_index.py`** whenever a record is added or edited,
  so the agent never reads stale data. Never hand-edit `index.jsonl`.
- **Self-learning is lightweight:** when a known pattern recurs, record the occurrence (add the ticket ID to
  `linked_ids`, update the pattern's recurrence/programs) rather than creating a duplicate record. Memory
  improves by accumulating real occurrences, not by adding machinery.
- Keep the structured dossier AND the conversational debug story in every record.

## Data provenance / limitations

Records are built from HSD ticket **text + comments + fields** (via the HSD MCP tools). Binary
**attachments** (dumps, PSF/PA/VISA traces, Solar logs, waveforms) and dedicated HSD
**Link/Sets** fields are **not** retrievable by tooling — they are referenced narratively only.
Treat any field sourced from a NULL HSD field as lower-confidence.
