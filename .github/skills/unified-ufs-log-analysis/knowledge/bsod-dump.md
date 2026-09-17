# Log Module — BSOD Dump (Windows crash / kernel dump)

```yaml
log_type: bsod-dump
aka: [memory dump, minidump, MEMORY.DMP, WinDbg dump]
captures_layers: [OS]
analyzer_mcp: WinDbg (kd)     # MCP wrapper TODO
mcp_status: todo              # WinDbg exists; a dump-analyzer MCP for UFS is not yet wired here
schema_ready: no
time_base: os-uptime
provides_anchors: [bugcheck time, DPC watchdog fire, storufs reset entry]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
The Windows **bugcheck + kernel state** at crash — the OS-side face of the failure (driver stack,
bugcheck code, stalled DPC). Complements the silicon view (VISA/register-dump) from above the OS.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** at the BSOD; **attach live KD BEFORE the repro** where possible (post-mortem full dumps were
  unreliable for the fabric-hang class). Save any auto-generated `MEMORY.DMP`.
- **HOW:** `TODO(wiki): KD/WinDbg live-attach setup for a UFS-boot target.` Then `!analyze -v`, `kv`,
  `.frame`, `!error`.
- **WHY:** gives the exact bugcheck code + the stalled driver path.

## 3. Analyzer — MCP (todo) / WinDbg
WinDbg/`kd` decodes the dump. `TODO(wiki): wire a BSOD-dump analyzer MCP that emits the bugcheck code,
faulting stack, and DPC duration in the common event schema.` Until then, read `!analyze -v` output.

## 4. Normalized output → common event schema
- `ts` ← bugcheck/uptime; `ts_base: os-uptime`; `layer: OS`.
- Events: `{type: "bugcheck", decoded: "<CODE>"}`, `{type: "dpc-watchdog-fire"}`, `{type: "storufs-reset"}`.
- **Anchors it provides:** bugcheck time / DPC fire — align with the silicon hang instant (register-dump).

## 5. Healthy vs failing reference
- **Healthy:** no long-running DPC in the storufs reset path.
- **Fault:** watchdog assertion (`nt!KeAccumulateTicks`) with the storufs reset path stalled:
  `storufs!UfsResetBusDpc → UfsResetBus → UfsIntelLkfResetBus → UfsStopAdapter →
  storport!StorPortStallExecution` (UFS bus reset >20s → watchdog).

## 6. BKM (best-known methods)
- Prefer **live KD** over post-mortem for this class — full dumps were unreliable.
- Always capture/record the **exact bugcheck code** + attach the minidump to the sighting (a common gap).
- If the dump was "shared with a team" (e.g. MTC) but not attached to HSD, flag it — the sighting must carry it.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| storufs-reset-dpc->20s | DPC watchdog fires in `UfsResetBus…StallExecution` path | UFS bus reset stalls >20s after fabric hang → watchdog BSOD | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* UFS-primary hang on PKGC. *What the dump showed:*
  `DPC_WATCHDOG_VIOLATION` (WIP) and `CLOCK_WATCHDOG_TIMEOUT` (memory dump captured, shared with MTC);
  DPC stack in the storufs reset path stalling >20s. *How it fit the RCA:* the OS-side symptom of the
  **fabric hang** — recovery (bus reset) can't complete because the controller core is stopped
  (see register-dump SBFES/HCFES), so the watchdog trips. Gap: minidump not attached to HSD.
