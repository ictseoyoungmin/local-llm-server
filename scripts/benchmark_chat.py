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

PROMPT_PRESETS: dict[str, dict[str, Any]] = {
    "short-ready": {
        "label": "short-ready",
        "system": "You are concise.",
        "prompt": "Reply with: ready",
        "max_tokens": 8,
    },
    "hermes-routing": {
        "label": "hermes-routing",
        "system": (
            "You are a local planning model used by an automation agent. "
            "Return concise, actionable Korean text."
        ),
        "prompt": (
            "다음 작업 요청을 로컬 에이전트가 실행 가능한 단계로 나눠라. "
            "목표: Hermes-agent가 local LLM endpoint를 안정적으로 사용하고, "
            "모델 프로파일 전환과 벤치마크 기록을 운영 절차에 포함한다. "
            "출력은 5개 항목의 번호 목록으로 작성하라."
        ),
        "max_tokens": 256,
    },
    "hermes-summary": {
        "label": "hermes-summary",
        "system": (
            "You summarize local LLM server verification logs for an engineering "
            "work queue. Be specific and compact."
        ),
        "prompt": (
            "Summarize this verification result and recommend the next benchmark: "
            "Qwen3.5-2B MTP UD-Q4_K_XL loaded with n_ctx=130048 on GTX 1660 6GB. "
            "MTP initialized with draft_n=6. A short cached smoke test returned "
            "ready quickly, but an earlier cold 2-token test showed high overhead. "
            "Mention what must be measured before changing Hermes-agent defaults."
        ),
        "max_tokens": 220,
    },
}


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


def apply_preset(args: argparse.Namespace) -> None:
    if args.preset == "custom":
        return
    preset = PROMPT_PRESETS[args.preset]
    if args.label == parser_default("label"):
        args.label = preset["label"]
    if args.system == parser_default("system"):
        args.system = preset["system"]
    if args.prompt == parser_default("prompt"):
        args.prompt = preset["prompt"]
    if args.max_tokens == parser_default("max_tokens"):
        args.max_tokens = int(preset["max_tokens"])


def parser_default(name: str) -> Any:
    defaults = {
        "label": "short-ready",
        "system": "You are concise.",
        "prompt": "Reply with: ready",
        "max_tokens": 8,
    }
    return defaults[name]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run and record an OpenAI-compatible chat benchmark.")
    parser.add_argument("--base-url", default="http://127.0.0.1:18080/v1")
    parser.add_argument("--api-key", default="local-not-required")
    parser.add_argument("--model", default="qwen3.5-2b-mtp-ud-q4-k-xl")
    parser.add_argument("--profile", default="")
    parser.add_argument(
        "--preset",
        choices=sorted([*PROMPT_PRESETS.keys(), "custom"]),
        default="short-ready",
        help="Benchmark prompt preset. Use custom with --system/--prompt.",
    )
    parser.add_argument("--label", default="short-ready")
    parser.add_argument("--system", default="You are concise.")
    parser.add_argument("--prompt", default="Reply with: ready")
    parser.add_argument("--max-tokens", type=int, default=8)
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--timeout", type=float, default=240.0)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    apply_preset(args)

    started_at = utc_now()
    record: dict[str, Any] = {
        "started_at": started_at,
        "label": args.label,
        "preset": args.preset,
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
