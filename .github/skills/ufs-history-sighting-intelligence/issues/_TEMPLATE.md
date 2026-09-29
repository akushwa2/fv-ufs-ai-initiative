# Issue Record — <ID> — <short title>

> Copy this file to `issues/<primary-ticket-id>.md` and fill every field.
> Mark anything not retrievable/confirmed as **UNKNOWN** (gaps are signal).
> Use ONLY controlled values from `reference/taxonomy.md`. Explain jargon via `reference/ufs-glossary.md`.
> **Two layers, same facts:** the **structured dossier** (frontmatter + §1–11) is the machine/agent-readable
> layer — dense, greppable, exact namednodes/values, confidence-tagged; **§12 debug story** is the
> human-readable layer — narrative. Never duplicate content between them, only re-shape it.
> Tag confidence on non-obvious facts: `[confirmed]`, `[platform-confirmed (<prog>)]`, `[inferred]`,
> `[agent-paraphrased]`, `[gap]` (searched, not found — an honest unknown, not a guess).
> **Attribute facts to their source** (CCB/HSD ticket / register read / spec), NOT to a filename or a person.
> Keep **dates and owner names OUT of the debug flow (§6)** — they belong in frontmatter/§10 only.
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
> Make rule-outs **precise** — a too-broad rule-out causes false negatives (e.g. "not this if UFS disabled"
> was wrong when a strap-disabled config still ran the failing fuse-pull path). State the exact condition.
## 4. Reproduction recipe (config, images, IFWI, knobs, operating point)
## 5. Fault evidence & instrumentation (machine-readable evidence map)
> Machine-readable, agent-actionable, greppable. **No HOW-to-capture here** (defer to
> `unified-ufs-log-analysis`). Organize **by instrument**, each row a **probe**:
> **exact command / namednode → field → value observed at the fault (real hex) → inference → rank**.
> Suggested subsections (use only those that apply):
> - **5a. PythonSV probes** — table: `command/namednode | field | value@fault (good=) | inference | rank`.
> - **5b. Scan dump** — extracted FSM/flop states (verbatim signal paths + raw values).
> - **5c–5e. Other instruments** — one per instrument used (fuse-controller history, StatusScope, PMC SRAM,
>   RTL review, …), each with what it yielded.
> - **5f. Decisive-first capture sequence** — the run order; flag observability **traps** (captures that
>   perturb/mask the failure).
> Tag confidence per row. Prefer **real namednodes + observed values** over prose. When a value is a
> decoded/paraphrased label rather than a raw read, say so (e.g. `[gap: FSM enum]`).
## 6. Debug flow (diagnostic narrowing)
> **Logic-ordered, NOT chronological.** Each step: what we suspected / needed to answer → the evidence that
> resolved it (**cross-reference the §5 rows**) → what it narrowed → the next question. **No dates, no owner
> names, no process noise** (repro logistics, patch rollout, validation cycles, CCB ARs → those live in
> §8/§10). Keep any verbatim parameter/sweep or large register tables as a **§6b** sub-section — but only the
> raw artifacts §5 can't fully hold (e.g. a big multi-row table §5 only samples); do **not** re-list
> per-register reads already tabulated in §5.
## 7. Root cause (precise mechanism + class)
### 7b. Fingerprint registers (high level)
> Name only the decisive register/bits (from `key_registers`) and what they mean for THIS failure —
> one or two lines. Put the full bit-level decode (offset, width, access, enable bits, spec-verbatim
> text) in `reference/ufs-glossary.md` and link it here. Do not duplicate the full decode per record.
## 8. Fix & verification (or workaround + status)
> Fix, workaround **iterations** (what failed and why, then what worked), validation cycles, schedule, and
> CCB disposition live HERE — not in the §6 debug flow. Distinguish interim vs permanent WA and note what
> supersedes what.
## 9. Retrospective (avoidable? prevention? detection gap?)
> Include **dead-ends / false leads**: paths chased that turned out wrong, and the tell that ruled
> each out — so the next debugger (and the agent) does not repeat the wasted work.
## 10. Cross-program linkage (all related ticket IDs + roles)
## 11. Gaps / unknowns
## 12. Debug story (conversational narrative for first-time readers)
> The **human-readable layer** — narrative, rationale, red-herrings, the "aha". Same facts as §1–11,
> re-shaped for a first-time reader. Keep it **accurate**: no stale claims or trap-readings that §5–§7 have
> since corrected.