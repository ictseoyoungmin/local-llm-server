from __future__ import annotations

import importlib

from scripts import benchmark_chat


def test_benchmark_defaults_follow_openai_env(monkeypatch):
    monkeypatch.setenv("OPENAI_BASE_URL", "http://example.test/v1")
    monkeypatch.setenv("OPENAI_API_KEY", "env-key")
    monkeypatch.setenv("OPENAI_MODEL", "env-model")

    importlib.reload(benchmark_chat)
    args = benchmark_chat.parse_args([])

    assert args.base_url == "http://example.test/v1"
    assert args.api_key == "env-key"
    assert args.model == "env-model"


def test_preset_does_not_override_explicit_label():
    args = benchmark_chat.parse_args(["--preset", "hermes-routing", "--label", "short-ready"])

    assert args.label == "short-ready"
    assert args.max_tokens == 256
    assert "Hermes-agent" in args.prompt


def test_custom_preset_uses_fallbacks():
    args = benchmark_chat.parse_args(["--preset", "custom"])

    assert args.label == "custom"
    assert args.system == "You are concise."
    assert args.prompt == "Reply with: ready"
    assert args.max_tokens == 8
