# Correlation Patterns — cross-log signal chains

Per-log **Known signatures** live in each `knowledge/<type>.md`. This file holds the **chains** — how
signatures across *different* logs link into one causal story. A chain is what lets the agent say "these
five logs are the same failure" and rank it. Whole-issue fingerprints still live in the sighting skill;
this is the reusable *log-to-log wiring* that produces them.

> Each pattern: **trigger → chain (log-by-log, time-ordered) → what it proves → confidence → sightings.**
> Match a pattern when a majority of its links are present in the log set.

---

## P1 — `ufs-fabric-timeout-on-pkgc` chain
**Trigger:** UFS is primary storage, PKGC/S0ix enabled, BSOD/MCA/hang; stable with PKGC off.

**Chain (time-ordered across logs):**
1. **bios-log (ACPI/OS):** `_PS0 UFS0 D0 WA` ↔ `_PS3 UFS0` **flood** → OS is churning UFS D-states around PKGC. *(context / symptom)*
2. **visa (fabric):** at a PkgC-exit, `ufs_prim_clkreq`+`req_sa=1`, `PMCMCPPMFA_ps=0x4` → **UFS upstream cycle forces PkgC exit** (the wake).
3. **visa (HCI):** ~**804.432 µs** later, `prim_ism_agent_in` stuck `0x3`, driver `int_sts` read **hangs** → downstream read never completes.
4. **fth-trace (fabric):** last `IS_` read stuck; **non-posted read PSF4→UFS hung** → the hang is *on the fabric*.
5. **register-dump (HCI):** `IS_` **SBFES + HCFES** set → **OCP fabric timeout, core stopped** (fatal, run-stop cleared).
6. **(optional) MCA:** THREE_STRIKE CORE2 MLC on the stuck read — *may be absent* (not mandatory).
7. **bsod-dump (OS):** `UfsResetBus…StorPortStallExecution`, UFS bus reset **>20s** → **DPC_WATCHDOG** BSOD.

**What it proves:** the OS wakes UFS during deep PKGC; UFS's upstream cycle needs resources the PMC hasn't
restored (WCL UFS 3.1 reports **no LTR** to PMC) → **OCP fabric times out** → downstream `IS_` read hangs →
recovery reset stalls → watchdog BSOD. Fault is **fabric power-state timing**, not the UFS link (PA clean).

**Rule-in:** links 2+3 (VISA wake→hang) **and** link 5 (SBFES/HCFES). **Rule-out:** clean `IS_`, no PSF4→UFS
stall, or fails with PKGC fully off → not this chain.

**Confidence:** confirmed · **Sightings:** 16027585017

---

## Adding a new pattern
- Give it an id + trigger. Write the chain **log-by-log, time-ordered**, each link naming the `knowledge/`
  signature it uses. State what it proves, rule-in/rule-out, confidence, sightings.
- If a chain recurs across programs, promote the whole-issue fingerprint into `ufs-history-sighting-intelligence`.
