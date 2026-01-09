# Ingestion Service

Log normalization and storage service for O.A.S.I.S.

## Features

- **mTLS Server**: Authenticates gateway services
- **OCSF Normalization**: Converts logs to Open Cybersecurity Schema Framework
- **ClickHouse Storage**: Table-per-tenant log storage
- **Dynamic Table Creation**: Creates tenant tables on-demand
- **Batch Processing**: Efficient batch inserts (1000 logs/batch)
- **Error Handling**: Graceful degradation on normalization failures

## Architecture

```
Gateway (mTLS) → Ingestion Service → ClickHouse (table per tenant)
                         ↓
                   PostgreSQL (tenant metadata)
```

## API Endpoints

### Health Check

- `GET /health` - Service health

### Ingestion

- `POST /ingest` - Ingest log batch from gateway (mTLS required)
  - Body: `{ "tenant_id": "uuid", "logs": [...] }`
  - Returns: `{ "accepted": n, "rejected": n }`

## OCSF Normalization

Logs are normalized to OCSF 1.0.0 format:

- **class_uid**: 3001 (Application Activity)
- **category_uid**: 3 (Application Activity)
- **severity_id**: 1-6 (debug to fatal)
- **timestamp**: ISO 8601 format
- **metadata**: Preserved from original log

## ClickHouse Schema

Table-per-tenant: `logs_{tenant_uuid}`

```sql
CREATE TABLE logs_<tenant_uuid> (
    timestamp DateTime64(3),
    tenant_id UUID,
    raw_log String,
    ocsf JSON,
    source_ip IPv4,
    destination_ip IPv4,
    severity_id UInt8,
    category_uid UInt16,
    class_uid UInt16,
    activity_id UInt8,
    status_id UInt8,
    indexed_at DateTime64(3) DEFAULT now64()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, tenant_id, severity_id, category_uid)
TTL timestamp + INTERVAL <retention_days> DAY
```

## Configuration

Environment variables:

```bash
# ClickHouse
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=9000
CLICKHOUSE_DB=oasis
CLICKHOUSE_USER=ingestion_user
CLICKHOUSE_PASSWORD=changeme

# PostgreSQL (tenant metadata)
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DB=oasis
POSTGRES_USER=ingestion_user
POSTGRES_PASSWORD=changeme

# mTLS
MTLS_CERT_PATH=/certs/ingestion.crt
MTLS_KEY_PATH=/certs/ingestion.key
MTLS_CA_PATH=/certs/ca.crt

# Batch processing
BATCH_SIZE=1000
BATCH_TIMEOUT_SECONDS=5
MAX_BUFFER_SIZE=10000

# Logging
LOG_LEVEL=INFO
```

## Development

### Install Dependencies

```bash
poetry install
```

### Run Locally

```bash
poetry run uvicorn src.main:app --reload --port 8080
```

### Run Tests

```bash
poetry run pytest
```

## Performance

- **Batch size**: 1000 logs per insert
- **Compression**: LZ4 for timestamps/IPs, ZSTD for JSON/strings
- **Partitioning**: Monthly partitions for efficient queries
- **TTL**: Automatic deletion after retention period
- **Indexing**: Optimized for time-based queries

## Monitoring

Structured JSON logging:

```json
{
  "event": "ingestion_request_received",
  "tenant_id": "uuid",
  "log_count": 1000,
  "timestamp": "2024-01-09T00:00:00Z"
}
```

## Related Services

- **Gateway Services**: Forward logs via mTLS
- **API Service**: Query stored logs
- **ClickHouse**: Time-series log storage

## Status

**Phase 1A**: Core ingestion and storage ✅  
**Phase 1B**: Advanced batching, back-pressure ⏸️
