"""
Metrics calculation logic
"""

from typing import Dict, Any
import structlog
import asyncpg
import clickhouse_connect

from .config import settings
from .cache import cache

logger = structlog.get_logger()

# Global database connections
pg_pool: asyncpg.Pool | None = None
ch_client: clickhouse_connect.driver.Client | None = None


async def initialize_connections():
    """Initialize database connections"""
    global pg_pool, ch_client

    pg_pool = await asyncpg.create_pool(
        host=settings.POSTGRES_HOST,
        port=settings.POSTGRES_PORT,
        database=settings.POSTGRES_DB,
        user=settings.POSTGRES_USER,
        password=settings.POSTGRES_PASSWORD,
        min_size=2,
        max_size=10,
    )

    ch_client = clickhouse_connect.get_client(
        host=settings.CLICKHOUSE_HOST,
        port=settings.CLICKHOUSE_PORT,
        database=settings.CLICKHOUSE_DB,
        username=settings.CLICKHOUSE_USER,
        password=settings.CLICKHOUSE_PASSWORD,
    )

    logger.info("database_connections_initialized")


async def close_connections():
    """Close database connections"""
    if pg_pool:
        await pg_pool.close()
    if ch_client:
        ch_client.close()
    logger.info("database_connections_closed")


async def get_system_metrics() -> Dict[str, Any]:
    """
    Calculate system-wide metrics:
    - total_logs: Count across all tenant tables in ClickHouse
    - total_sources: Unique agent hostnames from PostgreSQL
    - ingestion_rate: Logs per second in last 5 minutes

    Returns:
        Dictionary with metrics
    """
    # Check cache first
    cache_key = "metrics:system:all"
    cached = await cache.get(cache_key)
    if cached is not None:
        logger.debug("system_metrics_cache_hit")
        return cached

    metrics = {
        "total_logs": 0,
        "total_sources": 0,
        "ingestion_rate": 0.0,
    }

    try:
        # Get total logs across all tenants from ClickHouse
        if ch_client:
            try:
                # Get all log tables (one per tenant)
                tables_result = ch_client.query(
                    f"""
                    SELECT name 
                    FROM system.tables 
                    WHERE database = '{settings.CLICKHOUSE_DB}' 
                    AND name LIKE 'logs_%'
                    """
                )

                total_logs = 0
                for row in tables_result.result_rows:
                    table_name = row[0]
                    count_result = ch_client.query(
                        f"SELECT count() FROM {settings.CLICKHOUSE_DB}.{table_name}"
                    )
                    if count_result.result_rows:
                        total_logs += count_result.result_rows[0][0]

                metrics["total_logs"] = total_logs

                # Calculate ingestion rate (logs per second in last 5 minutes)
                ingestion_rate = 0.0
                for row in tables_result.result_rows:
                    table_name = row[0]
                    # Check if ingested_at column exists
                    cols_result = ch_client.query(
                        f"""
                        SELECT name FROM system.columns
                        WHERE database = '{settings.CLICKHOUSE_DB}' 
                        AND table = '{table_name}'
                        AND name IN ('ingested_at', 'indexed_at', 'timestamp')
                        LIMIT 1
                        """
                    )

                    if cols_result.result_rows:
                        time_col = cols_result.result_rows[0][0]
                        rate_result = ch_client.query(
                            f"""
                            SELECT count() / 300.0 as rate
                            FROM {settings.CLICKHOUSE_DB}.{table_name}
                            WHERE {time_col} >= now() - INTERVAL 5 MINUTE
                            """
                        )
                        if rate_result.result_rows:
                            ingestion_rate += rate_result.result_rows[0][0]

                metrics["ingestion_rate"] = round(ingestion_rate, 2)

            except Exception as e:
                logger.warning("clickhouse_metrics_failed", error=str(e))

        # Get total sources (unique agent hostnames) from PostgreSQL
        if pg_pool:
            try:
                async with pg_pool.acquire() as conn:
                    # Count unique agent hostnames across all tenants
                    sources_result = await conn.fetchval(
                        "SELECT COUNT(DISTINCT hostname) FROM agents WHERE hostname IS NOT NULL"
                    )
                    metrics["total_sources"] = sources_result or 0
            except Exception as e:
                logger.warning("postgres_sources_failed", error=str(e))

        # Cache the result
        await cache.set(cache_key, metrics, settings.CACHE_TTL_SYSTEM_METRICS)
        logger.info("system_metrics_calculated", metrics=metrics)

        return metrics

    except Exception as e:
        logger.error("metrics_calculation_failed", error=str(e))
        raise


async def get_tenant_metrics(tenant_id: str) -> Dict[str, Any]:
    """
    Calculate per-tenant metrics

    Args:
        tenant_id: Tenant UUID

    Returns:
        Dictionary with tenant metrics
    """
    # Check cache first
    cache_key = f"metrics:tenant:{tenant_id}"
    cached = await cache.get(cache_key)
    if cached is not None:
        logger.debug("tenant_metrics_cache_hit", tenant_id=tenant_id)
        return cached

    metrics = {
        "tenant_id": tenant_id,
        "logs_count": 0,
        "sources_count": 0,
        "ingestion_rate": 0.0,
    }

    try:
        # Get logs from tenant-specific ClickHouse table
        if ch_client:
            try:
                table_name = f"logs_{tenant_id.replace('-', '_')}"

                # Check if table exists
                table_check = ch_client.query(
                    f"""
                    SELECT name 
                    FROM system.tables 
                    WHERE database = '{settings.CLICKHOUSE_DB}' 
                    AND name = '{table_name}'
                    """
                )

                if table_check.result_rows:
                    # Get total logs
                    count_result = ch_client.query(
                        f"SELECT count() FROM {settings.CLICKHOUSE_DB}.{table_name}"
                    )
                    if count_result.result_rows:
                        metrics["logs_count"] = count_result.result_rows[0][0]

                    # Get ingestion rate
                    cols_result = ch_client.query(
                        f"""
                        SELECT name FROM system.columns
                        WHERE database = '{settings.CLICKHOUSE_DB}' 
                        AND table = '{table_name}'
                        AND name IN ('ingested_at', 'indexed_at', 'timestamp')
                        LIMIT 1
                        """
                    )

                    if cols_result.result_rows:
                        time_col = cols_result.result_rows[0][0]
                        rate_result = ch_client.query(
                            f"""
                            SELECT count() / 300.0 as rate
                            FROM {settings.CLICKHOUSE_DB}.{table_name}
                            WHERE {time_col} >= now() - INTERVAL 5 MINUTE
                            """
                        )
                        if rate_result.result_rows:
                            metrics["ingestion_rate"] = round(rate_result.result_rows[0][0], 2)

            except Exception as e:
                logger.warning(
                    "clickhouse_tenant_metrics_failed", tenant_id=tenant_id, error=str(e)
                )

        # Get sources count for this tenant from PostgreSQL
        if pg_pool:
            try:
                async with pg_pool.acquire() as conn:
                    sources_result = await conn.fetchval(
                        "SELECT COUNT(*) FROM agents WHERE tenant_id = $1", tenant_id
                    )
                    metrics["sources_count"] = sources_result or 0
            except Exception as e:
                logger.warning("postgres_tenant_sources_failed", tenant_id=tenant_id, error=str(e))

        # Cache the result
        await cache.set(cache_key, metrics, settings.CACHE_TTL_TENANT_METRICS)
        logger.info("tenant_metrics_calculated", tenant_id=tenant_id, metrics=metrics)

        return metrics

    except Exception as e:
        logger.error("tenant_metrics_calculation_failed", tenant_id=tenant_id, error=str(e))
        raise


async def get_agent_metrics(agent_id: str) -> Dict[str, Any]:
    """
    Calculate per-agent metrics

    Args:
        agent_id: Agent UUID

    Returns:
        Dictionary with agent metrics
    """
    # Check cache first
    cache_key = f"metrics:agent:{agent_id}"
    cached = await cache.get(cache_key)
    if cached is not None:
        logger.debug("agent_metrics_cache_hit", agent_id=agent_id)
        return cached

    metrics = {
        "agent_id": agent_id,
        "logs_count": 0,
        "last_seen": None,
        "status": "unknown",
    }

    try:
        # Get agent info from PostgreSQL
        if pg_pool:
            try:
                async with pg_pool.acquire() as conn:
                    agent = await conn.fetchrow(
                        """
                        SELECT hostname, tenant_id, last_seen, status
                        FROM agents 
                        WHERE agent_id = $1
                        """,
                        agent_id,
                    )

                    if agent:
                        metrics["hostname"] = agent["hostname"]
                        metrics["tenant_id"] = str(agent["tenant_id"])
                        metrics["last_seen"] = (
                            agent["last_seen"].isoformat() if agent["last_seen"] else None
                        )
                        metrics["status"] = agent["status"]

                        # Get logs count for this agent from ClickHouse
                        if ch_client and agent["tenant_id"]:
                            table_name = f"logs_{str(agent['tenant_id']).replace('-', '_')}"

                            # Check if table exists
                            table_check = ch_client.query(
                                f"""
                                SELECT name 
                                FROM system.tables 
                                WHERE database = '{settings.CLICKHOUSE_DB}' 
                                AND name = '{table_name}'
                                """
                            )

                            if table_check.result_rows:
                                # Try to count logs by agent hostname
                                count_result = ch_client.query(
                                    f"""
                                    SELECT count() 
                                    FROM {settings.CLICKHOUSE_DB}.{table_name}
                                    WHERE hostname = '{agent["hostname"]}'
                                    """
                                )
                                if count_result.result_rows:
                                    metrics["logs_count"] = count_result.result_rows[0][0]

            except Exception as e:
                logger.warning("agent_metrics_failed", agent_id=agent_id, error=str(e))

        # Cache the result
        await cache.set(cache_key, metrics, settings.CACHE_TTL_AGENT_METRICS)
        logger.info("agent_metrics_calculated", agent_id=agent_id, metrics=metrics)

        return metrics

    except Exception as e:
        logger.error("agent_metrics_calculation_failed", agent_id=agent_id, error=str(e))
        raise
