#!/usr/bin/env python3
"""Regenerate knowledge/index.jsonl from each knowledge/<name>.md module's YAML frontmatter.

The module frontmatter (first ```yaml ... ``` block) is the single source of truth.
Run after adding or editing a log module:  python build_index.py
"""
import json
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required:  python -m pip install pyyaml")

LOGS = pathlib.Path(__file__).parent / "knowledge"
FIELDS = ["log_type", "analyzer_mcp", "mcp_status", "captures_layers", "signature_count"]
YAML_BLOCK = re.compile(r"```yaml\s*\n(.*?)```", re.DOTALL)


def main() -> None:
    rows = []
    for md in sorted(LOGS.glob("*.md")):
        if md.name == "_TEMPLATE.md":
            continue
        m = YAML_BLOCK.search(md.read_text(encoding="utf-8"))
        if not m:
            print(f"WARN: no frontmatter in {md.name}", file=sys.stderr)
            continue
        fm = yaml.safe_load(m.group(1)) or {}
        if "log_type" not in fm:
            print(f"WARN: no log_type in {md.name}", file=sys.stderr)
            continue
        row = {k: fm.get(k) for k in FIELDS}
        row["module"] = f"knowledge/{md.name}"
        rows.append(row)

    out = LOGS / "index.jsonl"
    out.write_text("\n".join(json.dumps(r) for r in rows) + "\n", encoding="utf-8")
    print(f"Wrote {out} — {len(rows)} module(s)")


if __name__ == "__main__":
    main()
