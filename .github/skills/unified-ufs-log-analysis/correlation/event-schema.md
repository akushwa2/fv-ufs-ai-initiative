# Common Event Schema (Layer-1 → Layer-2 normalization)

Every per-log analyzer (MCP or skill-guided) normalizes its output to this one event shape so the merge
layer can put all logs on a single timeline. **If a log can't be expressed as these events, it can't be
correlated** — extend the schema deliberately, don't fork it.

## Event
```json
{
  "source":   "visa|register-dump|bios-log|fth-trace|bsod-dump|driver-etl|solar|socwatch|cse-ese|axon",
  "ts":       "<number>",                // native timestamp value from the log
  "ts_base":  "visa-sample-clock|tsc|os-uptime|qpc|fth-cycle|wall-clock|socwatch-timestamp|n/a",
  "layer":    "HCI|UniPro|M-PHY|fabric|PMC|OS|BIOS",
  "type":     "<short-event-verb>",      // e.g. pkgc-exit, sbfes-set, d3-entry, dpc-watchdog-fire
  "severity": "info|warn|error|fatal",
  "raw":      "<verbatim log line / signal state>",
  "decoded":  "<human meaning + decoded value>"
}
```
- **`ts` + `ts_base`** — every log keeps its own clock; the merge layer maps them onto one timeline using
  anchors (see `anchor-catalog.md`). A snapshot log (register dump) has `ts_base: n/a` and is stamped at
  the hang instant.
- **`type`** — a controlled short verb so signatures/patterns can match on it.
- **`raw`** — keep verbatim for provenance; never lossy-summarize the evidence.

## Example — normalized instances from sighting 16027585017
```json
[
  {"source":"bios-log","ts":0,"ts_base":"tsc","layer":"OS","type":"d0d3-flood",
   "severity":"warn","raw":"_PS0 UFS0 D0 WA / _PS3 UFS0 x167/165","decoded":"UFS D-state churn around PKGC"},
  {"source":"visa","ts":19395.0,"ts_base":"visa-sample-clock","layer":"fabric","type":"pkgc-exit-wake",
   "severity":"warn","raw":"ufs_prim_clkreq=1, req_sa=1, PMCMCPPMFA_ps=0x4","decoded":"UFS upstream cycle forces PkgC exit"},
  {"source":"visa","ts":19395.804,"ts_base":"visa-sample-clock","layer":"HCI","type":"int_sts-read-hang",
   "severity":"fatal","raw":"prim_ism_agent_in stuck 0x3; int_sts read","decoded":"downstream int_sts read hung, 804.432us after wake"},
  {"source":"register-dump","ts":null,"ts_base":"n/a","layer":"HCI","type":"sbfes-set",
   "severity":"fatal","raw":"IS_ bit17=1 bit16=1","decoded":"SBFES+HCFES fatal: OCP fabric timeout, core stopped"},
  {"source":"fth-trace","ts":null,"ts_base":"fth-cycle","layer":"fabric","type":"nonposted-stuck",
   "severity":"fatal","raw":"last IS_ read stuck; PSF4->UFS non-posted read hung","decoded":"fabric hung on downstream read"},
  {"source":"bsod-dump","ts":null,"ts_base":"os-uptime","layer":"OS","type":"dpc-watchdog-fire",
   "severity":"fatal","raw":"UfsResetBus...StorPortStallExecution","decoded":"UFS bus reset >20s -> DPC_WATCHDOG"}
]
```

## Notes
- Analyzers should emit **structured** output already in this shape; skill-guided (manual) analysis
  produces the same events by hand.
- The merge MCP (when built) consumes a list of these per-source and returns one time-ordered list.
