# Anchor Catalog — cross-log time-sync events

Correlation is impossible unless different logs (each on its own clock) can be lined up. An **anchor** is
an event visible in **≥2 logs** that maps their clocks onto one timeline. This is the shared, growing list
of anchors we use; append as new ones prove reliable.

> How it's used: pick anchors that appear in the current log set, match them across logs, and offset each
> log's clock so the anchors coincide. Then all other events fall into place on one timeline.

| Anchor event | Seen in (logs) | How it appears per log | Reliability | Notes |
|--------------|----------------|------------------------|-------------|-------|
| **PkgC10 / deep-PkgC entry** | bios-log, socwatch, visa | BIOS knob/phase; SoC Watch residency window; VISA `pmcm_cstate_ea`/`PMCMCPPMFA_ps` | high | the config gate — present whenever PKGC is enabled |
| **PkgC exit (UFS-forced)** | visa, fth-trace | VISA `ufs_prim_clkreq`+`req_sa=1`, `PMCMCPPMFA_ps=0x4`; FTH upstream txn | high | the wake instant; best primary anchor for the fabric-timeout class |
| **UFS D3 entry / `_PS3`** | bios-log(ACPI), driver-etl, socwatch | ACPI `_PS3 UFS0`; ETL D3-entry; SoC Watch D-state | med | OS-side; maps OS clock to the power timeline |
| **`IS_` SBFES/HCFES set** | register-dump, visa | regdump `IS_` bits; VISA `int_sts` hang / `prim_ism` stuck `0x3` | high | the failure instant; anchors the snapshot regdump onto the timeline |
| **MCA THREE_STRIKE / CATERROR** | (PythonSV GPT Agent), register-dump | MCA bank; regdump state | med | may be absent (MCA not mandatory for this class) |
| **DPC watchdog fire / bugcheck** | bsod-dump, driver-etl | BSOD bugcheck time; ETL reset-start | med | OS recovery instant, ~>20s after the hang |
| **804.432 µs wake→hang interval** | visa (internal) | VISA cursor delta | exact | not a cross-log anchor but the decisive intra-VISA measurement |

## Guidance
- Prefer **high-reliability, unambiguous** anchors as the primary sync point (here: **PkgC exit** or
  **`IS_` SBFES set**).
- Use ≥2 anchors when possible to catch clock drift/scale differences between logs.
- A **snapshot** log (register-dump, MCA) has no timeline of its own — anchor it at the failure instant via
  the fatal-bit anchor.
- New anchor? Add a row with which logs show it and how, and a reliability note.
