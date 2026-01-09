# Internal Gateway Service

Corporate network log ingestion gateway for O.A.S.I.S.

## Features

- **API Key Authentication**: Validates API keys against PostgreSQL
- **Rate Limiting**: Per-tenant EPS (Events Per Second) limits
- **HTTP/JSON Ingestion**: RESTful API for log submission
- **Syslog Support**: UDP/TCP/TLS syslog listeners (Phase 1B)
- **mTLS Forwarding**: Secure communication with ingestion service
- **Health Checks**: `/health` and `/ready` endpoints

## Architecture

```
Internet → Internal Gateway (DMZ) → Ingestion Service (Backend)
                ↓
        PostgreSQL (auth)
```

## API Endpoints

### Health Checks

- `GET /health` - Service health check
- `GET /ready` - Readiness check

### Ingestion

- `POST /api/v1/ingest` - Ingest log batch (requires API key)
  - Header: `Authorization: Bearer <api_key>`
  - Body: `{ "logs": [...] }`
  - Max batch size: 1000 logs

### Syslog (Phase 1B)

- UDP port 514 - RFC3164/RFC5424
- TCP port 514 - RFC3164/RFC5424
- TCP port 6514 - TLS RFC5424

## Configuration

Environment variables:

```bash
# Gateway identification
GATEWAY_TYPE=external
GATEWAY_NAME="Internal Gateway"

# PostgreSQL
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DB=oasis
POSTGRES_USER=gateway_user
POSTGRES_PASSWORD=changeme

# Ingestion service
INGESTION_SERVICE_URL=https://ingestion-service:8080

# mTLS
MTLS_CERT_PATH=/certs/gateway.crt
MTLS_KEY_PATH=/certs/gateway.key
MTLS_CA_PATH=/certs/ca.crt

# Limits
DEFAULT_RATE_LIMIT=1000
MAX_REQUEST_SIZE=10485760  # 10MB
MAX_BATCH_SIZE=1000

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
poetry run uvicorn src.main:app --reload --port 8000
```

### Run Tests

```bash
poetry run pytest
```

### Linting

```bash
poetry run ruff check src/
poetry run black --check src/
```

### Type Checking

```bash
poetry run mypy src/
```

## Docker

### Build

```bash
docker build -t oasis-internal-gateway:latest .
```

### Run

```bash
docker run -p 8443:443 -p 514:514/udp \
  -e POSTGRES_HOST=postgresql \
  -e POSTGRES_PASSWORD=changeme \
  -v ./certs:/certs:ro \
  oasis-internal-gateway:latest
```

## Testing with curl

### Health Check

```bash
curl http://localhost:8000/health
```

### Ingest Logs

```bash
curl -X POST http://localhost:8000/api/v1/ingest \
  -H "Authorization: Bearer <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [
      {
        "timestamp": "2024-01-09T00:00:00Z",
        "message": "Test log entry",
        "severity": "informational",
        "source": "test-app",
        "metadata": {"key": "value"}
      }
    ]
  }'
```

## Security

- All API keys are hashed with bcrypt before storage
- mTLS required for ingestion service communication
- Rate limiting enforced per tenant
- Input validation on all endpoints
- Non-root user in Docker container

## Monitoring

Structured JSON logging to stdout:

```json
{
  "event": "request_received",
  "method": "POST",
  "path": "/api/v1/ingest",
  "tenant_id": "uuid",
  "timestamp": "2024-01-09T00:00:00Z"
}
```

## Related Services

- **Internal Gateway**: Identical service for corporate network
- **Ingestion Service**: OCSF normalization and ClickHouse storage
- **API Service**: Query and management API

## Status

**Phase 1A**: Core HTTP/JSON ingestion ✅  
**Phase 1B**: Syslog listeners, advanced rate limiting ⏸️
