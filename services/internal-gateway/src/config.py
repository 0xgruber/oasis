"""
Configuration settings for gateway service
"""

from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Gateway service configuration"""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Gateway identification
    GATEWAY_TYPE: Literal["external", "internal"] = "external"
    GATEWAY_NAME: str = "External Gateway"

    # PostgreSQL configuration
    POSTGRES_HOST: str = "postgresql"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "oasis"
    POSTGRES_USER: str = "gateway_user"
    POSTGRES_PASSWORD: str = "changeme"

    # Ingestion service configuration
    INGESTION_SERVICE_URL: str = "https://ingestion-service:8080"

    # mTLS configuration
    MTLS_CERT_PATH: str = "/certs/gateway.crt"
    MTLS_KEY_PATH: str = "/certs/gateway.key"
    MTLS_CA_PATH: str = "/certs/ca.crt"

    # Rate limiting defaults
    DEFAULT_RATE_LIMIT: int = 1000  # events per second
    RATE_LIMIT_WINDOW: int = 1  # seconds

    # Logging
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"

    # Request limits
    MAX_REQUEST_SIZE: int = 10 * 1024 * 1024  # 10MB
    MAX_BATCH_SIZE: int = 1000  # max events per batch

    @property
    def postgres_url(self) -> str:
        """Get PostgreSQL connection URL"""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"


settings = Settings()
