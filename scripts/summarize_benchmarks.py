#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_INPUT = Path("docs/verification/benchmarks/results/chat-benchmarks.jsonl")


def load_records(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if not path.exists():
        return records
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records


def timing(record: dict[str, Any], key: str) -> str:
    value = (record.get("timings") or {}).get(key)
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.2f}"
    return str(value)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize recorded benchmark JSONL.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args()

    records = load_records(args.input)
    if not records:
        print(f"No benchmark records found: {args.input}")
        return 0

    rows = records[-args.limit :]
    print(
        f"{'STARTED':25} {'PRESET':16} {'LABEL':18} {'PROFILE':24} {'OK':3} "
        f"{'CTX':8} {'ELAPSED_MS':10} {'P_TOK/S':8} {'G_TOK/S':8} {'DRAFT':9}"
    )
    for record in rows:
        health = record.get("health") or {}
        data = ((health.get("upstream") or {}).get("data") or [{}])[0]
        meta = data.get("meta") or {}
        timings = record.get("timings") or {}
        draft = "-"
        if "draft_n" in timings:
            draft = f"{timings.get('draft_n_accepted', 0)}/{timings.get('draft_n', 0)}"
        print(
            f"{record.get('started_at', '-')[:25]:25} "
            f"{record.get('preset', '-')[:16]:16} "
            f"{record.get('label', '-')[:18]:18} "
            f"{record.get('profile', '-')[:24]:24} "
            f"{str(record.get('success', False)):3} "
            f"{str(meta.get('n_ctx', '-')):8} "
            f"{str(record.get('elapsed_ms', '-'))[:10]:10} "
            f"{timing(record, 'prompt_per_second')[:8]:8} "
            f"{timing(record, 'predicted_per_second')[:8]:8} "
            f"{draft:9}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
