# Log Module — BIOS Log

```yaml
log_type: bios-log
aka: [bioslog, serial BIOS log, boot log]
captures_layers: [BIOS, PMC]
analyzer_mcp: "intel-sandbox/val_mcp_tools .ai/BDC_CVE/fv-pm/MCP/Bioslog_MCP_release_v0.3.1/bioslog-analyzer-v2-0.3.1.vsix"
mcp_status: available
schema_ready: todo          # confirm the analyzer's output maps to the common event schema
time_base: tsc              # confirm: TSC / boot-relative
provides_anchors: [PkgC config/entry, S0ix enable, LTR programming, boot phase]
signature_count: 0
```

## 1. Identity — what it captures & which UFS layers it sees
The platform/BIOS boot + config log — knob state, PkgC/S0ix enablement, LTR programming, boot phase
timing. Establishes the **configuration context** for everything else (was PKGC on? what LTR was set?).

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** every run — capture across boot and the failing cycle.
- **HOW:** `TODO(wiki): BIOS/serial log capture procedure.`
- **WHY:** confirms the config that gates the bug (PKGC enabled, LTR value) and gives boot-phase anchors.

## 3. Analyzer — MCP (available)
**bioslog-analyzer-v2 (v0.3.1)** — install the `.vsix` from
`intel-sandbox/val_mcp_tools/.ai/BDC_CVE/fv-pm/MCP/Bioslog_MCP_release_v0.3.1/`.
`TODO(wiki): usage + confirm it emits structured events (phase, knob, timestamp).`

## 4. Normalized output → common event schema
- `ts` ← BIOS/TSC timestamp; `ts_base: tsc`; `layer: BIOS|PMC`.
- Events: `{type: "knob", decoded: "PKGC=on"}`, `{type: "ltr-program", decoded: "650us"}`, phase markers.
- **Anchors it provides:** `PkgC entry`, `S0ix enable`, `LTR programming` — align with VISA/register-dump.

## 5. Healthy vs failing reference
- **Healthy:** expected knob/LTR config; boot completes.
- **Fault:** config that enables the bug (PKGC/S0ix on, no/again LTR); or the mitigated config (LTR 650µs,
  ignore-on-D3). `TODO: capture concrete healthy-vs-fault log lines.`

## 6. BKM (best-known methods)
- Always keep the BIOS log with the log set — it's the cheapest source of the **config context** that the
  whole RCA hinges on (PKGC state, LTR value).
- Note the exact BIOS build string (e.g. `..._AUTO_LTR_0x8A8A_PS0_PS3_ignufsx2_debug_fix.rom`).

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| _(none yet)_ | | | | |

## 8. Examples with issue background (feedback loop)
- **16027585017 — config context.** The mitigation lived in BIOS (`AUTO_LTR ... ignufsx2`); the BIOS log
  is where you confirm PKGC/S0ix enablement and the LTR programming that turns the bug on/off. *(Add a
  concrete captured example when a BIOS log is provided for this case.)*
