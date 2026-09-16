# UFS Log Inbox — drop zone for log-set analysis

Put collected logs here so the **unified-ufs-log-analysis** skill can decode, correlate, and root-cause them.

## What YOU do (that's all)
1. Drop all logs for one failure into a folder: `ufs-log-inbox/<case-folder>/`
   (typed sub-folders like `bsod/ visa/ bios/` help but are optional — the agent infers types).
2. Ask the agent, with the sighting ticket id:

   > **“Analyze the UFS logs in `ufs-log-inbox/<case-folder>` for sighting `<HSD id>`.”**

   No sighting yet? Give the symptom instead — the agent asks at most one clarifying question.

**That's it. You never write a manifest.**

## What the AGENT does
- Discovers the files and **infers each log's type** from its name/extension/folder.
- Pulls the **issue context** (symptom, config, fingerprint, expected registers/signals) automatically
  from the sighting record `issues/<id>.md`.
- Derives the cross-log **time anchors** from the sighting fingerprint + what's in the logs.
- Generates `manifest.generated.yaml` in the case folder (a transparent record of what it did),
  runs decode → merge → correlate, and returns a ranked, evidence-backed root cause.
- Writes derived signatures/BKMs/examples back into `logs/<type>.md` (never the raw logs).

## Rules
- **Raw logs are local only** — everything under `<case-folder>/` is gitignored and never committed.
- Logs are analyzed **with reference to the issue**, never standalone.
- Unrecognized log type? The agent adds a `logs/<name>.md` module, then proceeds.

_This README and `_MANIFEST_TEMPLATE.yaml` (the schema the agent fills) are tracked; case folders
— raw logs + the generated manifest — are not._
