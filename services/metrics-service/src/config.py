"""
Configuration settings for Metrics service
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Metrics service configuration"""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ClickHouse configuration (read-only)
    CLICKHOUSE_HOST: str = "clickhouse"
    CLICKHOUSE_PORT: int = 8123  # HTTP port for clickhouse-connect
    CLICKHOUSE_DB: str = "oasis"
    CLICKHOUSE_USER: str = "api_user"
    CLICKHOUSE_PASSWORD: str = "changeme"

    # PostgreSQL configuration
    POSTGRES_HOST: str = "postgresql"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "oasis"
    POSTGRES_USER: str = "api_user"
    POSTGRES_PASSWORD: str = "changeme"

    # Redis configuration
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_PASSWORD: str | None = None

    # Logging
    LOG_LEVEL: str = "INFO"

    # Cache TTLs (seconds)
    CACHE_TTL_SYSTEM_METRICS: int = 30  # System-wide metrics
    CACHE_TTL_TENANT_METRICS: int = 30  # Per-tenant metrics
    CACHE_TTL_AGENT_METRICS: int = 60  # Per-agent metrics

    @property
    def clickhouse_url(self) -> str:
        """Get ClickHouse connection URL"""
        return f"clickhouse://{self.CLICKHOUSE_USER}:{self.CLICKHOUSE_PASSWORD}@{self.CLICKHOUSE_HOST}:{self.CLICKHOUSE_PORT}/{self.CLICKHOUSE_DB}"

    @property
    def postgres_url(self) -> str:
        """Get PostgreSQL connection URL"""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    @property
    def redis_url(self) -> str:
        """Get Redis connection URL"""
        if self.REDIS_PASSWORD:
            return f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"


settings = Settings()
