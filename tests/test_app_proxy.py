from __future__ import annotations

from fastapi import HTTPException
import pytest

import local_llm_server.app as app_module


class DummySettings:
    local_llm_api_key = "secret"
    public_model_name = "test-model"
    request_timeout_seconds = 1.0
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
