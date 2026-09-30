# Log Module — Driver ETL (Windows storufs ETW trace)

```yaml
log_type: driver-etl
aka: [ETW trace, storufs ETL, storport trace]
captures_layers: [OS]
analyzer_mcp: <WPA / xperf>
mcp_status: todo
schema_ready: no
time_base: qpc
provides_anchors: [D3 entry, hibernate call, reset start, _PS3, UnitTimeOut, RESET LUN/DEVICE/BUS, DME_LINKSTARTUP]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
Windows **ETW/ETL** trace of the storufs/storport driver — the OS driver's timed view of D-state,
hibernate, and reset activity. Bridges ACPI (what) and BSOD (crash) with **timestamps**.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** across the failing cycle (boot + sleep-wake).
- **HOW:** `TODO(wiki): ETW/xperf capture for storufs (providers + session).`
- **WHY:** gives a **timestamped** OS-side sequence for correlation (SW hibernate → `_PS3` → reset).

## 3. Analyzer — MCP (todo)
`TODO(wiki): WPA/xperf-based ETL decoder MCP; emit driver events with QPC timestamps.`

## 4. Normalized output → common event schema
- `ts` ← QPC; `ts_base: qpc`; `layer: OS`. Events: `{type: "d3-entry"|"sw-hibernate"|"reset-start"}`.
- **Anchors it provides:** SW-hibernate/`_PS3`/reset timing — align with ACPI D0/D3 and BSOD DPC fire.

## 5. Healthy vs failing reference
- **Healthy:** D3/hibernate/reset sequence completes; SCSI commands complete (HW responds within ~1 ms).
- **Fault (data-path recovery):** `!storloglist` (storport RaidLogList, extractable from a kernel dump) shows
  the hierarchical-reset escalation: **`UnitTimeOut`** (no HW response ~10 s) → **`RESET LUN [Error]`** →
  **`RESET DEVICE [Error]`** → `PauseAdapter (Timeout 30)` → **`Bus reset`**; the aborted SRB is a
  **`SCSI READ(10)`** (or, on the enumeration path, a **`SCSI INQUIRY`**).
- **Fault (M-PHY link re-init):** during **Bus Reset** the UIC command trace shows `DME_SET`→Success, then
  **`DME_LINKSTARTUP` fails repeatedly with `[HW Error][PHY][ErrorCode = 0x10]`** and **`DME_ENDPOINTRESET`
  fails** — the M-PHY/UniPro link won't re-init (`IS=0x45724877` at the failure). This is the concrete reason
  recovery / re-enumeration stalls (cross-ref `register-dump.md` for IS_/PHY-error decode).

## 6. BKM (best-known methods)
- The ETL is the best place to see **OS hibernate cadence** (SW-H8 vs AH8) that decides whether the
  failing timing window opens — pair with the hibernate-mode analysis.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| storufs-hierarchical-reset->dme-linkstartup-phy-fail | `!storloglist`: `UnitTimeOut` → `RESET LUN[Error]` → `RESET DEVICE[Error]` → `Bus reset`; aborted SRB = `SCSI READ(10)` / `INQUIRY`. UIC trace during Bus reset: `DME_LINKSTARTUP` ×N → `[HW Error][PHY][ErrorCode 0x10]`; `DME_ENDPOINTRESET` → Failure | UFS gives **no response for ~10 s** → OS runs hierarchical reset; during Bus reset the **M-PHY `DME_LINKSTARTUP` fails (PHY err 0x10)** so the link won't re-init → recovery/enumeration stalls. Trigger (the ~10 s no-response) is a **HW-side** issue, still open. | confirmed | 16029554884 |

## 8. Examples with issue background (feedback loop)
- **16029554884 — UFS HLK Connected-Standby soft-hang.** From the eng-driver-breakpoint dumps on the
  **promoted IP-debug ticket 16029462685** (owner nithyapr): the storufs `!storloglist` shows a
  `SCSI READ(10)` / `INQUIRY` getting **no HW response for ~10 s** → `UnitTimeOut` → hierarchical reset
  (`RESET LUN`/`RESET DEVICE` both `Error` → `Bus reset`). During Bus reset the UIC command trace shows
  **`DME_LINKSTARTUP` failing 5× with `[PHY][ErrorCode 0x10]`** and **`DME_ENDPOINTRESET` failing** → the
  M-PHY link won't re-init. Analyst conclusion: *“This is not a bugcheck… the reason behind the OS reset is
  no response for a SCSI command for ~10 second, so we have to check from **HW side** why it hung…
  breakpoint hit **6 times**, pattern same → the underlying issue is there in the normal case and
  **recovering without our notice**.”* The ~10 s no-response (Issue #1) is the open HW root cause; the failed
  M-PHY re-init is why recovery stalls (Issue #2). Dump: GDHM 3235882136 / `\\amr.corp.intel.com\wos\EXT\Friday\16029462685`.
- _(SW-H8 vs AH8 hibernate-cadence example for 16027585017 still to add.)_
