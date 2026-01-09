"""
Database connection and API key validation
"""

from typing import Optional
from datetime import datetime

import asyncpg
import bcrypt
import structlog

from src.config import settings

logger = structlog.get_logger()


class DatabasePool:
    """PostgreSQL connection pool manager"""

    def __init__(self) -> None:
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self) -> None:
        """Create connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                host=settings.POSTGRES_HOST,
                port=settings.POSTGRES_PORT,
                database=settings.POSTGRES_DB,
                user=settings.POSTGRES_USER,
                password=settings.POSTGRES_PASSWORD,
                min_size=2,
                max_size=10,
                command_timeout=60,
            )
            logger.info("database_pool_created", host=settings.POSTGRES_HOST)
        except Exception as e:
            logger.error("database_pool_creation_failed", error=str(e))
            raise

    async def disconnect(self) -> None:
        """Close connection pool"""
        if self.pool:
            await self.pool.close()
            logger.info("database_pool_closed")

    async def validate_api_key(self, api_key: str) -> Optional[dict]:
        """
        Validate API key and return tenant information

        Args:
            api_key: API key from request header

        Returns:
            Tenant info dict if valid, None if invalid
        """
        if not self.pool:
            logger.error("database_pool_not_initialized")
            return None

        try:
            # Extract key prefix (first 8 chars)
            key_prefix = api_key[:8] if len(api_key) >= 8 else None
            if not key_prefix:
                return None

            async with self.pool.acquire() as conn:
                # Get API key record
                row = await conn.fetchrow(
                    """
                    SELECT 
                        ak.id as api_key_id,
                        ak.key_hash,
                        ak.tenant_id,
                        ak.is_active as key_active,
                        t.name as tenant_name,
                        t.eps_limit,
                        t.retention_days,
                        t.is_active as tenant_active
                    FROM api_keys ak
                    JOIN tenants t ON ak.tenant_id = t.id
                    WHERE ak.key_prefix = $1
                        AND ak.is_active = true
                        AND t.is_active = true
                        AND (ak.expires_at IS NULL OR ak.expires_at > NOW())
                    """,
                    key_prefix,
                )

                if not row:
                    logger.warning(
                        "api_key_not_found",
                        key_prefix=key_prefix,
                    )
                    return None

                # Verify hash
                key_hash = row["key_hash"]
                if not bcrypt.checkpw(api_key.encode(), key_hash.encode()):
                    logger.warning(
                        "api_key_hash_mismatch",
                        key_prefix=key_prefix,
                        tenant_id=str(row["tenant_id"]),
                    )
                    return None

                # Update last_used_at
                await conn.execute(
                    "UPDATE api_keys SET last_used_at = NOW() WHERE id = $1",
                    row["api_key_id"],
                )

                logger.info(
                    "api_key_validated",
                    tenant_id=str(row["tenant_id"]),
                    tenant_name=row["tenant_name"],
                )

                return {
                    "tenant_id": str(row["tenant_id"]),
                    "tenant_name": row["tenant_name"],
                    "eps_limit": row["eps_limit"],
                    "retention_days": row["retention_days"],
                }

        except Exception as e:
            logger.error("api_key_validation_error", error=str(e))
            return None


# Global database pool instance
db_pool = DatabasePool()
