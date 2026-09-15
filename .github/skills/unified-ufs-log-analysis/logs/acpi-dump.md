# Log Module — ACPI Dump

```yaml
log_type: acpi-dump
aka: [ACPI table dump, D0/D3 trace]
captures_layers: [OS, PMC]
analyzer_mcp: none
mcp_status: gap
schema_ready: no
time_base: os-uptime
provides_anchors: [D0/D3 transition, _PS0/_PS3 calls]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
OS power-management / device-state view — the `_PS0`/`_PS3` (D0/D3) traffic the OS drives to UFS.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** early, during OS-behavior characterization (before going to silicon).
- **HOW:** `TODO(wiki): ACPI dump capture procedure on failing boot.`
- **WHY:** shows the OS D0/D3 cadence into the hang (symptom-level context).

## 3. Analyzer — GAP (skill-guided)
No MCP. Read the D0/D3 transition traffic. `TODO(wiki): ACPI dump interpretation reference.`

## 4. Normalized output → common event schema
- `ts` ← OS uptime; `ts_base: os-uptime`; `layer: OS|PMC`. Events: `{type: "d3-entry"|"d0-exit"|"_PS3"}`.
- **Anchors it provides:** D0/D3 transitions / `_PS3` calls — align with VISA PkgC exit + BIOS knob state.

## 5. Healthy vs failing reference
- **Healthy:** D0/D3 traffic matches the configured cadence.
- **Fault:** abnormal **flood of D0/D3 calls** to UFS, then non-responsive (alternating `_PS3 UFS0` ↔
  `_PS0 UFS0 D0`). Symptom, **not** root cause.

## 6. BKM (best-known methods)
- Treat the D0/D3 flood as a **symptom** — don't anchor RCA on it (disabling PEP constraints didn't help).
- Use it to establish the OS cadence that opens the failing timing window (correlate with hibernate mode).

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| d0d3-flood-then-unresponsive | alternating `_PS3 UFS0`↔`_PS0 UFS0 D0` flood → UFS non-responsive | OS power cadence driving repeated UFS D-state churn around PKGC | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017.** *Issue:* UFS-primary PKGC hang. *What ACPI showed (evidence `Comment_3_second.png`):*
  a flood of D0/D3 calls, then UFS unresponsive. *How it fit the RCA:* a **symptom** of the OS D3/hibernate
  cadence; the real cause is the fabric timeout — ACPI framed *when* the OS pokes UFS around PKGC.
