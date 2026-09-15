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
signature_count: 1
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

## 8. Examples with issue background (feedback loop)
- **16027585017 — UFS-primary BSOD on PKGC.** *Issue:* UFS-primary PKGC hang. *What FTH/PSF showed:*
  "nothing suspicious from IP except the last transaction to `IS_` is stuck"; HW analysis tied it to a
  **non-posted read stuck PSF4 → UFS**. *How it fit the RCA:* located the hang **on the fabric**, not the
  UFS link — the downstream `IS_` read that never returns after the upstream wake (matches VISA ~804µs).
