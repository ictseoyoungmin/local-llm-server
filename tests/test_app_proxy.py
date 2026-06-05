from __future__ import annotations

from fastapi import HTTPException
import pytest

import local_llm_server.app as app_module


class DummySettings:
    local_llm_api_key = "secret"
    public_model_name = "test-model"
    request_timeout_seconds = 1.0
    sanitize_llama_cpp_requests = True
    upstream_base_url = "http://upstream.test/v1"


def test_api_key_rejects_invalid_authorization(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())

    with pytest.raises(HTTPException) as exc_info:
        app_module._check_api_key("Bearer wrong")

    assert exc_info.value.status_code == 401


def test_api_key_allows_expected_authorization(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())

    app_module._check_api_key("Bearer secret")


@pytest.mark.parametrize(
    ("body", "expected"),
    [
        (b'{"stream": true}', True),
        (b'{"stream": false}', False),
        (b"not-json", False),
        ("{}".encode("utf-16"), False),
    ],
)
def test_stream_request_detection(body, expected):
    assert app_module._is_stream_request(body) is expected


def test_llama_cpp_sanitizer_removes_ollama_specific_fields(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())
    body = (
        b'{"model":"m","messages":[],"extra_body":{"options":{"num_ctx":200192}},'
        b'"options":{"num_ctx":200192},"num_ctx":200192,"stream":false}'
    )

    sanitized_body, removed = app_module._prepare_upstream_body("/chat/completions", body)

    assert removed == ["extra_body", "num_ctx", "options"]
    assert b"extra_body" not in sanitized_body
    assert b"options" not in sanitized_body
    assert b"num_ctx" not in sanitized_body
    assert b'"stream": false' in sanitized_body


def test_llama_cpp_sanitizer_preserves_tools(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())
    body = b'{"model":"m","messages":[],"tools":[{"type":"function"}],"tool_choice":"auto"}'

    sanitized_body, removed = app_module._prepare_upstream_body("/chat/completions", body)

    assert removed == []
    assert sanitized_body == body


def test_llama_cpp_sanitizer_can_be_disabled(monkeypatch):
    settings = DummySettings()
    settings.sanitize_llama_cpp_requests = False
    monkeypatch.setattr(app_module, "settings", settings)
    body = b'{"model":"m","messages":[],"options":{"num_ctx":200192}}'

    sanitized_body, removed = app_module._prepare_upstream_body("/chat/completions", body)

    assert removed == []
    assert sanitized_body == body


@pytest.mark.asyncio
async def test_health_reports_ok(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())

    async def fake_get_upstream_json(path):
        assert path == "/models"
        return 200, {"data": [{"id": "model.gguf"}]}

    monkeypatch.setattr(app_module, "_get_upstream_json", fake_get_upstream_json)

    response = await app_module.health()

    assert response["status"] == "ok"
    assert response["model_name"] == "test-model"
    assert response["upstream_status"] == 200


@pytest.mark.asyncio
async def test_health_reports_degraded(monkeypatch):
    monkeypatch.setattr(app_module, "settings", DummySettings())

    async def fake_get_upstream_json(path):
        assert path == "/models"
        return 503, {"detail": "unavailable"}

    monkeypatch.setattr(app_module, "_get_upstream_json", fake_get_upstream_json)

    response = await app_module.health()

    assert response["status"] == "degraded"
    assert response["upstream_status"] == 503
