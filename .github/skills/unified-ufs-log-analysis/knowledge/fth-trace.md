# Log Module — FTH Trace (Fabric / PSF transaction trace)

```yaml
log_type: fth-trace
aka: [FTH capture, PSF trace, Primary Scalable Fabric trace, FTH-for-PSF]
captures_layers: [fabric]
analyzer_mcp: <mcp?>          # TODO confirm FTH/PSF decoder MCP
mcp_status: todo
schema_ready: no
time_base: fth-cycle
provides_anchors: [last outstanding transaction, PSF4->UFS stall, IS_ read on fabric]
signature_count: 3
```

## 1. Identity — what it captures & which UFS layers it sees
On-die **fabric transaction trace** — the requests/completions crossing the PSF/OCP fabric to/from UFS.
FTH is the capture vehicle; the PSF transactions are the payload ("FTH captures we have gotten for PSF
transactions"). Shows **where a transaction stalled**.

## 2. Capture — WHEN / HOW / WHY
- **WHEN:** **arm BEFORE** triggering the repro (fabric/power-state bug suspected). Useless if armed
  after the hang — must capture the failing signature at the stall.
- **HOW:** `TODO(wiki): FTH/PSF trace arm & capture procedure + tool invocation.` Arm on the failing
  signature; run the boot/sleep-wake cycle; save with the failing cycle ID.
- **WHY:** isolates the stuck transaction (which agent, which direction).

## 3. Analyzer — MCP (todo)
`TODO(wiki): FTH/PSF transaction decoder MCP / reference.` Decode to find the **last outstanding
transaction** and where it stalled (e.g., **PSF4 → UFS**).

## 4. Normalized output → common event schema
- `ts` ← FTH cycle/timestamp; `ts_base: fth-cycle`; `layer: fabric`.
- Events per transaction: `{type: "txn", decoded: "<src>-><dst> <posted|non-posted> <complete|stuck>"}`.
- **Anchors it provides:** the stuck-transaction instant / `IS_` fabric access — align with VISA `int_sts`
  hang and register-dump SBFES.

## 5. Healthy vs failing reference
- **Healthy:** transactions complete with matching completions.
- **Fault:** last transaction to `IS_` **stuck / no completion**; downstream **non-posted read PSF4 → UFS
  hung**. (Upstream posted write has no completion by design — do not mistake for the stall.)

## 6. BKM (best-known methods)
- Arm on the failing signature ahead of time; label the capture with the exact failing cycle ID.
- Distinguish **posted** (no completion expected) from **non-posted** (completion expected) before calling
  a transaction "stuck" — only a hung non-posted read is the fingerprint.
- Pair with VISA: FTH says *which* transaction stalled; VISA says *when* relative to PkgC exit.

## 7. Known signatures (learning loop)
| Signature | Appearance in this log | Means | Confidence | Sighting IDs |
|-----------|------------------------|-------|-----------|--------------|
| psf4-to-ufs-nonposted-stuck | last `IS_` read stuck; non-posted read PSF4→UFS hung | fabric hung after UFS upstream wake → downstream read never completes | confirmed | 16027585017 |
| utrldbr-utrlclr-recovery-spin-plus-illegal-dme_enable | good→bad transition: last-good `DBR Cleared` entry, then a **~10 s dead gap** (nothing on the UFS interface), then a loop of repeated `MWr UTRLCLR (off 0x5C)` + `MRd UTRLDBR (off 0x58)` (`DBR Cleared-N` incrementing); **later** in the trace, `UICCMD` written `0x39` = **`DME_ENABLE`**, which the IP databook marks **not permitted** | the ~10 s gap **is** the SCSI unit-timeout (command never reached UFS); the UTRLDBR/UTRLCLR loop **is** the OS recovery spinning (clear+re-poll doorbell) while the link is stuck; the later illegal `DME_ENABLE` is a protocol smell in the recovery path, not the trigger | fth-snap | 16029554884 |
| p2sb-startcpl-to-cpldone-gt-5us | a completion whose **StartCpl→CplDone duration exceeds ~5 µs** (the recommended FTH trigger for this class); around it, the UFS ISR sequence (Read `UTRLDBR` off `0x58` → write doorbell → UFS uplink MRd64/MWr64 → **MSI from `rte_25` IOAPIC** `P2SB[0x11B0]` → read `IS`/`IE` → clear `IS.utrcs` → **EOI vec `0x81` @ `0xFEC00040`**) is **truncated**: the failing iteration shows only a ~0.4 s window (vs ~10 s good E2E), **multiple `UTRLDBR` writes before UTP completion**, and an **EOI issued without clearing `IS` first** | the stretched P2SB completion latency is the observable of the **posted-vs-non-posted contention** that lets the EOI beat the MSI completion; the truncated/!cleared-IS ISR corroborates the interrupt line wedging. Pair with VISA `servicePCmdValid[3]/[0]` for the ordering proof, and register-dump `rte_line_25` for the stuck RIRR | fth-snap / confirmed | 16030172470 |

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* UFS-primary PKGC hang. *What FTH/PSF showed:*
  "nothing suspicious from IP except the last transaction to `IS_` is stuck"; HW analysis tied it to a
  **non-posted read stuck PSF4 → UFS**. *How it fit the RCA:* located the hang **on the fabric**, not the
  UFS link — the downstream `IS_` read that never returns after the upstream wake (matches VISA ~804µs).
- **16029554884 — UFS HLK Connected-Standby soft-hang.** *Issue:* SCSI unit-timeout + vendor
  endpoint-reset recovery gap (WCL-U, Win25H2). *What FTH showed (comment `1667223638`):* a clean
  last-good boundary (`DBR Cleared-11440 → All Cmds Served Successfully`), then `CHK_BAD : Loop Starts
  Here` with a **~10 s dead gap** between entries (matches the SCSI 10 s unit-timeout exactly — nothing
  on the UFS interface during that window); the OS then spins `UTRLCLR`(0x5C)/`UTRLDBR`(0x58) in a loop
  (`DBR Cleared-11441/11442/11443...`) — the recovery polling the doorbell against a link that never came
  back. A later trace entry shows `UICCMD` written `0x39` (`DME_ENABLE`), which the IP databook says is
  **not permitted** during recovery — a protocol smell, occurring after the main loop, not the cause of it.
  *How it fit the RCA:* the dead-gap duration pins the trigger as a config-driven **unit-timeout** (fixed
  via UFS `FeatureFlags` doorbell-completion default, sibling ticket `15019125953`), while the
  UTRLDBR/UTRLCLR spin is the **visible signature of Issue #2** (recovery failing to re-init the link on
  SK hynix). *Gap:* PMC user-mode-data register writes (`0x15B0–0x15B5`) also appear in the trace —
  provenance queried, no Intel recommendation known yet (`[gap]`).
- **16030172470 — UFS-primary 0x9F (P2SB EOI bypasses MSI completion).** *Issue:* WCL/PTL UFS-only 0x9F on
  S4-resume/warm-reset. *What FTH/PSF-OBS showed (comments `1363666535`/`1363666691` snapshots):* the
  recommended trigger was **StartCpl→CplDone > 5 µs** (stretched P2SB completion). The **last successful**
  ISR takes ~10 s E2E: Read `UTRLDBR`(0x58) → write doorbell (`0x8000000`) → UFS uplink MRd64/MWr64 →
  **MSI from `rte_25` IOAPIC** (`P2SB[0x11B0]`) → read `IS`/`IE` → clear `IS.utrcs` → **EOI vec `0x81` @
  `0xFEC00040`** (UFS MMIO base `0x8013BE80xx`). The **failing** iteration collapses to a ~0.4 s window with
  **multiple `UTRLDBR` writes before UTP completion** and an **EOI issued without clearing `IS` first**.
  *How it fit the RCA:* the stretched completion latency is the FTH-visible observable of the posted-vs-
  non-posted contention; combined with VISA (`servicePCmdValid[3]/[0]`) and register-dump (`rte_line_25`
  RIRR stuck), it pins the EOI-beats-MSI-completion ordering. *Gap:* StartCpl/CplDone exact timestamps
  read from the snapshots, not a machine-parsed FTH export.
