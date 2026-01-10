"""
Configuration settings for ingestion service
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Ingestion service configuration"""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ClickHouse configuration
    CLICKHOUSE_HOST: str = "clickhouse"
    CLICKHOUSE_PORT: int = 9000
    CLICKHOUSE_DB: str = "oasis"
    CLICKHOUSE_USER: str = "ingestion_user"
    CLICKHOUSE_PASSWORD: str = "changeme"

    # PostgreSQL configuration (for tenant lookup)
    POSTGRES_HOST: str = "postgresql"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "oasis"
    POSTGRES_USER: str = "ingestion_user"
    POSTGRES_PASSWORD: str = "changeme"

    # mTLS configuration
    MTLS_CERT_PATH: str = "/certs/ingestion.crt"
    MTLS_KEY_PATH: str = "/certs/ingestion.key"
    MTLS_CA_PATH: str = "/certs/ca.crt"

    # Batch processing
    BATCH_SIZE: int = 1000
    BATCH_TIMEOUT_SECONDS: int = 5

    # Logging
    LOG_LEVEL: str = "INFO"

    # Buffer limits
    MAX_BUFFER_SIZE: int = 10000  # Maximum logs in memory before back-pressure

    @property
    def clickhouse_url(self) -> str:
        """Get ClickHouse connection URL"""
        return f"clickhouse://{self.CLICKHOUSE_USER}:{self.CLICKHOUSE_PASSWORD}@{self.CLICKHOUSE_HOST}:{self.CLICKHOUSE_PORT}/{self.CLICKHOUSE_DB}"

    @property
    def postgres_url(self) -> str:
        """Get PostgreSQL connection URL"""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"


settings = Settings()
