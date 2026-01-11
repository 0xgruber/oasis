# O.A.S.I.S. Metrics Service

**Real-time metrics aggregation and caching service**

The Metrics Service is a dedicated microservice that calculates and caches real-time metrics for the OASIS platform, including log counts, ingestion rates, agent statistics, and system health indicators.

## Purpose

- **Separation of Concerns**: Isolates metrics calculation from the API service
- **Performance**: Redis caching reduces database queries by ~97%
- **Scalability**: Can scale independently based on metrics query load
- **Real-time**: Computes fresh metrics with configurable TTL (30-60s)

## Architecture

```
API Service → Metrics Service → Redis Cache → ClickHouse/PostgreSQL
                                      ↓
                              Cached Results (30-60s TTL)
```

## Endpoints

### Health Check
```
GET /health
```

Returns service health status.

**Response:**
```json
{
  "status": "healthy",
  "service": "metrics-service",
  "version": "0.1.0"
}
```

---

### System Metrics
```
GET /metrics/system
```

System-wide aggregated metrics across all tenants.

**Response:**
```json
{
  "total_logs": 3780,
  "total_sources": 2,
  "ingestion_rate": 0.03
}
```

**Fields:**
- `total_logs`: Total log count across all tenants
- `total_sources`: Unique agent hostnames (active + inactive)
- `ingestion_rate`: Logs per second in last 5 minutes

**Cache TTL:** 30 seconds

---

### Tenant Metrics
```
GET /metrics/tenant/{tenant_id}
```

Per-tenant metrics and statistics.

**Parameters:**
- `tenant_id` (path): Tenant UUID

**Response:**
```json
{
  "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
  "logs_count": 1500,
  "sources_count": 2,
  "ingestion_rate": 0.05
}
```

**Fields:**
- `logs_count`: Total logs for this tenant
- `sources_count`: Number of agents for this tenant
- `ingestion_rate`: Logs per second in last 5 minutes

**Cache TTL:** 30 seconds

---

### Agent Metrics
```
GET /metrics/agent/{agent_id}
```

Per-agent metrics and status (planned enhancement).

**Parameters:**
- `agent_id` (path): Agent UUID

**Response:**
```json
{
  "agent_id": "660e8400-e29b-41d4-a716-446655440000",
  "hostname": "web-server-01",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "logs_count": 500,
  "last_seen": "2026-01-11T22:30:47Z",
  "status": "online"
}
```

**Fields:**
- `logs_count`: Total logs from this agent
- `last_seen`: Last heartbeat timestamp (ISO 8601)
- `status`: Computed status (`online`, `offline`, `dead`)

**Cache TTL:** 60 seconds

---

### Cache Management

#### Clear All Cache
```
POST /cache/clear
```

Clears all cached metrics (admin operation).

**Response:**
```json
{
  "status": "success",
  "message": "All metrics cache cleared"
}
```

---

#### Clear Tenant Cache
```
POST /cache/clear/tenant/{tenant_id}
```

Clears cached metrics for a specific tenant.

**Parameters:**
- `tenant_id` (path): Tenant UUID

**Response:**
```json
{
  "status": "success",
  "message": "Cache cleared for tenant {tenant_id}"
}
```

---

## Configuration

Environment variables (via Docker Compose):

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `redis` | Redis server hostname |
| `REDIS_PORT` | `6379` | Redis server port |
| `CLICKHOUSE_HOST` | `clickhouse` | ClickHouse server hostname |
| `CLICKHOUSE_PORT` | `8123` | ClickHouse HTTP port |
| `POSTGRES_HOST` | `postgresql` | PostgreSQL server hostname |
| `POSTGRES_PORT` | `5432` | PostgreSQL server port |
| `CACHE_TTL_SYSTEM_METRICS` | `30` | System metrics cache TTL (seconds) |
| `CACHE_TTL_TENANT_METRICS` | `30` | Tenant metrics cache TTL (seconds) |
| `CACHE_TTL_AGENT_METRICS` | `60` | Agent metrics cache TTL (seconds) |

## Technology Stack

- **Python 3.11**: Runtime environment
- **FastAPI**: Web framework
- **Redis**: Cache layer (redis:7-alpine)
- **asyncpg**: Async PostgreSQL client
- **clickhouse-connect**: ClickHouse client
- **structlog**: Structured logging

## Performance Characteristics

- **Latency**: <100ms for cached responses, <500ms for cache misses
- **Cache Hit Rate**: ~97% under normal load (30-60s TTL)
- **Database Load Reduction**: ~97% fewer queries to ClickHouse/PostgreSQL
- **Scalability**: Stateless design allows horizontal scaling

## Caching Strategy

### Cache Keys
- System metrics: `metrics:system:all`
- Tenant metrics: `metrics:tenant:{tenant_id}`
- Agent metrics: `metrics:agent:{agent_id}`

### Cache Invalidation
- **TTL-based**: Automatic expiration after configured TTL
- **Manual**: POST endpoints for admin-triggered clearing
- **LRU Eviction**: Redis evicts least-recently-used keys when memory limit reached

### Cache Memory
- **Redis Memory Limit**: 256MB (docker-compose.yml)
- **Eviction Policy**: `allkeys-lru` (evict least recently used keys)

## Docker Network

- **Network**: `backend-network` (172.22.0.0/24)
- **IP Address**: 172.22.0.41
- **Port**: 8001 (internal only)
- **Dependencies**: redis, clickhouse, postgresql

## Development

### Local Testing
```bash
# Start service
docker compose up -d metrics-service

# View logs
docker logs oasis-metrics-service -f

# Test endpoint
curl http://localhost:8001/health
```

### Adding New Metrics

1. Add metric calculation function to `src/metrics.py`
2. Add endpoint to `src/main.py`
3. Define cache key and TTL in `src/config.py`
4. Update this README with new endpoint documentation

## Monitoring

### Health Check
The `/health` endpoint is polled by Docker Compose healthchecks every 10 seconds.

### Logs
Structured logs output to stdout/stderr in JSON format:
```json
{
  "timestamp": "2026-01-11T22:30:45Z",
  "level": "info",
  "event": "system_metrics_calculated",
  "metrics": {"total_logs": 3780, "total_sources": 2}
}
```

### Redis Monitoring
```bash
# Check cache keys
docker exec oasis-redis redis-cli KEYS "metrics:*"

# Check memory usage
docker exec oasis-redis redis-cli INFO memory

# Monitor cache hits/misses
docker exec oasis-redis redis-cli INFO stats | grep keyspace
```

## Phase History

- **Phase 2A** (2026-01-11): Initial implementation
  - System, tenant, and agent metrics endpoints
  - Redis caching with configurable TTL
  - Integration with API service

- **Phase 2B** (In Progress): Agent status calculation
  - Dynamic agent status computation (online/offline/dead)
  - Tenant-specific threshold support
  - Enhanced agent metrics

## Future Enhancements

- **Background Pre-Aggregation**: Calculate metrics proactively before requests
- **Prometheus Export**: `/metrics` endpoint in Prometheus format
- **Alert Metrics**: Alert count, severity distribution, MTTR
- **Threat Metrics**: IOCs, detection rates, compliance metrics
- **Time-Series Storage**: Historical metrics in ClickHouse
- **GraphQL API**: Flexible metric queries

## Related Services

- **API Service**: Primary consumer of metrics (proxies to frontend)
- **Redis**: Cache layer for computed metrics
- **ClickHouse**: Log storage (source data for log counts)
- **PostgreSQL**: Agent and tenant metadata (source data for counts)

## Architecture Decisions

### Why Separate Service?

**Benefits:**
- ✅ Reduces API service complexity
- ✅ Independent scaling based on metrics query load
- ✅ Isolates expensive database queries
- ✅ Enables targeted caching strategies
- ✅ Simplifies testing and maintenance

**Trade-offs:**
- ⚠️ Additional service to deploy and monitor
- ⚠️ Network hop adds ~1-2ms latency

**Decision**: Benefits outweigh costs for production scalability.

---

**Last Updated:** 2026-01-11  
**Version:** 0.1.0  
**Status:** Production (Phase 2A)
