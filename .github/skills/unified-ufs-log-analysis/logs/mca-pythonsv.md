# Log Module — MCA decode (PythonSV machine-check)

```yaml
log_type: mca-pythonsv
aka: [MCA decode, debug.mca.analyze, machine check, THREE_STRIKE decode]
captures_layers: [HCI, fabric, PMC]
analyzer_mcp: PythonSV (debug.mca.analyze)
mcp_status: todo
schema_ready: no
time_base: n/a           # snapshot at CATERROR/three-strike
provides_anchors: [MCA bank log time, THREE_STRIKE, CATERROR]
signature_count: 1
```

## 1. Identity — what it captures & which UFS layers it sees
CPU **Machine Check Architecture** bank status — records the core/bank that took an unrecoverable error
(e.g., a stuck read). The CPU-side confirmation of a fabric hang.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** immediately after an **MCA/CATERROR/three-strike**, **BEFORE power-cycle** (banks lost on reset).
- **HOW:** `TODO(wiki): PythonSV env setup & connection.` Then `debug.mca.analyze()`; collect pysvlogs.
- **WHY:** identifies the failing bank/core and ties it to the stuck UFS transaction.

## 3. Analyzer — MCP (todo) / PythonSV
`debug.mca.analyze()`. `TODO(wiki): MCA bank decode reference + wrap as MCP emitting bank/core/status.`

## 4. Normalized output → common event schema
- `ts` ← stamp with the CATERROR/hang instant; `ts_base: n/a`; `layer: HCI|fabric`.
- Events: `{type: "mca-three-strike", decoded: "CORE2 MLC"}`.
- **Anchors it provides:** THREE_STRIKE / CATERROR instant — align with register-dump SBFES + FTH stall.

## 5. Healthy vs failing reference
- **Healthy:** no MCA logged.
- **Fault:** **THREE_STRIKE on a core bank** (e.g. CORE2 MLC) tied to a stuck non-posted read to UFS.
- **Nuance:** `debug.mca.analyze()` may return **empty** even in a failing PKGC-hang — MCA is **not
  mandatory** for the `ufs-fabric-timeout-on-pkgc` signature. Absence does not rule it out.

## 6. BKM (best-known methods)
- Decode **before** power-cycle — banks are gone on reset.
- Don't treat "no MCA" as "not this bug" — cross-check register-dump `IS_` and FTH instead.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| three-strike-core-mlc-on-ufs-read | THREE_STRIKE CORE2 MLC, stuck non-posted read to UFS | core gave up on a read hung in the fabric | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* UFS-primary PKGC hang. *What MCA showed:*
  THREE_STRIKE on **CORE2 MLC** with a non-posted read stuck PSF4→UFS — but in one capture
  `debug.mca.analyze()` came back **empty**. *How it fit the RCA:* CPU-side confirmation of the fabric
  hang when present; the empty case taught us MCA is optional for this signature (rely on `IS_`/FTH/VISA).
