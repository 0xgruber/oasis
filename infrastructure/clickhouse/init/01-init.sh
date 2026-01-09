#!/bin/bash
set -e

###############################################################################
# ClickHouse Initialization Script for O.A.S.I.S.
# Creates service-specific users and grants permissions
###############################################################################

echo "========================================"
echo "O.A.S.I.S. ClickHouse Initialization"
echo "========================================"

# Wait for ClickHouse to be ready
until clickhouse-client --query "SELECT 1" > /dev/null 2>&1; do
    echo "Waiting for ClickHouse to be ready..."
    sleep 2
done

echo "ClickHouse is ready, creating users and permissions..."

# Create database
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS oasis"

# Create ingestion_user with INSERT permissions only
clickhouse-client --multiquery <<-EOSQL
    CREATE USER IF NOT EXISTS ingestion_user IDENTIFIED BY '${CLICKHOUSE_INGESTION_PASSWORD:-changeme}';
    GRANT INSERT ON oasis.* TO ingestion_user;
    GRANT CREATE TABLE ON oasis.* TO ingestion_user;
EOSQL

echo "ingestion_user created with INSERT and CREATE TABLE permissions"

# Create api_user with SELECT permissions only
clickhouse-client --multiquery <<-EOSQL
    CREATE USER IF NOT EXISTS api_user IDENTIFIED BY '${CLICKHOUSE_API_PASSWORD:-changeme}';
    GRANT SELECT ON oasis.* TO api_user;
EOSQL

echo "api_user created with SELECT permissions"

# Create the Internal tenant table
clickhouse-client --multiquery <<-EOSQL
    CREATE TABLE IF NOT EXISTS oasis.logs_ffffffff_ffff_ffff_ffff_ffffffffffff (
        timestamp DateTime64(3) CODEC(DoubleDelta, LZ4),
        tenant_id UUID DEFAULT 'ffffffff-ffff-ffff-ffff-ffffffffffff',
        raw_log String CODEC(ZSTD(1)),
        ocsf JSON CODEC(ZSTD(1)),
        source_ip IPv4 CODEC(Delta, LZ4),
        destination_ip IPv4 CODEC(Delta, LZ4),
        severity_id UInt8 CODEC(T64, LZ4),
        category_uid UInt16 CODEC(T64, LZ4),
        class_uid UInt16 CODEC(T64, LZ4),
        activity_id UInt8 CODEC(T64, LZ4),
        status_id UInt8 CODEC(T64, LZ4),
        indexed_at DateTime64(3) DEFAULT now64() CODEC(DoubleDelta, LZ4)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (timestamp, tenant_id, severity_id, category_uid)
    TTL timestamp + INTERVAL 365 DAY
    SETTINGS index_granularity = 8192, storage_policy = 'default';
EOSQL

echo "Internal tenant table created: logs_ffffffff_ffff_ffff_ffff_ffffffffffff"

echo "========================================"
echo "ClickHouse initialization completed!"
echo "========================================"
