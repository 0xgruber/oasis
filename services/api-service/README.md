# API Service

Query and management API for O.A.S.I.S.

## Features

- **JWT Authentication**: Secure token-based auth with configurable expiration
- **Password Hashing**: bcrypt for secure password storage
- **Log Query API**: Query logs with tenant isolation
- **User Management**: Login and authentication
- **Tenant Isolation**: Users can only access their tenant's logs
- **Health Checks**: Service health monitoring

## Architecture

```
SOC Portal → API Service (JWT auth) → ClickHouse (tenant-scoped queries)
                    ↓
              PostgreSQL (users, tenants)
```

## API Endpoints

### Health

- `GET /health` - Service health check

### Authentication

- `POST /auth/login` - User login
  - Body: `{ "username": "admin", "password": "Admin123!" }`
  - Returns: `{ "access_token": "...", "user_id": "...", "role": "..." }`

### Logs

- `GET /logs` - Query logs (requires JWT)
  - Header: `Authorization: Bearer <token>`
  - Query params: `limit` (default 100, max 10000), `offset` (default 0)
  - Returns tenant-scoped logs only

## Default Credentials

```
Username: admin
Password: Admin123!
Role: super_admin
Tenant: Internal (ffffffff-ffff-ffff-ffff-ffffffffffff)
```

**⚠️ CHANGE IMMEDIATELY IN PRODUCTION**

## JWT Tokens

Tokens include:
- `sub`: User ID
- `tenant_id`: User's tenant ID
- `role`: User's role (super_admin, internal_soc, soc_operator, tenant_user)
- `username`: Username
- `exp`: Expiration timestamp
- `iat`: Issued at timestamp

Token lifetime: 60 minutes (configurable via `JWT_EXPIRATION_MINUTES`)

## Tenant Isolation

- Each user belongs to a tenant
- Log queries automatically filter by user's tenant_id
- ClickHouse queries use table: `logs_{tenant_uuid}`
- Prevents cross-tenant data access

## Configuration

Environment variables:

```bash
# ClickHouse (read-only)
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=9000
CLICKHOUSE_DB=oasis
CLICKHOUSE_USER=api_user
CLICKHOUSE_PASSWORD=changeme

# PostgreSQL
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DB=oasis
POSTGRES_USER=api_user
POSTGRES_PASSWORD=changeme

# JWT
JWT_SECRET=changeme-generate-secure-secret
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=60

# TOTP (Phase 1B)
TOTP_ISSUER=O.A.S.I.S.

# Query limits
MAX_QUERY_LIMIT=10000
DEFAULT_QUERY_LIMIT=100

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

## Example Usage

### Login

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "Admin123!"}'
```

Response:
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer",
  "user_id": "uuid",
  "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
  "role": "super_admin"
}
```

### Query Logs

```bash
curl http://localhost:8000/logs?limit=10 \
  -H "Authorization: Bearer eyJhbGc..."
```

Response:
```json
{
  "logs": [
    {
      "timestamp": "2024-01-09T00:00:00",
      "tenant_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
      "raw_log": "...",
      "severity_id": 1
    }
  ],
  "total": 1000,
  "limit": 10,
  "offset": 0
}
```

## Security

- Passwords hashed with bcrypt (cost factor 12)
- JWT tokens signed with HS256
- Tenant isolation enforced at database query level
- Connection pooling with PostgreSQL
- Structured audit logging

## Monitoring

Structured JSON logging:

```json
{
  "event": "user_login_success",
  "user_id": "uuid",
  "username": "admin",
  "role": "super_admin",
  "timestamp": "2024-01-09T00:00:00Z"
}
```

## Future Features (Phase 1B/1C)

- TOTP 2FA support
- Tenant CRUD endpoints
- API key management
- Certificate management
- Re-authentication for sensitive operations
- Audit log viewing
- Advanced log filtering (severity, time range, search)
- Rate limiting per user
- OpenAPI/Swagger UI

## Related Services

- **SOC Portal**: React/Next.js frontend
- **Gateway Services**: Forward logs for storage
- **Ingestion Service**: Store logs in ClickHouse

## Status

**Phase 1A**: Core authentication and log querying ✅  
**Phase 1B**: Tenant management, API keys, TOTP ⏸️  
**Phase 1C**: Certificate management, advanced features ⏸️
