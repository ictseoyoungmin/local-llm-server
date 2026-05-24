from __future__ import annotations

from collections.abc import AsyncIterator
import json
from typing import Any

import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse

from .config import get_settings


settings = get_settings()
app = FastAPI(title="Local LLM Server", version="0.1.0")


def _check_api_key(authorization: str | None) -> None:
    if settings.local_llm_api_key in {"", "local-not-required"}:
        return

    expected = f"Bearer {settings.local_llm_api_key}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Invalid API key")


def _upstream_headers(request: Request) -> dict[str, str]:
    headers: dict[str, str] = {"Content-Type": "application/json"}
    authorization = request.headers.get("authorization")
    if authorization:
        headers["Authorization"] = authorization
    return headers


def _is_stream_request(body: bytes) -> bool:
    try:
        payload = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return False
    return isinstance(payload, dict) and payload.get("stream") is True


def _upstream_url(path: str, request: Request | None = None) -> str:
    url = f"{settings.upstream_base_url}{path}"
    if request is not None and request.url.query:
        url = f"{url}?{request.url.query}"
    return url


async def _get_upstream_json(path: str, request: Request | None = None) -> tuple[int, dict[str, Any]]:
    timeout = httpx.Timeout(settings.request_timeout_seconds)
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.get(_upstream_url(path, request))
    try:
        payload = response.json()
    except ValueError:
        payload = {"detail": response.text}
    return response.status_code, payload


@app.get("/health")
async def health() -> dict[str, Any]:
    upstream_status, upstream_payload = await _get_upstream_json("/models")
    return {
        "status": "ok" if upstream_status == 200 else "degraded",
        "platform": "local-llm-server",
        "model_name": settings.public_model_name,
        "upstream_base_url": settings.upstream_base_url,
        "upstream_status": upstream_status,
        "upstream": upstream_payload,
    }


@app.get("/v1/health")
async def v1_health() -> dict[str, Any]:
    return await health()


@app.api_route("/v1/{path:path}", methods=["GET", "POST"])
async def proxy_v1(
    path: str,
    request: Request,
    authorization: str | None = Header(default=None),
):
    _check_api_key(authorization)

    upstream_path = f"/{path}"
    timeout = httpx.Timeout(settings.request_timeout_seconds)

    if request.method == "GET":
        status_code, payload = await _get_upstream_json(upstream_path, request)
        return JSONResponse(status_code=status_code, content=payload)

    body = await request.body()
    if _is_stream_request(body):
        return StreamingResponse(
            _stream_upstream(upstream_path, body, request),
            media_type="text/event-stream",
        )

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            _upstream_url(upstream_path, request),
            content=body,
            headers=_upstream_headers(request),
        )

    try:
        payload = response.json()
    except ValueError:
        payload = {"detail": response.text}
    return JSONResponse(status_code=response.status_code, content=payload)


async def _stream_upstream(path: str, body: bytes, request: Request) -> AsyncIterator[bytes]:
    timeout = httpx.Timeout(settings.request_timeout_seconds)
    async with httpx.AsyncClient(timeout=timeout) as client:
        async with client.stream(
            "POST",
            _upstream_url(path, request),
            content=body,
            headers=_upstream_headers(request),
        ) as response:
            if response.status_code >= 400:
                error_body = await response.aread()
                yield error_body
                return
            async for chunk in response.aiter_bytes():
                yield chunk
