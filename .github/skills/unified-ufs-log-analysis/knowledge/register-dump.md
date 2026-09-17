# Log Module — Register Dump (UFS host controller & PMC registers)

```yaml
log_type: register-dump
aka: [ITP register read, PythonSV register dump, HCI/UniPro/M-PHY/Device regs]
captures_layers: [HCI, UniPro, M-PHY, PMC]
analyzer_mcp: none
mcp_status: gap            # no MCP today — skill-guided decode (glossary + register spec)
schema_ready: no
time_base: n/a             # point-in-time snapshot, not a timeline; anchors other logs at the hang instant
provides_anchors: [IS_ SBFES set, IS_ HCFES set, PMC ufs pwr_sts, PKGC entry counters]
signature_count: 2
```

## 1. Identity — what it captures & which UFS layers it sees
A **point-in-time snapshot** of decisive UFSHCI + PMC registers at the failure instant. Not a timeline —
its value is the **state at the hang**, which anchors the other (time-series) logs.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** **at the hang, before ANY reset/recovery** (recovery clobbers these). Halt cores first if a
  watchdog reset is imminent.
- **HOW:** `TODO(wiki): ITP/PythonSV register-read procedure for UFS host controller & PMC.`
- **WHY:** the fatal `IS_` bits are the definitive confirmation of the fabric-timeout class.

## 3. Analyzer — GAP (skill-guided decode)
No MCP. Decode against `reference/ufs-glossary.md` → "`IS_` Interrupt Status — detailed decode"
(sourced from the SCC UFS register spec + MindShare training). Key registers:
- **`IS_` (offset 20h, RW/1C):** bit 17 **SBFES** (System Bus Fatal Error), bit 16 **HCFES** (Host
  Controller Fatal Error — sightings call it "HBFES"). Any fatal bit ⇒ core stops, run-stop regs cleared.
- **`UECPA/UECDL/UECN/UECT`** (UniPro error): may read **0 / unreadable under CATERROR**.
- **PMC** `...ip_pwr_sts_1.ufsx2_pwr_sts`, `...ip_pwr_sts_0.ufspw1_pwr_sts` → `0x1` = **not power-gated**.
- **PKGC entry counters** `pm_tools.cstate.get_pkgc_entry_counters()` → per-state counts.
- `TODO(wiki): full offset/field decode for UECPA/UECDL/UECN/UECT.`

## 4. Normalized output → common event schema
- No native `ts` — stamp with the **hang instant** (from the merge anchor) so it lands on the timeline.
- Emit one event per decisive bit: `{layer: HCI, type: "SBFES-set"|"HCFES-set", severity: fatal, decoded}`.
- **Anchors it provides:** `IS_ SBFES set` / `HCFES set` (align with VISA `int_sts` hang), PMC pwr_sts,
  PKGC counter state.

## 5. Healthy vs failing reference
- **Healthy:** `IS_` no fatal bits; UEC* readable/clean; PKGC counters advancing.
- **Fault:** **`IS_` SBFES + HCFES set**; UEC* unreadable/0 under CAT error; PMC pwr_sts `0x1` (UFS not
  gated); PKGC counters **frozen** (identical across two reads = system stuck).

## 6. BKM (best-known methods)
- Read **before** any reset — fatal bits + MCA are lost on power-cycle.
- Take **two consecutive reads** of PKGC counters — identical values prove "frozen/stuck" vs "still moving."
- Record `IS_` raw hex, not just bit names, so bit positions can be re-verified against the spec.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| is-sbfes-hcfes-fatal | `IS_` bits 17+16 set | OCP/system-bus fatal → core stopped, needs reset | confirmed | 16027585017 |
| pkgc-counters-frozen | C10_1 reached, C10_2/3=0, identical across 2 reads | system stuck at capture (not merely shallow) | confirmed | 16027585017 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* WCL UFS-primary hang when PKGC enabled.
  *What the register dump showed (evidence `Comment_3.png`):* `IS_` **SBFES + HCFES** set;
  PKGC counters **C10_1=532, C10_2=C10_3=0**, identical across two reads (frozen); `debug.mca.analyze()`
  came back **empty** in one capture. *How it fit the RCA:* the SBFES/HCFES pair is the definitive
  confirmation of the **OCP fabric timeout**; the frozen counters proved the system was stuck at PKGC10.1;
  empty-MCA proved MCA is *not mandatory* for this signature.
