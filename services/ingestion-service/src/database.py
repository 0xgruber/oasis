"""
PostgreSQL database connection and queries for ingestion service
"""

import asyncpg
import structlog
from typing import Optional

from src.config import settings

logger = structlog.get_logger()


class DatabasePool:
    """PostgreSQL connection pool manager"""

    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self) -> None:
        """Initialize connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                host=settings.POSTGRES_HOST,
                port=settings.POSTGRES_PORT,
                database=settings.POSTGRES_DB,
                user=settings.POSTGRES_USER,
                password=settings.POSTGRES_PASSWORD,
                min_size=2,
                max_size=10,
                command_timeout=30.0,
            )
            logger.info(
                "postgres_pool_created",
                host=settings.POSTGRES_HOST,
                database=settings.POSTGRES_DB,
            )
        except Exception as e:
            logger.error("postgres_pool_creation_failed", error=str(e))
            raise

    async def disconnect(self) -> None:
        """Close connection pool"""
        if self.pool:
            await self.pool.close()
            logger.info("postgres_pool_closed")

    async def update_agent_heartbeat(self, tenant_id: str, hostname: str) -> bool:
        """
        Update agent's last_seen timestamp

        Args:
            tenant_id: Tenant UUID
            hostname: Agent hostname

        Returns:
            True if updated, False if agent not found
        """
        if not self.pool:
            logger.warning("postgres_pool_not_initialized")
            return False

        try:
            async with self.pool.acquire() as conn:
                result = await conn.execute(
                    """
                    UPDATE agents
                    SET last_seen = NOW(), is_active = true
                    WHERE tenant_id = $1 AND hostname = $2
                    """,
                    tenant_id,
                    hostname,
                )

                # Check if any rows were updated
                rows_affected = int(result.split()[-1])
                if rows_affected > 0:
                    logger.debug(
                        "agent_heartbeat_updated",
                        tenant_id=tenant_id,
                        hostname=hostname,
                    )
                    return True
                else:
                    logger.debug(
                        "agent_not_found_for_heartbeat",
                        tenant_id=tenant_id,
                        hostname=hostname,
                    )
                    return False

        except Exception as e:
            logger.error(
                "agent_heartbeat_update_failed",
                tenant_id=tenant_id,
                hostname=hostname,
                error=str(e),
            )
            return False


# Global database pool instance
db_pool = DatabasePool()
