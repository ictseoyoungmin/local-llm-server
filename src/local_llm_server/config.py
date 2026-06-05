from functools import lru_cache

from pydantic import AnyHttpUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    gateway_host: str = "0.0.0.0"
    gateway_port: int = 8000
    llama_upstream_base_url: AnyHttpUrl = "http://127.0.0.1:8080/v1"
    public_model_name: str = "local-llama"
    local_llm_api_key: str = "local-not-required"
    request_timeout_seconds: float = 600.0
    sanitize_llama_cpp_requests: bool = True

    @property
    def upstream_base_url(self) -> str:
        return str(self.llama_upstream_base_url).rstrip("/")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
