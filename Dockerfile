FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY pyproject.toml README.md /app/
COPY src /app/src

RUN pip install --no-cache-dir .

CMD ["sh", "-c", "uvicorn local_llm_server.app:app --host ${GATEWAY_HOST:-0.0.0.0} --port ${GATEWAY_PORT:-8000}"]
