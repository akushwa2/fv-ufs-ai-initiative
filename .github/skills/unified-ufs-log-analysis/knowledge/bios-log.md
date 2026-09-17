# Log Module — BIOS Log (incl. ACPI / D0-D3)

```yaml
log_type: bios-log
aka: [bioslog, serial BIOS log, boot log, ACPI dump, D0/D3 trace]
captures_layers: [BIOS, PMC, OS]
analyzer_mcp: "intel-sandbox/val_mcp_tools .ai/BDC_CVE/fv-pm/MCP/Bioslog_MCP_release_v0.3.1/bioslog-analyzer-v2-0.3.1.vsix"
mcp_status: available
schema_ready: todo          # confirm the analyzer's output maps to the common event schema
time_base: tsc              # confirm: TSC / boot-relative
provides_anchors: [PkgC config/entry, S0ix enable, LTR programming, boot phase, D0/D3 transition, _PS0/_PS3]
signature_count: 3
```

## 1. Identity — what it captures & which UFS layers it sees
The platform/BIOS boot + config log — knob state, PkgC/S0ix enablement, LTR programming, boot phase
timing. Establishes the **configuration context** for everything else (was PKGC on? what LTR was set?).
**Includes the ACPI dump** (BIOS and ACPI dump are treated as one log here): the OS `_PS0`/`_PS3`
(D0/D3) traffic to UFS.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** every run — capture across boot and the failing cycle.
- **HOW:** `TODO(wiki): BIOS/serial log capture procedure.`
- **WHY:** confirms the config that gates the bug (PKGC enabled, LTR value) and gives boot-phase anchors.

## 3. Analyzer — MCP (available)
**bioslog-analyzer-v2 (v0.3.1)** — install the `.vsix` from
`intel-sandbox/val_mcp_tools/.ai/BDC_CVE/fv-pm/MCP/Bioslog_MCP_release_v0.3.1/`.
`TODO(wiki): usage + confirm it emits structured events (phase, knob, timestamp).`

## 4. Normalized output → common event schema
- `ts` ← BIOS/TSC timestamp; `ts_base: tsc`; `layer: BIOS|PMC|OS`.
- Events: `{type: "knob", decoded: "PKGC=on"}`, `{type: "ltr-program", decoded: "650us"}`, phase markers,
  and ACPI `{type: "d3-entry"|"d0-exit"|"_PS3"}`.
- **Anchors it provides:** `PkgC entry`, `S0ix enable`, `LTR programming`, `D0/D3 transition` — align with
  VISA PkgC exit + register-dump.

## 5. Healthy vs failing reference
- **Healthy:** expected knob/LTR config; boot completes; D0/D3 traffic matches the configured cadence.
- **Fault:** config that enables the bug (PKGC/S0ix on, no/again LTR); or the mitigated config (LTR 650µs,
  ignore-on-D3). **ACPI-side fault:** abnormal **flood of D0/D3 calls** to UFS, then UFS non-responsive — a
  **symptom**, not the root cause.
- **Concrete fault lines (from a real ACPI serial dump, 16027585017):** a tight repeating pair
  ```
  _PS0 UFS0 D0 WA
  _PS3 UFS0
  ```
  repeated **~165+ times** (that capture: **167 `_PS0 UFS0 D0`, 165 `_PS3 UFS0`**). The **`WA` suffix** on
  the D0 method = the **OCP-timeout-disable workaround runs inside UFS `_PS0()`** (so the WA only applies on
  the D0 entry — matches §8b exp #2: it doesn't help once PKGC is entered). Related lines: `Skip D3C entry? 0x0`,
  `_DSW D0 Wake Disable`, and PEP overrides `PEP default 0x3/0x5 → override 0x1` (legend in-log: `3 = D3`,
  `4 = Enable with D0`).

## 6. BKM (best-known methods)
- Always keep the BIOS log with the log set — it's the cheapest source of the **config context** that the
  whole RCA hinges on (PKGC state, LTR value).
- Note the exact BIOS build string (e.g. `..._AUTO_LTR_0x8A8A_PS0_PS3_ignufsx2_debug_fix.rom`).
- Treat the ACPI **D0/D3 flood as a symptom** — don't anchor RCA on it (disabling PEP constraints didn't help);
  use it to establish the OS power cadence that opens the failing timing window.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| d0d3-flood-then-unresponsive | ACPI: `_PS0 UFS0 D0 WA` ↔ `_PS3 UFS0` repeating ~165+× (167/165 in the capture) → UFS non-responsive | OS power cadence driving repeated UFS D-state churn around PKGC | confirmed | 16027585017 |
| ps0-carries-WA-tag | `_PS0 UFS0 D0 **WA**` | OCP-timeout-disable workaround executes in UFS `_PS0()` — applies only on D0 entry, not once PKGC is entered | confirmed | 16027585017 |
| pep-ufs-constraint-override | `PEP default 0x3/0x5 → override 0x1` (`3=D3`, `4=Enable with D0`) | platform PEP power constraints being overridden for UFS — disabling them did **not** fix the hang | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — config context + ACPI flood.** The mitigation lived in BIOS (`AUTO_LTR ... ignufsx2`);
  the BIOS log is where you confirm PKGC/S0ix enablement and the LTR programming that turns the bug on/off.
- **16027585017 — analyzed ACPI serial dump** (`ufs-log-inbox/16027585017/ACPI_Dump_UFS_D0_D3_Calls_after_booting_to_OS`).
  *Issue:* UFS-primary BSOD/hang on PKGC. *What the dump showed:* after boot to OS, a relentless
  `_PS0 UFS0 D0 WA` ↔ `_PS3 UFS0` oscillation — **167 D0 / 165 D3** UFS calls — i.e. the OS is churning UFS
  in and out of D3 continuously; the `WA` tag proves the OCP-timeout-disable workaround only runs on the D0
  method. PEP constraints for UFS were overridden (`→ 0x1`) yet the hang persisted. *How it fit the RCA:*
  confirmed the **D0/D3 flood is a symptom** of the OS D3/hibernate cadence (not the cause), and showed *why*
  the `_PS0`-only workaround is insufficient once PKGC is entered — pointing back to the LTR/fabric-timing fix.
