"""
ClickHouse client for log storage
"""

from typing import List, Dict, Any, Optional
from datetime import datetime
import json

import clickhouse_connect
import structlog

from src.config import settings

logger = structlog.get_logger()


class ClickHouseClient:
    """ClickHouse client for log storage with table-per-tenant"""

    def __init__(self) -> None:
        self.client: Optional[clickhouse_connect.driver.Client] = None

    def connect(self) -> None:
        """Create ClickHouse connection"""
        try:
            self.client = clickhouse_connect.get_client(
                host=settings.CLICKHOUSE_HOST,
                port=settings.CLICKHOUSE_PORT,
                database=settings.CLICKHOUSE_DB,
                username=settings.CLICKHOUSE_USER,
                password=settings.CLICKHOUSE_PASSWORD,
            )
            logger.info("clickhouse_connected", host=settings.CLICKHOUSE_HOST)
        except Exception as e:
            logger.error("clickhouse_connection_failed", error=str(e))
            raise

    def disconnect(self) -> None:
        """Close ClickHouse connection"""
        if self.client:
            self.client.close()
            logger.info("clickhouse_disconnected")

    def ensure_tenant_table(self, tenant_id: str, retention_days: int = 90) -> None:
        """
        Create log table for tenant if it doesn't exist

        Args:
            tenant_id: UUID of tenant
            retention_days: TTL for log retention
        """
        if not self.client:
            raise RuntimeError("ClickHouse client not connected")

        # Sanitize tenant_id (UUID format)
        table_name = f"logs_{tenant_id.replace('-', '_')}"

        try:
            # Check if table exists
            result = self.client.query(f"EXISTS TABLE {settings.CLICKHOUSE_DB}.{table_name}")
            if result.result_rows[0][0] == 1:
                logger.debug("tenant_table_exists", tenant_id=tenant_id, table=table_name)
                self._ensure_tenant_table_schema(table_name)
                return

            # Create table
            create_sql = f"""
            CREATE TABLE IF NOT EXISTS {settings.CLICKHOUSE_DB}.{table_name} (
                uuid UUID DEFAULT reinterpretAsUUID(MD5(concat(toString(timestamp), raw_log))),
                timestamp DateTime64(3) CODEC(DoubleDelta, LZ4),
                tenant_id UUID DEFAULT '{tenant_id}',
                raw_log String CODEC(ZSTD(1)),
                message String CODEC(ZSTD(1)),
                ocsf JSON CODEC(ZSTD(1)),
                source_ip IPv4 CODEC(Delta, LZ4),
                destination_ip IPv4 CODEC(Delta, LZ4),
                severity_id UInt8 CODEC(T64, LZ4),
                category_uid UInt16 CODEC(T64, LZ4),
                class_uid UInt16 CODEC(T64, LZ4),
                activity_id UInt8 CODEC(T64, LZ4),
                status_id UInt8 CODEC(T64, LZ4),
                ingested_at DateTime64(3) DEFAULT timestamp CODEC(DoubleDelta, LZ4)
            ) ENGINE = MergeTree()
            PARTITION BY toYYYYMM(timestamp)
            ORDER BY (timestamp, tenant_id, severity_id, category_uid)
            TTL toDateTime(timestamp) + INTERVAL {retention_days} DAY
            SETTINGS index_granularity = 8192, storage_policy = 'default'
            """

            self.client.command(create_sql)
            logger.info(
                "tenant_table_created",
                tenant_id=tenant_id,
                table=table_name,
                retention_days=retention_days,
            )

        except Exception as e:
            logger.error(
                "tenant_table_creation_failed",
                tenant_id=tenant_id,
                table=table_name,
                error=str(e),
            )
            raise

    def _ensure_tenant_table_schema(self, table_name: str) -> None:
        """Best-effort schema migration for existing tenant tables."""
        if not self.client:
            raise RuntimeError("ClickHouse client not connected")

        try:
            # Ensure new columns exist on older tables.
            self.client.command(
                f"ALTER TABLE {settings.CLICKHOUSE_DB}.{table_name} "
                "ADD COLUMN IF NOT EXISTS uuid UUID "
                "DEFAULT reinterpretAsUUID(MD5(concat(toString(timestamp), raw_log)))"
            )
            self.client.command(
                f"ALTER TABLE {settings.CLICKHOUSE_DB}.{table_name} "
                "ADD COLUMN IF NOT EXISTS message String DEFAULT ''"
            )
            # Use event timestamp as stable default for old parts.
            self.client.command(
                f"ALTER TABLE {settings.CLICKHOUSE_DB}.{table_name} "
                "ADD COLUMN IF NOT EXISTS ingested_at DateTime64(3) DEFAULT timestamp"
            )
        except Exception as e:
            logger.warning("tenant_table_schema_migration_failed", table=table_name, error=str(e))

    def insert_logs(self, tenant_id: str, logs: List[Dict[str, Any]]) -> int:
        """
        Insert batch of logs into tenant table

        Args:
            tenant_id: UUID of tenant
            logs: List of normalized log entries

        Returns:
            Number of logs inserted
        """
        if not self.client:
            raise RuntimeError("ClickHouse client not connected")

        if not logs:
            return 0

        table_name = f"logs_{tenant_id.replace('-', '_')}"

        try:
            # Prepare data for insertion
            rows = []
            for log in logs:
                rows.append(
                    [
                        log.get("timestamp"),
                        tenant_id,
                        log.get("raw_log", ""),
                        log.get("message", ""),
                        json.dumps(log.get("ocsf", {})),
                        log.get("source_ip", "0.0.0.0"),
                        log.get("destination_ip", "0.0.0.0"),
                        log.get("severity_id", 1),
                        log.get("category_uid", 0),
                        log.get("class_uid", 0),
                        log.get("activity_id", 0),
                        log.get("status_id", 0),
                        datetime.utcnow(),
                    ]
                )

            # Insert batch
            self.client.insert(
                f"{settings.CLICKHOUSE_DB}.{table_name}",
                rows,
                column_names=[
                    "timestamp",
                    "tenant_id",
                    "raw_log",
                    "message",
                    "ocsf",
                    "source_ip",
                    "destination_ip",
                    "severity_id",
                    "category_uid",
                    "class_uid",
                    "activity_id",
                    "status_id",
                    "ingested_at",
                ],
            )

            logger.info(
                "logs_inserted",
                tenant_id=tenant_id,
                table=table_name,
                count=len(rows),
            )

            return len(rows)

        except Exception as e:
            logger.error(
                "log_insertion_failed",
                tenant_id=tenant_id,
                table=table_name,
                error=str(e),
            )
            raise


# Global ClickHouse client instance
ch_client = ClickHouseClient()
