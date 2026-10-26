# Worked Example — 16027585017 fused on one timeline

The reference end-to-end run: a real log set correlated into one timeline and a ranked, evidence-backed
root cause. This is the **proof the skill works** and the template for every future analysis output.

## Input (what the user did)
- Dropped logs in `ufs-log-inbox/16027585017/` and said:
  *"Analyze the UFS logs in `ufs-log-inbox/16027585017` for sighting 16027585017."*
- Log set analyzed here: **bios-log (ACPI D0/D3 dump)** [provided], plus **VISA**, **register-dump**,
  **FTH**, **BSOD** [from the sighting record; add the raw captures as they arrive].

## Issue context (pulled from the sighting record, not the logs)
WCL, UFS = primary storage, BSOD/MCA/hang when PKGC/S0ix enabled; **stable with PKGC off**. Expected
fingerprint: `IS_` SBFES/HCFES, VISA wake→`int_sts` hang (~804µs), DPC watchdog. Anchors: **PkgC exit**,
**`IS_` SBFES set**.

## Merged timeline (anchored on PkgC-exit and the fatal `IS_` set)
| # | t (rel) | source | layer | event | evidence |
|---|---------|--------|-------|-------|----------|
| 1 | boot+ | bios-log | OS | **D0/D3 flood** `_PS0 UFS0 D0 WA` ↔ `_PS3 UFS0` ×167/165 | ACPI dump |
| 2 | T0 | visa | fabric | **UFS forces PkgC exit** `ufs_prim_clkreq`+`req_sa=1`, `PMCMCPPMFA_ps=0x4` | Comment_10.png |
| 3 | T0+804.432µs | visa | HCI | **`int_sts` read hangs**, `prim_ism_agent_in` stuck `0x3` | Comment_10.png |
| 4 | ~T0 | fth-trace | fabric | last `IS_` read stuck; **PSF4→UFS non-posted read hung** | PSF trace |
| 5 | ~T0 | register-dump | HCI | **`IS_` SBFES + HCFES set** → core stopped | ITP/PythonSV |
| 6 | T0+>20s | bsod-dump | OS | **UFS bus reset >20s → DPC_WATCHDOG** | WinDbg |

(Register-dump and FTH are snapshots — anchored at the fatal-`IS_` instant, step 5, per `anchor-catalog.md`.)

## Correlation → matches pattern P1 (`correlation/correlation-patterns.md`)
Links 1–7 of P1 all present (MCA optional) → **rule-in satisfied** (VISA wake→hang + SBFES/HCFES).

## Ranked root cause
1. **[confirmed, high] OCP (Sonics) fabric timeout on deep-PKGC entry, from missing UFS→PMC LTR.**
   UFS upstream wake mid-PKGC (step 2) needs resources the PMC hasn't restored → fabric times out →
   `IS_` SBFES/HCFES (step 5) → downstream `int_sts` read hangs (step 3) → reset stalls → watchdog (step 6).
   Evidence chain spans BIOS/VISA/regdump/FTH/BSOD; PA clean rules out the link.
2. **[ruled out] UFS link / signal-integrity** — PA showed no SI suspect; data path clean.
3. **[ruled out] OS power-policy (PEP)** — PEP constraints overridden yet hang persisted; `_PS0`-only WA
   insufficient once PKGC entered.

**Fix pointer:** report UFS LTR ≈650µs (blunt; blocks deep S0ix) → refined: ignore/disqualify UFS LTR on
D3/S0ix entry, re-qualify on D0/S0ix exit. See sighting record §8.

## Why this is the template
Every analysis should end like this: **merged timeline table → pattern match → ranked, evidence-cited RCA
→ fix pointer.** Add new worked examples as new correlated cases are completed.
