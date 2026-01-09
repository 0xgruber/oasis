# O.A.S.I.S. - Phase 1A Infrastructure

This commit establishes the foundational infrastructure for the O.A.S.I.S. project Phase 1A.

## What's Included

### Docker Infrastructure
- **docker-compose.yml**: Complete three-subnet architecture (DMZ, Internal, Backend)
  - External Gateway (DMZ: 172.20.0.10, ports 8443, 514, 6514)
  - Internal Gateway (Internal: 172.21.0.10, ports 8444, 1514, 7514)
  - SOC Portal (Internal: 172.21.0.20, port 3000)
  - Ingestion Service (Backend: 172.22.0.30)
  - API Service (Backend: 172.22.0.40)
  - ClickHouse (Backend: 172.22.0.50, 12GB memory limit)
  - PostgreSQL (Backend: 172.22.0.60, 2GB memory limit)
  - Qdrant (Backend: 172.22.0.70, 2GB memory limit)

### Database Configuration

#### PostgreSQL (Metadata Storage)
- **Schema**: tenants, api_keys, users, certificates, audit_logs, system_config
- **Service Users**: gateway_user, ingestion_user, api_user (least privilege)
- **Auto-created**: "Internal" tenant (UUID: ffffffff-ffff-ffff-ffff-ffffffffffff)
- **Default Admin**: username `admin`, password `Admin123!` (CHANGE IMMEDIATELY)

#### ClickHouse (Log Storage)
- **Table-per-tenant**: logs_{tenant_uuid} with MergeTree engine
- **Service Users**: ingestion_user (INSERT only), api_user (SELECT only)
- **Partitioning**: By month (toYYYYMM(timestamp))
- **TTL**: Configurable per tenant (default: 365 days for Internal)
- **Compression**: LZ4 for performance, ZSTD for storage efficiency

### Project Structure
```
services/
├── external-gateway/    # DMZ internet-facing gateway
├── internal-gateway/    # Corporate network gateway  
├── ingestion-service/   # Log normalization and storage
└── api-service/         # REST API for queries and management

infrastructure/
├── clickhouse/          # ClickHouse config and init scripts
├── postgresql/          # PostgreSQL schema and init scripts
├── certificates/        # Self-signed certs (auto-generated)
└── docker/              # Docker-related configs

frontend/                # Next.js SOC Portal
scripts/                 # Utility scripts
docs/                    # Additional documentation
```

### Gateway Service (Started)
- FastAPI-based Python service
- API key authentication
- Per-tenant rate limiting
- mTLS for ingestion service communication
- Syslog support (UDP/TCP/TLS)

## Getting Started

### Prerequisites
- Docker & Docker Compose
- Poetry (for Python services)
- Node.js 20+ (for frontend)

### Initial Setup

1. **Copy environment file**:
   ```bash
   cp .env.example .env
   ```

2. **Generate secure JWT secret**:
   ```bash
   openssl rand -hex 32
   # Update JWT_SECRET in .env with generated value
   ```

3. **Update default passwords in .env**:
   ```bash
   nano .env
   # Change all passwords from "changeme" to secure values
   ```

4. **Start infrastructure** (when services are complete):
   ```bash
   docker compose up -d
   ```

5. **Check service health**:
   ```bash
   docker compose ps
   docker compose logs -f
   ```

## Security Notes

⚠️ **IMPORTANT**: This is a development configuration. Production deployment requires:
- Strong passwords for all service accounts
- Secure JWT secret (generated with `openssl rand -hex 32`)
- Change default admin password immediately after first login
- Proper certificate management (not self-signed)
- Network firewall rules
- Resource limits tuned for production hardware

## Next Steps (Phase 1A Continuation)

- [ ] Complete external gateway implementation (API key auth, rate limiting)
- [ ] Complete internal gateway implementation (identical to external)
- [ ] Implement ingestion service (OCSF normalization, batch inserts)
- [ ] Implement API service (JWT auth, log queries, tenant management)
- [ ] Create SOC portal frontend (Next.js with authentication)
- [ ] Write unit tests for all services (80% coverage)
- [ ] Write integration tests (gateway → ingestion → ClickHouse)

## Current Status

**Completed**:
- ✅ Project structure
- ✅ Docker Compose with three-subnet architecture
- ✅ PostgreSQL schema and initialization
- ✅ ClickHouse configuration and initialization
- ✅ Gateway service project structure

**In Progress**:
- 🚧 External gateway implementation

**Pending**:
- ⏸️ Internal gateway
- ⏸️ Ingestion service
- ⏸️ API service
- ⏸️ SOC Portal frontend

## Related Documentation

- [OpenSpec Proposal](../../openspec/changes/add-oasis-foundation/proposal.md)
- [Design Decisions](../../openspec/changes/add-oasis-foundation/design.md)
- [Implementation Tasks](../../openspec/changes/add-oasis-foundation/tasks.md)
- [Git Workflow](../../GIT_WORKFLOW.md)
- [CI/CD Pipeline](../../CI_CD_PIPELINE.md)
- [Contributing Guide](../../CONTRIBUTING.md)
