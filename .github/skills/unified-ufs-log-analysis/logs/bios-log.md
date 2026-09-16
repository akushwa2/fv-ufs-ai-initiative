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
signature_count: 1
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
  ignore-on-D3). **ACPI-side fault:** abnormal **flood of D0/D3 calls** to UFS (alternating `_PS3 UFS0` ↔
  `_PS0 UFS0 D0`), then UFS non-responsive — a **symptom**, not the root cause.

## 6. BKM (best-known methods)
- Always keep the BIOS log with the log set — it's the cheapest source of the **config context** that the
  whole RCA hinges on (PKGC state, LTR value).
- Note the exact BIOS build string (e.g. `..._AUTO_LTR_0x8A8A_PS0_PS3_ignufsx2_debug_fix.rom`).
- Treat the ACPI **D0/D3 flood as a symptom** — don't anchor RCA on it (disabling PEP constraints didn't help);
  use it to establish the OS power cadence that opens the failing timing window.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| d0d3-flood-then-unresponsive | ACPI: alternating `_PS3 UFS0`↔`_PS0 UFS0 D0` flood → UFS non-responsive | OS power cadence driving repeated UFS D-state churn around PKGC | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — config context + ACPI flood.** The mitigation lived in BIOS (`AUTO_LTR ... ignufsx2`);
  the BIOS log is where you confirm PKGC/S0ix enablement and the LTR programming that turns the bug on/off.
  The bundled **ACPI dump** (evidence `Comment_3_second.png`) showed a **flood of D0/D3 calls** then UFS
  unresponsive — a symptom of the OS D3/hibernate cadence; the real cause is the fabric timeout, but ACPI
  framed *when* the OS pokes UFS around PKGC.
