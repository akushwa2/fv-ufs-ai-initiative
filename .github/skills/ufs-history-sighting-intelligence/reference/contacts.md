# UFS SME / Owner Contacts (by area)

Because HSD ticket quality is inconsistent, the fastest path to a full picture is often the person
who did the debug. Capture owners here so a newcomer knows *who to ask*. Fill `TODO` as identities
are confirmed. Use HSD idsid where known.

## By debug area
| Area | Role | Contact (idsid) | Notes |
|------|------|-----------------|-------|
| UFS IP debug | primary debugger | `msure` | owner of 16027585017 (OCP fabric timeout debug) |
| Platform BIOS / PKGC / LTR | BIOS owner | `roopaheg` | owner of 14025261732 (BIOS workaround) & 22021069833 (origin) |
| UFS PCH / IP disposition | IP disposition | `muralibh` | owner of 16027667860 (won't-fix disposition) |
| MCA / silicon HW analysis | HW debug | `mjodwal` | MCA THREE_STRIKE / PSF4→UFS analysis |
| OS storage driver (storufs) | Windows driver | `nithyapr`, `rajeshas` | UFS reset-path / DPC watchdog analysis |
| Dispositioner | triage/CCB | `sramak5` | dispositioned 16027667860 |
| PSF trace | SME | `TODO(owner)` | fabric trace capture/decode |
| VISA | SME | `TODO(owner)` | monitor-port capture |
| Protocol Analyzer (PA) | SME | `TODO(owner)` | link SI analysis |
| PythonSV / MCA | SME | `TODO(owner)` | `debug.mca.analyze()` |
| ITP / register access | SME | `TODO(owner)` | `IS_`/UECxx/PMC reads |
| Solar / power validation | SME | `TODO(owner)` | residency regression |

## By program
| Program | UFS validation lead | Notes |
|---------|--------------------|-------|
| WCL | `TODO(owner)` | Wildcat Lake |
| PTL | `TODO(owner)` | referenced as prior-art for the PKGC pattern |
| LKF | `TODO(owner)` | earliest era of the LTR/PKGC class |

> Contact list is derived from ticket authorship in the analyzed cluster — confirm current ownership
> before escalating (people change roles).
