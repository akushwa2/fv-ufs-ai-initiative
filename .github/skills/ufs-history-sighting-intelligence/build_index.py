#!/usr/bin/env python3
"""Regenerate issues/index.jsonl from each record's YAML frontmatter.

Single source of truth = the record .md files. Run after adding/editing any record:
    python build_index.py

Reads the first ```yaml fenced block in each issues/*.md (except _TEMPLATE.md),
extracts the agent-queryable fields, and writes one JSON line per record.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import yaml  # PyYAML
except ImportError:
    sys.exit("PyYAML required:  python -m pip install pyyaml")

ISSUES = Path(__file__).parent / "issues"
INDEX = ISSUES / "index.jsonl"

# Fields copied verbatim into the index (agent join keys).
SCALARS = ["id", "signature", "ufs_layer", "failure_mode",
           "root_cause_class", "status"]
LISTS = ["programs", "key_registers"]

_YAML_BLOCK = re.compile(r"```yaml\s*\n(.*?)\n```", re.DOTALL)


def frontmatter(md: str) -> dict | None:
    m = _YAML_BLOCK.search(md)
    return yaml.safe_load(m.group(1)) if m else None


def row(fm: dict, record: str) -> dict:
    r = {k: fm.get(k) for k in SCALARS}
    for k in LISTS:
        r[k] = fm.get(k, [])
    # linked_ids: list of {id, role} -> list of ids
    r["linked_ids"] = [x.get("id") for x in fm.get("linked_ids", []) if isinstance(x, dict)]
    r["record"] = f"issues/{record}"
    return r


def main() -> int:
    rows, errors = [], []
    for md in sorted(ISSUES.glob("*.md")):
        if md.name == "_TEMPLATE.md":
            continue
        fm = frontmatter(md.read_text(encoding="utf-8"))
        if not fm or not fm.get("id"):
            errors.append(f"{md.name}: no yaml frontmatter / missing id")
            continue
        rows.append(row(fm, md.name))
    if errors:
        print("SKIPPED:\n  " + "\n  ".join(errors))
    INDEX.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")
    print(f"Wrote {INDEX.relative_to(Path(__file__).parent)} — {len(rows)} record(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
