# Issue Record — <ID> — <short title>

> Copy this file to `issues/<primary-ticket-id>.md` and fill every field.
> Mark anything not retrievable/confirmed as **UNKNOWN** (gaps are signal).
> Use ONLY controlled values from `reference/taxonomy.md`. Explain jargon via `reference/ufs-glossary.md`.
> Tag confidence on non-obvious facts: `[confirmed]`, `[inferred]`, `[agent-paraphrased]`.
> For HOW to capture any log in §5, point to the `unified-ufs-log-analysis` skill (do not duplicate procedure here).

```yaml
id: <primary HSD id>
title: <ticket title>
source_ticket_urls:                     # provenance — for verification against raw tickets
  - "https://hsdes.intel.com/appstore/article-one/#/article/<id>"
data_source: hsd-text-agent             # how this record was built (agent summary vs raw read)
record_confidence: <confirmed|inferred|agent-paraphrased|mixed>
signature: <canonical-tag from taxonomy.md>
ufs_layer: <value from taxonomy.md>
failure_mode: <value(s) from taxonomy.md>
trigger: <e.g. deep-PKGC/S0ix entry with UFS primary + gfx driver>
programs: [<WCL, PTL, ...>]
severity: <p1|p2|...|unknown>
status: <open|root_caused|fixed|workaround|rejected|unknown>
root_cause_class: <value from taxonomy.md>
key_registers: [<IS_, SBFES, HBFES, UECPA, ...>]
debug_tools: [<PSF, VISA, PA, WinDbg, PythonSV, crashlog, Solar, ...>]
contacts:                               # who to ask (see reference/contacts.md)
  - area: <e.g. UFS IP debug>
    idsid: <owner>
linked_ids:
  - id: <id>
    role: <origin|ip-debug|disposition|fix|prior-art|duplicate|look-alike-not-same>
date_opened: <YYYY-MM-DD>
date_updated: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>             # freshness — when a human last checked this is still true
```

## 1. Identity & classification
## 2. Symptom (observable) + reproducibility profile
## 3. Initial triage — first discriminators
> Also record **matching cues** so the next reader can classify a new issue against this one:
> **Rule-in** (see X → it IS this), **Rule-out** (see Y → it is NOT this),
> **Nearest look-alikes** (which tickets it resembles but differs from, and the deciding tell).
## 4. Reproduction recipe (config, images, IFWI, knobs, operating point)
## 5. Logs / instrumentation — RANKED (decisive / useful / noise)
> For EVERY log capture both **WHEN** (the trigger/stage that tells you to grab it — e.g.
> "arm before repro", "at the hang before any reset", "only during fix validation") AND
> **HOW** (capture method) AND **WHY** (what it yields). End with a decisive-first capture sequence.
## 6. Debug flow (chronological timeline)
> Paste any parameter/sweep tables VERBATIM (with the result column) as a `6b` sub-section — do not
> summarize them away. Tables are decisive boundary data.
## 7. Root cause (precise mechanism + class)
## 8. Fix & verification (or workaround + status)
## 9. Retrospective (avoidable? prevention? detection gap?)
> Include **dead-ends / false leads**: paths chased that turned out wrong, and the tell that ruled
> each out — so the next debugger (and the agent) does not repeat the wasted work.
## 10. Cross-program linkage (all related ticket IDs + roles)
## 11. Gaps / unknowns — ask the debugger
## 12. Debug story (conversational narrative for first-time readers)