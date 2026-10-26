# Log Module — BSOD Dump (Windows crash / kernel dump)

```yaml
log_type: bsod-dump
aka: [memory dump, minidump, MEMORY.DMP, WinDbg dump, hang dump, forced/debugger-break dump]
captures_layers: [OS]
analyzer_mcp: "bsod-copilot (intel-sandbox/VE_FV_WG/bsod-copilot) — WinDbg PS toolkit + per-bugcheck guides"
analyzer_local: "<INIT>/VE_FV_WG/bsod-copilot"   # cloned locally; <INIT> = …/Desktop/Initiatives and Innovation
mcp_status: available        # NOT an MCP — a Copilot-agent WinDbg toolkit (Analyze-Dump.ps1 + BSOD-AutoAnalyzer-Guide)
schema_ready: no             # bsod-copilot emits WinDbg text; we normalize to the event schema (§4)
time_base: os-uptime
provides_anchors: [bugcheck time, DPC watchdog fire, storufs reset entry, PnP re-enumerate wedge, forced-hang (bugcheck 0/0xE2)]
signature_count: 3
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
**Analyzer = `intel-sandbox/VE_FV_WG/bsod-copilot`** (a Copilot-agent toolkit, **not** an MCP). **Cloned locally at `<INIT>/VE_FV_WG/bsod-copilot`** (`<INIT> = …/Desktop/Initiatives and Innovation`).

### 3.0 Prereqs (one-time)
- **`kd.exe`** (Debugging Tools for Windows / Windows SDK). **Installed on this workstation** —
  `C:\Program Files\Windows Kits\10\Debuggers\x64\kd.exe` (v10.0.26100.4188). Note: the cloned
  `tools/Invoke-KdCommand.ps1` shipped `$KD_PATH` pointing at the **`(x86)`** path (doesn't exist here);
  it has been patched to **auto-resolve** the 64-bit path first, then fall back to `(x86)`. If `kd.exe` is
  absent on some box, you can still *interpret an existing kd/`!analyze -v` log* against the guides.
- **Symbols/proxy:** `$PROXY` in `tools/Invoke-KdCommand.ps1` is set to `http://proxy-dmz.intel.com:912`
  (Intel corp) for `msdl.microsoft.com`; symbol cache under `C:\symbols`.

### 3.1 Run it (two modes)
- **Agent mode (intended):** open the `bsod-copilot` folder in VS Code, drop the `MEMORY.DMP` into a
  subfolder, and ask Copilot (Agent mode) “analyze the BSOD dump.” The bundled
  `.github/copilot-instructions.md` makes Copilot act as a **WinDbg kernel-debugging expert**; it calls
  `tools/List-Dumps.ps1` → `tools/Analyze-Dump.ps1` and then references the matching guide.
- **Script mode (Layer-1 decode):** `tools/Analyze-Dump.ps1 -DumpFile <MEMORY.DMP>` → `output/analysis.log`
  (curated triage: `vertarget`, `.bugcheck`, `!analyze -v`, `!sysinfo smbios`, `!cpuinfo`, `!prcb`,
  `!thread`, `kb 100`, `!irql`, `lm t n`, `!vm`). Follow-ups via
  `tools/Invoke-KdCommand.ps1 -DumpFile <dmp> -Commands "<cmd>"`.

### 3.2 Domain playbook — route by bugcheck to `BSOD-AutoAnalyzer-Guide/`
Guides available: **0xA, 0x1A, 0x1E, 0x3B, 0x50, 0x7A, 0x7E, 0x7F, 0x9F, 0xD1, 0xE2, 0xEF, 0x101, 0x10D,
0x124, 0x133, 0x139, 0x1CA, 0x20001**. Pick by code, e.g. `0x133`→`BSOD0x133-guide.md`.
- **For UFS hang/reset/enumeration dumps this sighting-class produces, route PRIMARY to:**
  - **`BSOD0xE2-guide.md` — `0xE2 MANUALLY_INITIATED_CRASH` / debugger break-in `0x0` (forced HANG dump).**
    Key principle: **the bugcheck is only the capture mechanism** — investigate *what the hung system was
    doing*. Its patterns (PPM gate stall = a worker wedged while others pile up; **USB4 D-state ping-pong**
    = a device bouncing D3→D0) are the direct analogues of the UFS **PnP re-enumeration wedge + devnode
    re-enum loop** (see §8, 16029554884). Toolkit: `!analyze -v`, `!pnptriage`, `!irp`, `!devnode`,
    `!stacks 2`, `!running -it`, `!poaction`, `!locks`, `~*kv`.
  - **`BSOD0x133-guide.md` (DPC_WATCHDOG_VIOLATION)** and **`BSOD0x101-guide.md` (CLOCK_WATCHDOG_TIMEOUT)**
    — the *timeout* face (storufs reset DPC >20s); **`BSOD0x9F-guide.md`** (power-IRP timeout / PnP-tree
    lock held — note the faulting driver is usually an innocent **victim**); **`BSOD0x7A-guide.md`**
    (KERNEL_DATA_INPAGE_ERROR — storage failed to service a page-in; investigate the storage stack).
- **Integration into our pipeline:** feed the `analysis.log` (bugcheck + faulting/wedged stack + DPC/wait
  duration + devnode state) into §4 to emit event-schema records; then correlate on the timeline.
- Large dumps (16–64 GB) are slow on first symbol load.

## 4. Normalized output → common event schema
- `ts` ← bugcheck/uptime; `ts_base: os-uptime`; `layer: OS`.
- Events: `{type: "bugcheck", decoded: "<CODE>"}`, `{type: "dpc-watchdog-fire"}`, `{type: "storufs-reset"}`.
- **Anchors it provides:** bugcheck time / DPC fire — align with the silicon hang instant (register-dump).

## 5. Healthy vs failing reference
- **Healthy:** no long-running DPC in the storufs reset path; storufs devnode `DeviceNodeStarted` (stable), no repeated enumerate cycling; no PnP worker blocked on a storport synchronous request.
- **Fault (timeout/watchdog face):** watchdog assertion (`nt!KeAccumulateTicks`) with the storufs reset path stalled:
  `storufs!UfsResetBusDpc → UfsResetBus → UfsIntelLkfResetBus → UfsStopAdapter →
  storport!StorPortStallExecution` (UFS bus reset >20s → watchdog).
- **Fault (forced-hang / enumeration face — `0xE2`/bugcheck 0):** `!analyze` reports **bugcheck 0** (no real
  bugcheck; forced over debugger). A PnP worker is blocked in
  `storport!RaidBusEnumeratorIssueSynchronousRequest` (bus-rescan **INQUIRY**) with a pending
  `IRP_MJ_PNP/QUERY_DEVICE_RELATIONS` on `\Driver\storufs`; the storufs devnode
  (`PCI VEN_8086&DEV_4D47`) is stuck `DeviceNodeEnumeratePending` and **flapping**
  `Started↔EnumerateCompletion↔EnumeratePending`; victims pile up on the registry lock / wait-wake IRPs.

## 6. BKM (best-known methods)
- Prefer **live KD** over post-mortem for this class — full dumps were unreliable.
- Always capture/record the **exact bugcheck code** + attach the minidump to the sighting (a common gap).
- If the dump was "shared with a team" (e.g. MTC) but not attached to HSD, flag it — the sighting must carry it.
- **Route by bugcheck to the bsod-copilot guide:** `0x133`→DPC_WATCHDOG, `0x101`→CLOCK_WATCHDOG,
  `0x124`→MCE, `0x9F`/`0x7A`→power/inpage, **`0xE2`/bugcheck `0`→forced-hang** (`BSOD0xE2-guide.md`).
  For UFS-storage hangs, run the guide's **power + wait-chain** commands (`!poaction`, `!powertriage`,
  `!running -it`, `!stacks 2`, `!timer`) — they confirm the stalled `storufs` reset DPC and its >20s duration.
- **For a forced/hang dump (bugcheck `0` / `0xE2`), the bugcheck is only the capture mechanism** — do NOT
  chase `!analyze`'s faulting symbol/`PROCESS_NAME`. Investigate *what the hung system was doing*:
  `!pnptriage` (blocked PnP worker + pended IRP), `!irp <addr>` (which driver/IRP), `!devnode <addr>`
  (device state + **StateHistory** for re-enum loops), `!stacks 2` / `~*kv` (all-CPU wedge), `!locks` /
  `ExpWaitForResource` (victims). This is how the UFS **enumeration-INQUIRY wedge** (16029554884) was found.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| storufs-reset-dpc->20s | DPC watchdog fires in `UfsResetBus…StallExecution` path | UFS bus reset stalls >20s after fabric hang → watchdog BSOD | confirmed | 16027585017 |
| forced-hang-ufs-reenum-wedge | **bugcheck 0** (debugger break-in / `0xE2`), `!analyze` bucket `0x0_nt!SwapContext`; `!pnptriage` shows a PnP worker blocked ~22–30s in `storport!RaidBusEnumeratorIssueSynchronousRequest` (a bus-rescan **INQUIRY**); `!irp` = `IRP_MJ_PNP/QUERY_DEVICE_RELATIONS` on `\Driver\storufs`; `!devnode` (PCI `VEN_8086&DEV_4D47`, ServiceName `storufs`) stuck `DeviceNodeEnumeratePending` with StateHistory flapping `Started↔EnumerateCompletion↔EnumeratePending`. **Discriminator:** at the hang the devnode is in **D0** (`!devnode` power = PowerDeviceD0) and `!storadapter` = **Working** → **NOT** a power-gate/D3 issue — the powered-on device just won't answer the INQUIRY. Cascade reaches **NTFS** (`NtfsCheckUsnTimeOutWorker` on an NTFS resource) and the **registry lock** (`CmpLockRegistry`). | **Not a bugcheck** — a *forced dump of a hung system*: a synchronous request to the UFS device (here the **enumeration INQUIRY**, not a SCSI READ) never completes → PnP worker wedges → NTFS + registry + other threads pile up → whole-system hang. The UFS devnode is in a **re-enumeration loop**. Same root shape as the data-path recovery hang, different OS entry point. Route via **`BSOD0xE2-guide.md`**. | confirmed (2 dumps: 2025-12-12 & 12-22) | 16029554884 |
| 9f-driver-power-state-ufs-rirr-reset-loop | **`0x9F` DRIVER_POWER_STATE_FAILURE** during **S4 resume / warm-reset** on a UFS-only system; `storufs` reset path (RESET LUN → RESET DEVICE → RESET BUS) looping every ~30s; event logs **500 (Unit Timeout)** + **550 (hierarchical reset)**; HCI completes commands (CNR set, doorbell cleared) but the **ISR is never invoked**. Mis-scoped-WA variants (don't confuse): `0x9F` with **IRP pending on `UcmUcsiAcpiClient` `\_SB.UBTC._DSM`** = a **different** USB-C/UCSI issue; `IOMMU_INTERRUPT_REMAPPING_FAULT (0x1fb)` / `pc:Ab04` = fallout of the all-IP (non-UFS-scoped) RIRR-read backport. | the OS-visible face of the **P2SB EOI-bypasses-MSI / IOAPIC-RIRR-stuck** bug: the UFS level-triggered interrupt line is wedged (register-dump `ioapic-rirr-stuck-ufs-is-clean`), so completions stop, StorPort unit-timeout fires, the reset cascade succeeds via polling but re-wedges immediately → loop → `0x9F`. **Not a UFS fault.** | confirmed | 16030172470 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* UFS-primary hang on PKGC. *What the dump showed:*
  `DPC_WATCHDOG_VIOLATION` (WIP) and `CLOCK_WATCHDOG_TIMEOUT` (memory dump captured, shared with MTC);
  DPC stack in the storufs reset path stalling >20s. *How it fit the RCA:* the OS-side symptom of the
  **fabric hang** — recovery (bus reset) can't complete because the controller core is stopped
  (see register-dump SBFES/HCFES), so the watchdog trips. Gap: minidump not attached to HSD.
- **16029554884 — UFS HLK Connected-Standby soft-hang.** *Issue:* SCSI unit-timeout + vendor
  endpoint-reset recovery gap (WCL-U, Win25H2). *Dump (GDHM 3235882136, captured 2025-12-12 over a
  connected debugger):* analyzed via **`BSOD0xE2-guide.md`** by interpreting the existing `!analyze -v`
  log (`Log.txt`) + the analyst's `!pnptriage`/`!irp`/`!devnode` notes (`comment.txt`) — the **dump file
  lives on the remote GDHM share** (`\\gkcv04a-cifs...\gdhm_dumps_fg001$\...\Memory.dmp`), not local, so we
  ran the *guide methodology over the existing kd output* rather than a fresh `Analyze-Dump.ps1` pass.
  (`kd.exe` v10.0.26100.4188 is installed and the toolkit is wired — `$KD_PATH` in the local clone fixed.) *What it showed:* **`BUGCHECK_CODE: 0`** (`ERROR_CODE 0x80000003` breakpoint) —
  a **forced dump of a HANG, not a real BSOD** (GDHM's “Bsod / 0x0_nt!SwapContext” label is the capture
  mechanism, per the 0xE2 principle). A System PnP device-action worker was blocked **~22.06s** in
  `storport!RaidBusEnumeratorIssueSynchronousRequest` (bus-rescan **INQUIRY**) with a pending
  `IRP_MJ_PNP/QUERY_DEVICE_RELATIONS` on `\Driver\storufs`; the storufs devnode (`PCI VEN_8086&DEV_4D47`)
  was stuck `DeviceNodeEnumeratePending` and **flapping** Started↔EnumerateCompletion↔EnumeratePending; a
  second thread piled up on the **registry lock** (`CmpLockRegistry`), plus many pending wait-wake S0/S4
  power IRPs. *How it fit the RCA:* this is the **enumeration-path** face of the same fault — a synchronous
  request to the UFS device hangs because the device/link won’t answer, wedging PnP and cascading to a
  whole-system hang; the devnode re-enum loop corroborates the repeated D0/D3 recovery behavior. It's the
  **earliest** capture (pre-dates the eng-driver-breakpoint SCSI-READ captures). Directly analogous to the
  0xE2 guide's **USB4 D-state ping-pong** (device bouncing D3→D0) + **PPM gate-stall** (worker wedged,
  others pile up) patterns.
  - **Second capture (2025-12-22) — same signature, reproducible.** Same enumeration-INQUIRY wedge (this
    time **~29.5s**; devnode started→enumerate-pending window **~7 min**). Two new facts: (1) at the hang the
    UFS devnode power state is **PowerDeviceD0** and `!storadapter` reports **Working** → **rules out
    power-gate/D3** — the device is *on* but won't answer the INQUIRY; (2) the freeze reaches the
    **filesystem** — an NTFS USN-journal worker (`Ntfs!NtfsCheckUsnTimeOutWorker → ExAcquireResourceExclusiveLite`)
    is blocked on an NTFS resource behind the wedged UFS enumeration. Confirms this is a **repeatable class**,
    not a one-off.
  - **Root-cause layer (from the same dumps' storport `!storloglist` + UIC log):** the recovery escalates
    `UnitTimeOut → RESET LUN/DEVICE[Error] → Bus reset`, and during Bus reset **`DME_LINKSTARTUP` fails with
    PHY `ErrorCode 0x10`** (M-PHY link won't re-init). That log layer belongs to **`driver-etl.md`** (storufs
    storport / UIC-M-PHY) — see it and sighting §5g; the trigger (a SCSI cmd with **no HW response ~10 s**)
    is the open HW-side root cause.
