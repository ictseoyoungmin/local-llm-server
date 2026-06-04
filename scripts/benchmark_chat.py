#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_OUTPUT = Path("docs/verification/benchmarks/chat-benchmarks.jsonl")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def post_json(url: str, payload: dict[str, Any], api_key: str, timeout: float) -> dict[str, Any]:
    request = Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def get_json(url: str, timeout: float) -> dict[str, Any]:
    with urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def error_text(exc: BaseException) -> str:
    if isinstance(exc, HTTPError):
        try:
            body = exc.read().decode("utf-8", errors="replace")
        except Exception:
            body = ""
        return f"HTTP {exc.code}: {body}".strip()
    if isinstance(exc, URLError):
        return f"URL error: {exc.reason}"
    return str(exc)


def append_record(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True))
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run and record an OpenAI-compatible chat benchmark.")
    parser.add_argument("--base-url", default="http://127.0.0.1:18080/v1")
    parser.add_argument("--api-key", default="local-not-required")
    parser.add_argument("--model", default="qwen3.5-2b-mtp-ud-q4-k-xl")
    parser.add_argument("--profile", default="")
    parser.add_argument("--label", default="short-ready")
    parser.add_argument("--system", default="You are concise.")
    parser.add_argument("--prompt", default="Reply with: ready")
    parser.add_argument("--max-tokens", type=int, default=8)
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--timeout", type=float, default=240.0)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    started_at = utc_now()
    record: dict[str, Any] = {
        "started_at": started_at,
        "label": args.label,
        "profile": args.profile,
        "base_url": args.base_url,
        "model": args.model,
        "max_tokens": args.max_tokens,
        "temperature": args.temperature,
        "success": False,
    }

    try:
        health = get_json(f"{args.base_url.rstrip('/')}/health", timeout=10)
        record["health"] = health
    except Exception as exc:
        record["error"] = error_text(exc)
        record["finished_at"] = utc_now()
        append_record(args.output, record)
        print(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True))
        return 1

    payload = {
        "model": args.model,
        "messages": [
            {"role": "system", "content": args.system},
            {"role": "user", "content": args.prompt},
        ],
        "thinking": False,
        "chat_template_kwargs": {"enable_thinking": False},
        "temperature": args.temperature,
        "max_tokens": args.max_tokens,
    }

    start = time.monotonic()
    try:
        response = post_json(
            f"{args.base_url.rstrip('/')}/chat/completions",
            payload,
            api_key=args.api_key,
            timeout=args.timeout,
        )
        elapsed_ms = round((time.monotonic() - start) * 1000, 3)
        choice = (response.get("choices") or [{}])[0]
        message = choice.get("message") or {}
        record.update(
            {
                "success": True,
                "elapsed_ms": elapsed_ms,
                "finish_reason": choice.get("finish_reason"),
                "content": message.get("content", ""),
                "usage": response.get("usage"),
                "timings": response.get("timings"),
            }
        )
    except Exception as exc:
        record["elapsed_ms"] = round((time.monotonic() - start) * 1000, 3)
        record["error"] = error_text(exc)

    record["finished_at"] = utc_now()
    append_record(args.output, record)
    print(json.dumps(record, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if record["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
