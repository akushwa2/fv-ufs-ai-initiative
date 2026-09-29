# Controlled Taxonomy (enforced vocabulary)

To keep the database searchable, records MUST use these controlled values for the frontmatter fields.
If a new value is genuinely needed, **add it here first**, then use it — never invent free-text tags
inline (that silently fragments search).

## `ufs_layer` (where in the UFS stack)
- `application`
- `upiu`
- `utp-transport`
- `host-controller`
- `unipro`
- `m-phy`
- `interconnect-fabric`
- `power-mgmt`

## `failure_mode` (observable failure)
- `hang`
- `bsod`
- `mca`
- `timeout`
- `data-integrity`
- `link-error`
- `boot-fail`
- `perf`
(Combine with `|` if a sighting shows several, e.g., `hang|bsod|mca`.)

## `root_cause_class` (the true cause)
- `design-rtl`
- `firmware`
- `validation-content`
- `config-bios`
- `marginality`
- `tools`
- `environment`
- `spec-gap`          # device/vendor behavior differs from what the spec/OS flow expects (e.g. a UFS device's reaction to a standard command doesn't match the OS recovery flow's assumptions)
- `unknown`

## `signature` (canonical bug-class tag)
Format: `ufs-<mechanism>-<trigger>`, lowercase, hyphenated. Reuse an existing signature if the
mechanism matches — do NOT coin a near-duplicate.

Existing signatures:
- `ufs-fabric-timeout-on-pkgc` — OCP/Sonics fabric timeout during deep PKGC/S0ix entry because the
  UFS IP does not report LTR to PMC. (records: 16027585017)
- `ufs-fusepull-cdc-race-on-boot` — boot-time PMC-stuck-at-Phase3 waiting for UFS IP_ready, because a
  PGCB/CDC (clock-domain-crossing) race on IP-wake causes metastability that loses the IOSF2OCP-bridge
  fuse-pull request (fuse-pull stuck `001`). (records: 16029205689)
- `ufs-recovery-softhang-on-endpoint-reset` — after a SCSI READ unit-timeout (10s), the OS hierarchical/
  endpoint-reset recovery **soft-hangs** because the UFS device's reaction to `DME_ENDPOINTRESET` differs
  by vendor: a device that keeps the link **up** with `IS_` **clean** (`HCS.DP=1`) steers storufs onto a
  path that never HCE-toggles / re-inits the link, so recovery spins the UTRLDBR/UTRLCLR loop and hangs
  (a device that reports link-lost + `IS_.DFES` recovers). Distinct from `ufs-fabric-timeout-on-pkgc`:
  repros with **PKGC disabled** and the lost transaction is **above PSF0** with no fabric error.
  (records: 16029554884)

## `confidence` (per fact/field or record-level)
- `confirmed` — stated as fact in the ticket by the debug owner or a structured field.
- `inferred` — reasoned by the analyst from evidence; not explicitly stated.
- `agent-paraphrased` — summarized by the HSD text agent; not yet verified against the raw ticket.
- `unknown` — not retrievable.

## `linked_ids[].role`
- `origin` · `ip-debug` · `disposition` · `fix` · `prior-art` · `duplicate` · `look-alike-not-same`
