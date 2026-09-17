# Log Module — BSOD Dump (Windows crash / kernel dump)

```yaml
log_type: bsod-dump
aka: [memory dump, minidump, MEMORY.DMP, WinDbg dump]
captures_layers: [OS]
analyzer_mcp: "bsod-copilot (intel-sandbox/VE_FV_WG/bsod-copilot) — WinDbg PS toolkit + per-bugcheck guides"
mcp_status: available        # NOT an MCP — a Copilot-agent WinDbg toolkit (Analyze-Dump.ps1 + BSOD-AutoAnalyzer-Guide)
schema_ready: no             # bsod-copilot emits WinDbg text; we normalize to the event schema (§4)
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

## 3. Analyzer — bsod-copilot (WinDbg toolkit + per-bugcheck guides)
**Analyzer = `intel-sandbox/VE_FV_WG/bsod-copilot`** (a Copilot-agent toolkit, **not** an MCP):
- **Decode (Layer 1):** run `bsod-copilot/tools/Analyze-Dump.ps1 -DumpFile <MEMORY.DMP>` →
  `output/analysis.log` (curated triage: `vertarget`, `.bugcheck`, `!analyze -v`, `!sysinfo smbios`,
  `!cpuinfo`, `!prcb`, `!thread`, `kb 100`, `!irql`, `lm t n`, `!vm`). Follow-ups via
  `tools/Invoke-KdCommand.ps1 -DumpFile <dmp> -Commands "<cmd>"`.
- **Domain playbook:** pick the matching guide in `bsod-copilot/BSOD-AutoAnalyzer-Guide/` by bugcheck.
  For THIS sighting's codes: **`BSOD0x133-guide.md` (DPC_WATCHDOG_VIOLATION)** and
  **`BSOD0x101-guide.md` (CLOCK_WATCHDOG_TIMEOUT)** — both carry copy-paste WinDbg command sequences and
  power/wait-chain triage (`!poaction`, `!powertriage`, `!running -it`, `!stacks 2`, `!timer`, `!whea`).
- **Integration into our pipeline:** feed the `analysis.log` (bugcheck + faulting stack + DPC duration)
  into §4 to emit the event-schema records; then correlate on the timeline (see `correlation/`).
- Requires `kd.exe` (Windows SDK Debugging Tools) + symbol path; large dumps (16–64 GB) are slow first run.

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
- **Route by bugcheck to the bsod-copilot guide:** `0x133`→DPC_WATCHDOG, `0x101`→CLOCK_WATCHDOG,
  `0x124`→MCE, `0x9F`/`0x7A`→power/inpage. For UFS-storage hangs, run the guide's **power + wait-chain**
  commands (`!poaction`, `!powertriage`, `!running -it`, `!stacks 2`, `!timer`) — they confirm the stalled
  `storufs` reset DPC and its >20s duration.

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
