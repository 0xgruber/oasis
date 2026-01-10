"""
Configuration settings for API service
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """API service configuration"""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ClickHouse configuration (read-only)
    CLICKHOUSE_HOST: str = "clickhouse"
    CLICKHOUSE_PORT: int = 9000
    CLICKHOUSE_DB: str = "oasis"
    CLICKHOUSE_USER: str = "api_user"
    CLICKHOUSE_PASSWORD: str = "changeme"

    # PostgreSQL configuration
    POSTGRES_HOST: str = "postgresql"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "oasis"
    POSTGRES_USER: str = "api_user"
    POSTGRES_PASSWORD: str = "changeme"

    # JWT configuration
    JWT_SECRET: str = "changeme-generate-secure-secret"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 60

    # TOTP configuration
    TOTP_ISSUER: str = "O.A.S.I.S."

    # Logging
    LOG_LEVEL: str = "INFO"

    # Query limits
    MAX_QUERY_LIMIT: int = 10000  # Maximum rows per query
    DEFAULT_QUERY_LIMIT: int = 100  # Default rows per query

    @property
    def clickhouse_url(self) -> str:
        """Get ClickHouse connection URL"""
        return f"clickhouse://{self.CLICKHOUSE_USER}:{self.CLICKHOUSE_PASSWORD}@{self.CLICKHOUSE_HOST}:{self.CLICKHOUSE_PORT}/{self.CLICKHOUSE_DB}"

    @property
    def postgres_url(self) -> str:
        """Get PostgreSQL connection URL"""
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"


settings = Settings()
