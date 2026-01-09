# Change: Add O.A.S.I.S. Foundation (Phase 1)

## Why

The O.A.S.I.S. (OSS AI SIEM Intelligence System) project requires a foundational architecture to support AI-driven security intelligence. This is the initial implementation (Phase 1) to establish core infrastructure for log ingestion, storage, and comprehensive operational management.

The system is designed to be developed on consumer-grade hardware (32GB RAM, RTX 4070 Ti Super) but architected for production deployment on server infrastructure with higher resource availability. The architecture supports distributed deployment where GPU/VRAM-intensive services (LLM inference) can run on dedicated hardware separate from core SIEM services.

The current landscape lacks an open-source SIEM that deeply integrates local LLMs via Model Context Protocol (MCP) for privacy-centric threat analysis without relying on external cloud AI providers. O.A.S.I.S. fills this gap with a security-first, multi-tenant architecture designed for both managed security service providers (MSSPs) and enterprise security operations centers (SOCs).

## What Changes

### Phase 1: Foundation (Weeks 1-7+)

#### Core Infrastructure (Weeks 1-3)
- Initialize monorepo structure with proper governance (LICENSE, CONTRIBUTING.md, SECURITY.md)
- Set up Docker Compose environment with three database systems:
  - ClickHouse for columnar log storage with per-tenant tables (high compression)
  - PostgreSQL for application data (tenants, users, API keys, configuration, audit logs)
  - Qdrant for semantic search vectors (prepared for Phase 3)
- Establish three-subnet architecture (DMZ, Internal, Backend) for defense in depth
- Implement DMZ gateway services (external + internal) with smart security controls
- Integrate Vector agent for endpoint log collection (Windows/Linux/macOS)
- Support syslog ingestion (UDP 514, TCP 514, TLS 6514)
- Implement ingestion service with OCSF normalization pipeline
- Implement separate API service for queries and configuration management
- Set up CI/CD with security scanning (SBOM generation, vulnerability scanning, secret detection)

#### Multi-Tenancy & Security (Weeks 1-3)
- Table-per-tenant data isolation in ClickHouse
- Auto-create "Internal" tenant for SOC's own log collection
- API key-based authentication for log ingestion (1:1 tenant-to-key mapping)
- JWT-based authentication for web portals
- RBAC system with four roles: Super Admin, Internal SOC, SOC Operator, Tenant User
- Complete audit logging for all configuration changes
- Self-signed certificate management with UI-based regeneration

#### Web Frontend - SOC Portal (Weeks 1-7+)
**Phase 1A (Weeks 1-3):**
- Basic authentication and authorization
- Tenant management (CRUD operations)
- API key display and regeneration with confirmation
- System health dashboard with service status
- Basic log viewer with filtering

**Phase 1B (Weeks 4-6):**
- Certificate management UI (per-service display and regeneration)
- RBAC management (user creation, role assignment, tenant assignment)
- Tenant-level configuration (retention policies, rate limits, alert settings)
- Global system configuration (database connections, gateway endpoints, rate limiting)
- Re-authentication requirement for sensitive operations (password/TOTP)

**Phase 1C (Week 7+):**
- Advanced configuration UI (OCSF normalization rules, SMTP settings, backup schedules)
- Infrastructure configuration (Docker resource limits, network settings)
- Database migration triggers
- Configuration import/export
- Enhanced audit log viewer with filtering

### Technical Foundation

**Repository Structure:**
- Monorepo with clear separation: `/backend`, `/frontend`, `/infrastructure`, `/docs`
- Vector agent configuration examples in `/infrastructure/vector/`
- Git workflow with feature branches and Conventional Commits
- CI/CD via GitHub Actions with security scanning

**Backend Services:**
- Python 3.11+ with FastAPI for both ingestion and API services
- Separate services: ingestion-service (log processing), api-service (queries/config)
- Database authentication for all services with least-privilege access
- mTLS between gateways and ingestion service
- TLS between portals and API service

**Frontend:**
- Next.js 14+ with React, TypeScript, and Tailwind CSS
- Single codebase with separate deployment configs for SOC vs Customer portals
- SOC Portal (Phase 1), Customer Portal (Phase 2)

**Log Collection:**
- Vector agents (examples included, binary downloaded from official source)
- Syslog (UDP/TCP/TLS)
- Direct HTTP/JSON to gateway endpoints

**Data Standards:**
- OpenSpec for API definitions
- OCSF (Open Cybersecurity Schema Framework) for log normalization

**Development Constraints:**
- Hardware: 32GB RAM, 2TB NVMe
- Platform: Ubuntu 24.04 LTS
- Production: Scalable server infrastructure with flexible resource allocation

**Deployment Architecture:**
- Three-subnet model: DMZ (gateways, customer portal), Internal (SOC portal, internal gateway), Backend (services, databases)
- Distributed deployment support: GPU services isolated in separate containers/instances
- Gateway scalability: Multiple gateways behind load balancer (architecture documented, single gateway in Phase 1)

## Impact

### New Capabilities

- **api-gateway** (NEW): Smart ingestion gateways (external + internal) with API key authentication, rate limiting, and input validation
- **api-service** (NEW): REST API service for authentication, log queries, and comprehensive configuration management
- **data-ingestion**: Log reception from gateways, OCSF normalization, routing to storage
- **log-storage**: Multi-tier storage with per-tenant table isolation in ClickHouse, PostgreSQL for app data, Qdrant preparation
- **web-frontend**: Comprehensive SOC portal with three-phase configuration UI, customer portal architecture (Phase 2)
- **ai-intelligence**: MCP infrastructure preparation with distributed GPU deployment support (no LLM integration in Phase 1)

### Infrastructure

**Development Environment:**
- Docker Compose environment (32GB RAM constraint)
- Single-host deployment with all services co-located
- Self-signed certificates for mTLS/TLS

**Production Environment:**
- Three-subnet architecture for defense in depth
- Multi-host capable (services can span hosts on same backend subnet)
- Distributed service model for GPU/VRAM workloads (separate container/instance/bare-metal deployment)
- Load balancer support for gateway scalability

**CI/CD Pipeline:**
- GitHub Actions workflows (lint, test, security scan, build)
- SBOM generation (Syft)
- Vulnerability scanning (Trivy)
- Secret detection (gitleaks)
- 80% minimum code coverage requirement
- Docker image builds and push to GitHub Container Registry (ghcr.io)
- Dependabot for monthly dependency updates

**Repository Governance:**
- Git workflow documented (feature branches, Conventional Commits, PR requirements)
- Branch protection on `main` and `develop` (require 1 approval)
- CODEOWNERS file for automatic PR assignment
- SECURITY.md for vulnerability reporting

**Vector Agent Integration:**
- Example configurations for Windows Event Logs, Linux syslog, systemd journal, macOS unified logging, Docker logs
- Documentation for deployment and gateway endpoint configuration
- Configuration files in `/infrastructure/vector/` directory

### Multi-Tenancy

**Data Isolation:**
- ClickHouse: Separate table per tenant (`logs_{tenant_uuid}`)
- PostgreSQL: Tenant-scoped data with foreign key relationships
- Audit logging tracks all operations with tenant context

**Tenant Management:**
- Auto-creation of "Internal" tenant on system initialization
- CRUD operations via SOC Portal
- Per-tenant configuration (retention policy, rate limits, alert settings)
- 1:1 API key to tenant relationship
- API key regeneration with confirmation prompt

**RBAC Model:**
- **Super Admin**: Full system access, all tenants, configuration management
- **Internal SOC**: Access to "Internal" tenant only (for SOC's own logs)
- **SOC Operator**: Access to all external (customer) tenants, no internal tenant access
- **Tenant User**: Access to assigned tenant(s) only (Phase 2 - customer portal)

### Security

**Network Segmentation:**
- DMZ Subnet: External gateway (internet-facing), customer portal (Phase 2)
- Internal Subnet: Internal gateway (corporate network), SOC portal
- Backend Subnet: Ingestion service, API service, databases (multi-host capable)

**Authentication:**
- Gateways: API key authentication (per-tenant keys)
- Web Portals: JWT tokens (separate routes for SOC vs tenant login)
- Databases: Username/password per service (least privilege)

**Encryption:**
- mTLS: Gateways ↔ Ingestion Service
- TLS: Portals ↔ API Service
- TLS: Database connections

**Certificate Management:**
- Self-signed certificates for Phase 1
- UI-based regeneration with immediate service restart
- Per-service certificate display (friendly name, fingerprint, validity dates)
- External certificate support deferred to IMPROVEMENTS.md

**Audit Trail:**
- PostgreSQL audit log table tracking all CRUD operations
- User attribution (who performed action)
- Before/after values for configuration changes
- Timestamp, IP address, user agent
- Sensitive operations (certificate regeneration, API key regeneration, user deletion)

### Out of Scope for Phase 1

- Customer Portal (Phase 2)
- LLM/MCP integration (Phase 3)
- Alert engine and automated triage (Phase 4)
- Reporting modules (Phase 4)
- Advanced search and semantic queries (Phase 3)
- User access audit trail (who viewed which tenant) - IMPROVEMENTS.md
- Multi-factor authentication (TOTP, Passkeys) - IMPROVEMENTS.md
- Rolling certificate restart (zero downtime) - IMPROVEMENTS.md
- External certificate support (Let's Encrypt, corporate PKI) - IMPROVEMENTS.md

### Performance Targets

**Development:**
- Operate within 32GB RAM constraint
- Single-host Docker Compose deployment

**Production:**
- Scalable to server infrastructure with appropriate resource allocation
- Recommended minimums:
  - Small (< 10k EPS): 64GB RAM, 16 cores, 1TB SSD, optional GPU server
  - Medium (10k-50k EPS): 128GB RAM, 32 cores, 2TB NVMe, recommended GPU server
  - Large (50k+ EPS): Distributed ClickHouse cluster, load-balanced gateways, GPU server farm
- Foundation for 50k EPS (Events Per Second) ingestion rate
- Database schemas optimized for write-heavy workloads
- GPU/VRAM services deployable on dedicated hardware for optimal performance

**Performance Baselines:**
- Ingestion latency: p99 < 100ms per log event
- Query response time: p95 < 2s for last 24h queries
- Gateway rate limiting: Per-tenant configurable (default 1000 EPS)
- API rate limiting: Global and per-tenant configurable

### Breaking Changes

None - this is the initial implementation.

### Database Schema Highlights

**PostgreSQL:**
- `tenants`: Tenant metadata, retention policies, rate limits
- `api_keys`: 1:1 relationship with tenants, key hash storage
- `users`: Username, email, password hash, role, user type (internal/external)
- `user_tenant_assignments`: Many-to-many for Tenant User role
- `audit_log`: Complete audit trail with user attribution
- `system_config`: Key-value store for system-wide configuration
- `certificates`: Per-service certificate storage with metadata

**ClickHouse:**
- Dynamic table creation per tenant: `logs_{tenant_uuid}`
- Partitioned by month (YYYYMM) for efficient TTL and querying
- Ordered by (timestamp, severity, category) for optimized queries
- TTL based on per-tenant retention policy

**Qdrant (Phase 3):**
- Collection: `log_embeddings` (dimension: 768 for Llama-3)
- Payload: event_id, timestamp, tenant_id, metadata

### Network Ports

| Service | Subnet | Port | Protocol | Purpose |
|---------|--------|------|----------|---------|
| External Gateway | DMZ | 443 | HTTPS | Vector agents, HTTP logs |
| External Gateway | DMZ | 514 | UDP/TCP | Syslog |
| External Gateway | DMZ | 6514 | TCP/TLS | Syslog over TLS |
| Customer Portal | DMZ | 443 | HTTPS | Tenant user access (Phase 2) |
| Internal Gateway | Internal | 443 | HTTPS | Vector agents, HTTP logs |
| Internal Gateway | Internal | 514 | UDP/TCP | Syslog |
| Internal Gateway | Internal | 6514 | TCP/TLS | Syslog over TLS |
| SOC Portal | Internal | 443 | HTTPS | SOC team access |
| Ingestion Service | Backend | 8080 | HTTP/mTLS | Gateway → Ingestion |
| API Service | Backend | 8000 | HTTP/TLS | Portal → API |
| ClickHouse | Backend | 9000 | Native (Auth) | Database access |
| PostgreSQL | Backend | 5432 | Native (Auth) | Database access |
| Qdrant | Backend | 6333 | HTTP (API Key) | Vector DB (Phase 3) |

## Phase 1 Complexity Metrics

- **Requirements**: ~60 across 6 capabilities (api-gateway, api-service, data-ingestion, log-storage, web-frontend, ai-intelligence)
- **Tasks**: ~150 tasks across 12 sections
- **Docker Services**: 7 services in Phase 1 (2 gateways, ingestion, API, 3 databases)
- **Network Subnets**: 3 (DMZ, Internal, Backend)
- **RBAC Roles**: 4 (Super Admin, Internal SOC, SOC Operator, Tenant User)
- **Configuration UI Phases**: 3 (1A: Weeks 1-3, 1B: Weeks 4-6, 1C: Week 7+)

## Risk Mitigation

### Gateway Complexity
**Risk**: Two gateway services add operational overhead  
**Mitigation**: Start with single gateway, add scalability documentation for Phase 2+

### Multi-Tenancy Isolation
**Risk**: Table-per-tenant requires dynamic schema management  
**Mitigation**: Thorough testing, migration scripts, automated tenant creation workflow

### Configuration UI Scope
**Risk**: Extensive UI requirements may delay Phase 1  
**Mitigation**: Three-phase approach (1A/1B/1C) prioritizes operational features

### Certificate Management
**Risk**: Self-signed cert regeneration requires service restarts (downtime)  
**Mitigation**: Document downtime expectations, plan rolling restarts for Phase 2+

### Database Credentials
**Risk**: Multiple service accounts, potential for misconfiguration  
**Mitigation**: Configuration UI, clear documentation, validation checks
