# UFS Log Inbox — drop zone for log-set analysis

Put collected logs here so the **unified-ufs-log-analysis** skill can decode, correlate, and root-cause them.

## How to use
1. Create a folder per failure event: `ufs-log-inbox/<case-id>/`.
2. Drop each log in a typed sub-folder (`bsod/`, `visa/`, `fth/`, `bios/`, `regdump/`, `cse-ese/`, `driver-etl/`, ...).
3. Copy `_MANIFEST_TEMPLATE.yaml` → `<case-id>/manifest.yaml` and fill it in (issue context + `time_anchors`).
4. Tell the agent the **case-id**. It reads the manifest first (issue context), routes each log to its
   analyzer, merges on the anchors, and returns a ranked, evidence-backed root cause.

## Rules
- **Raw logs are local only** — everything under `<case-id>/` is gitignored and never committed (may be large/sensitive).
- Only the *derived* analysis (signatures, BKMs, examples) is written back into `logs/<type>.md` + the sighting record.
- `type` in the manifest must be a known `log_type` from `.github/skills/unified-ufs-log-analysis/logs/index.jsonl`.
  New log type? Add a `logs/<name>.md` module first.
- Logs are analyzed **with reference to the issue**, never standalone — always fill `sighting_id`/`symptom`/`context`.

_This README and `_MANIFEST_TEMPLATE.yaml` are tracked; the `<case-id>/` case folders are not._
