# Design: O.A.S.I.S. Phase 1 Architecture

## Context

O.A.S.I.S. is an open-source AI-driven SIEM platform designed for development on consumer-grade hardware and production deployment on server infrastructure. Phase 1 establishes the foundational infrastructure for log ingestion, storage, and basic visualization.

**Key Constraints:**
- Development Hardware: 32GB RAM, Intel i9-12900k, RTX 4070 Ti Super (16GB VRAM)
- Production: Scalable server infrastructure with flexible resource allocation
- Privacy-first: Local processing, no external cloud dependencies
- Performance: Foundation for 50k EPS ingestion rate
- Scalability: Architecture must support single-machine development and distributed production deployments
- Distributed GPU: Services requiring VRAM must be deployable separately (container, instance, or bare-metal)

**Stakeholders:**
- SOC Analysts: Need fast, intuitive log search and analysis
- Security Engineers: Require reliable ingestion and data integrity
- System Administrators: Need easy deployment and maintenance
- Open Source Community: Require clear architecture and contribution paths

## Goals / Non-Goals

### Goals
1. Establish multi-tier storage architecture optimized for security logs
2. Implement OCSF normalization for vendor-agnostic log processing
3. Create Docker-based development environment for easy onboarding (32GB constraint)
4. Design production architecture for scalable server deployment
5. Build foundation for future AI/MCP integration (Phase 3) with distributed GPU support
6. Integrate open-source log collection (syslog-ng) to reduce development overhead
7. Establish security best practices from day one

### Non-Goals (Deferred to Later Phases)
- LLM/MCP integration (Phase 3)
- Alert engine and automated response (Phase 4)
- Advanced analytics and correlation (Phase 4)
- Multi-tenancy and RBAC (Phase 2-3)
- Cloud deployment configurations (Post-initial release)
- Custom endpoint agents (Out of scope - use existing shippers)

## Decisions

### Decision 1: Multi-Tier Storage Architecture
**Choice:** ClickHouse (logs) + Qdrant (vectors) + PostgreSQL (app data)

**Rationale:**
- **ClickHouse**: Columnar storage provides 10-20x compression for log data. Optimized for write-heavy workloads and analytical queries. Scales well in production environments.
- **Qdrant**: Purpose-built for vector similarity search, needed for semantic search and future LLM features. Rust-based for performance. Can run on separate instance.
- **PostgreSQL**: Reliable ACID compliance for critical application data (users, alerts, configurations). Well-understood operational model.

**Alternatives Considered:**
- Single database (PostgreSQL): Rejected - insufficient compression and query performance for log volumes
- Elasticsearch: Rejected - higher memory overhead (~2GB baseline + data), JVM management complexity
- SQLite for app data: Rejected - need concurrent access for future multi-process architecture

**Trade-offs:**
- Operational complexity: Three databases vs. one
- Mitigation: Docker Compose abstracts complexity for development; production can use managed services

### Decision 2: OCSF for Log Normalization
**Choice:** Implement Open Cybersecurity Schema Framework (OCSF) v1.0+

**Rationale:**
- Vendor-neutral standard backed by AWS, Splunk, and others
- Eliminates N×M mapping problem (N sources × M analytics)
- Future-proof: Growing industry adoption
- Rich taxonomy for security events (authentication, network, file, process events)

**Alternatives Considered:**
- ECS (Elastic Common Schema): Rejected - tied to Elastic ecosystem, less comprehensive for security
- Custom schema: Rejected - reinventing the wheel, poor interoperability
- Raw log storage only: Rejected - makes analytics and AI processing significantly harder

**Trade-offs:**
- Development effort: Requires building/maintaining normalization mappings
- Mitigation: Start with 5-10 common log sources (Syslog, Windows Event Log, Linux auditd, firewall logs)

### Decision 3: Python/FastAPI for Backend
**Choice:** Python 3.11+ with FastAPI framework

**Rationale:**
- FastAPI: Modern async framework, auto-generated OpenAPI docs, high performance
- Python ecosystem: Rich libraries for security (cryptography, pydantic), LLM integration (Ollama, MCP)
- Async support: Critical for handling high ingestion rates without blocking
- Type hints: Pydantic models provide runtime validation and documentation

**Alternatives Considered:**
- Go: Rejected for Phase 1 - lower LLM/AI library support, team familiarity trade-off
- Node.js: Rejected - Python better suited for data processing and AI integration
- Rust: Rejected - longer development time, premature optimization

**Note:** Go remains an option for specific performance-critical services in later phases.

**Trade-offs:**
- Performance ceiling: Lower than Go/Rust
- Mitigation: Python async + proper architecture supports target 50k EPS; can rewrite bottlenecks later

### Decision 4: Next.js for Frontend
**Choice:** Next.js 14+ with React, TypeScript, and Tailwind CSS

**Rationale:**
- Server-side rendering: Better initial load times for dashboards
- API routes: Simplified backend-for-frontend pattern
- TypeScript: Type safety across frontend codebase
- Tailwind: Rapid UI development, consistent design system
- Rich ecosystem: Chart libraries (Recharts), table components (TanStack Table)

**Alternatives Considered:**
- Svelte/SvelteKit: Rejected - smaller ecosystem for security/dashboard components
- Vue.js: Rejected - team familiarity with React ecosystem
- Plain React (CRA/Vite): Rejected - missing SSR and routing optimizations

### Decision 5: Monorepo Structure
**Choice:** Single repository with `/backend`, `/frontend`, `/infrastructure`

**Rationale:**
- Atomic changes: API and UI changes in single commit
- Simplified dependency management for shared types/schemas
- Easier onboarding: Clone once, see everything
- CI/CD simplification: Single pipeline for all components

**Structure:**
```
/
├── backend/          # Python/FastAPI services
│   ├── ingestion/    # Log ingestion service
│   ├── api/          # REST API
│   ├── common/       # Shared utilities
│   └── tests/
├── frontend/         # Next.js application
│   ├── src/
│   ├── public/
│   └── tests/
├── infrastructure/   # Docker, Kubernetes, Terraform
│   ├── docker/
│   ├── scripts/
│   └── configs/
├── docs/            # Documentation
└── openspec/        # API specifications
```

**Alternatives Considered:**
- Polyrepo (separate repos per service): Rejected - coordination overhead for small team
- Microservices from day one: Rejected - premature complexity

### Decision 6: Docker Compose for Development
**Choice:** Docker Compose for local development environment

**Rationale:**
- Consistent environments: "Works on my machine" problem eliminated
- Easy onboarding: `docker-compose up` starts entire stack
- Service isolation: Database versions locked, no port conflicts
- Production parity: Same container images for dev and production

**Configuration:**
- Resource limits per container (e.g., ClickHouse: 8GB, PostgreSQL: 2GB)
- Named volumes for data persistence
- Health checks for service dependencies
- Bind mounts for hot-reload during development

### Decision 7: Security Hardening from Day One
**Choice:** Non-root containers, AppArmor/Seccomp profiles, automated scanning

**Rationale:**
- Dogfooding: SIEM platform must demonstrate security best practices
- Early prevention: Easier to build securely than retrofit
- Compliance: Prepares for future SOC 2/ISO 27001 considerations

**Implementation:**
- All containers run as non-root (UID 1000+)
- Secrets via environment variables (never committed)
- SBOM generation in CI (Syft)
- Vulnerability scanning (Trivy) with PR blocking for HIGH/CRITICAL
- TLS for all inter-service communication (development: self-signed, production: Let's Encrypt)

### Decision 8: Vector Agent for Endpoint Collection
**Choice:** Vector (vector.dev) for endpoint log collection + traditional syslog support for network devices

**Rationale:**
- **Cross-platform endpoint agent**: Single agent for Windows, Linux, macOS (reduces development overhead vs. building custom agents)
- **Modern architecture**: Rust-based, high performance, low memory footprint (~50MB)
- **Unified telemetry**: Logs, metrics, and traces in one agent (future-proof for observability expansion)
- **Rich ecosystem**: 100+ built-in sources (Windows Event Log, Linux systemd, macOS Unified Log, Docker, Kubernetes)
- **Powerful transforms**: Built-in parsing (JSON, CSV, regex), enrichment, filtering, and sampling
- **Multiple outputs**: Can send to multiple destinations simultaneously (O.A.S.I.S. + backup)
- **Reliability**: Built-in buffering, retries, and delivery guarantees
- **Syslog compatibility**: Still accept syslog from network devices (firewalls, switches, routers) via gateway

**Alternatives Considered:**
- syslog-ng: Initially chosen, but rejected - limited to syslog protocol, no native Windows Event Log or macOS support
- Custom agents: Rejected - significant development time for multi-platform support, reinventing the wheel
- Fluentd: Rejected - Ruby-based (higher memory), plugin quality inconsistent
- Logstash: Rejected - JVM overhead, tighter Elastic ecosystem coupling
- Filebeat: Rejected - tighter Elastic coupling, less flexible transform capabilities

**Deployment Model:**
- **Endpoints** (workstations, servers): Vector agent installed via package manager or Windows MSI
- **Network devices** (firewalls, switches): Traditional syslog (RFC 3164/5424) to gateway
- **Containers**: Vector as sidecar or Docker socket source
- **Gateway**: Receives Vector metrics output (HTTP/JSON) and syslog (UDP/TCP/TLS)

**Trade-offs:**
- Learning curve: Vector configuration uses TOML (different from syslog-ng)
- Mitigation: Provide templated configs for common scenarios (see VECTOR_EXAMPLES/)
- Agent deployment: Requires installing agents on endpoints
- Mitigation: Provide installation scripts, MSI packages, and deployment automation examples

### Decision 9: DMZ Gateway Architecture with Multi-Tenancy
**Choice:** Three-subnet architecture with smart gateways for API authentication and rate limiting

**Network Topology:**
```
DMZ Subnet (Internet-facing):
  - External Gateway (Port 443, 514, 6514)
  - Customer Portal (Port 443, Phase 2)

Internal Subnet (Corporate network):
  - Internal Gateway (Port 443, 514, 6514)
  - SOC Portal (Port 443)

Backend Subnet (Database tier):
  - Ingestion Service (Port 8080, mTLS from gateways)
  - API Service (Port 8000, TLS from portals)
  - ClickHouse (Port 9000, authentication required)
  - PostgreSQL (Port 5432, authentication required)
  - Qdrant (Port 6333, Phase 3)
```

**Rationale:**
- **Defense in depth**: Multiple security boundaries (DMZ → Internal → Backend)
- **Tenant isolation**: External customers can't reach internal corporate network
- **Smart gateways**: Not just proxies - perform API key authentication, rate limiting, input validation before forwarding to backend
- **Scalability**: Multiple gateways behind load balancer (architecture documented, single gateway for Phase 1)
- **Compliance**: Separation aligns with PCI DSS, SOC 2 network segmentation requirements
- **Multi-tenancy**: Each tenant has isolated data (separate ClickHouse tables), unique API keys

**Gateway Responsibilities:**
- API key authentication (validate before forwarding)
- Rate limiting per tenant (configurable limits)
- Input validation (size limits, schema validation)
- TLS termination (external) and mTLS initiation (to backend)
- Health checks and circuit breakers
- Request logging for audit trail

**Multi-Tenancy Model:**
- **Table-per-tenant in ClickHouse**: `logs_{tenant_uuid}` (NOT shared table with tenant_id column)
- **Auto-create "Internal" tenant**: Created on first startup for SOC use
- **API keys**: 1:1 relationship with tenant, regenerable via UI with confirmation
- **Data isolation**: Queries scoped to tenant tables, no cross-tenant leakage possible

**Alternatives Considered:**
- Flat network: Rejected - no defense in depth, all services exposed
- Shared ClickHouse table with tenant_id: Rejected - risk of query bugs exposing cross-tenant data
- API key auth in ingestion service: Rejected - backend services shouldn't handle untrusted input directly

**Trade-offs:**
- Network complexity: Three subnets vs. flat network
- Mitigation: Docker networks abstract complexity for development; production uses VLANs/security groups
- Gateway as SPOF: Single gateway failure blocks ingestion
- Mitigation: Load balancer with health checks, multiple gateway instances (Phase 2)

### Decision 10: Separate API Service from Ingestion Service
**Choice:** Two backend services with distinct responsibilities

**Service Boundaries:**
- **ingestion-service** (Port 8080):
  - Accepts logs from gateways (post-authentication)
  - OCSF normalization
  - Writes to ClickHouse and future Qdrant
  - No direct internet/user access
  - Optimized for write throughput
  
- **api-service** (Port 8000):
  - User authentication (JWT)
  - Log query API with tenant isolation
  - Configuration management (tenants, API keys, retention policies)
  - Audit logging for all CRUD operations
  - Serves SOC Portal and Customer Portal
  - Optimized for read queries and low-latency responses

**Rationale:**
- **Separation of concerns**: Write path (ingestion) vs. read path (queries)
- **Independent scaling**: Scale ingestion horizontally for bursts, scale API for concurrent users
- **Security**: Ingestion service never exposed to users, only to authenticated gateways
- **Performance isolation**: Heavy write workload doesn't impact user query responsiveness
- **Development velocity**: Teams can work on ingestion and API independently

**Alternatives Considered:**
- Monolithic service: Rejected - write/read workloads compete for resources, harder to scale independently
- Ingestion in gateway: Rejected - normalization is CPU-intensive, keep gateways lightweight

**Trade-offs:**
- Operational complexity: Two services vs. one
- Mitigation: Shared Python library for common code (database clients, OCSF models)

### Decision 11: Database Authentication for All Connections
**Choice:** Username/password authentication for all service-to-database connections

**Implementation:**
- **ClickHouse**: Create service accounts (`ingestion_user`, `api_user`) with specific grants
- **PostgreSQL**: Create service accounts with role-based permissions
- **Credentials**: Stored in environment variables (`.env` for dev, secrets manager for production)
- **Principle of least privilege**: `ingestion_user` has INSERT only, `api_user` has SELECT only

**Rationale:**
- **Audit trail**: Know which service performed which database operation
- **Blast radius reduction**: Compromised API service can't write to logs, compromised ingestion can't read user data
- **Compliance**: SOC 2, ISO 27001 require database access controls
- **Production security**: Default ClickHouse/PostgreSQL installations with no auth are insecure

**Alternatives Considered:**
- No authentication (default ClickHouse): Rejected - unacceptable security risk
- Shared credentials: Rejected - can't trace which service performed action
- Certificate-based auth: Considered for future, username/password sufficient for Phase 1

**Trade-offs:**
- Configuration complexity: More credentials to manage
- Mitigation: Environment variables with clear naming (`CLICKHOUSE_INGESTION_USER`, etc.)

### Decision 12: Self-Signed Certificate Management with UI
**Choice:** Auto-generated self-signed TLS certificates with web UI management

**Implementation:**
- **First startup**: Automatically generate self-signed CA and certificates for all services
- **Storage**: Certificates stored in PostgreSQL `certificates` table (PEM format)
- **Rotation**: SOC Admin can regenerate certificates via web UI with confirmation modal
- **Service restart**: Immediate restart of affected services after certificate regeneration (containers restart via Docker API)
- **mTLS**: Gateways → backend services (mutual authentication)
- **TLS**: Portals → API service (server authentication only)

**Certificate Types:**
- **CA Certificate**: Root CA for signing service certificates
- **Gateway Certificate**: For external and internal gateways
- **Ingestion Service Certificate**: mTLS server certificate
- **API Service Certificate**: TLS server certificate
- **Portal Certificates**: TLS server certificates for SOC/Customer portals

**Web UI Features (Phase 1B):**
- View certificate details (issuer, expiration, serial number)
- Download certificates (for configuring Vector agents to trust CA)
- Regenerate certificates (requires password re-authentication + TOTP)
- Certificate status indicators (valid, expiring soon <30 days, expired)

**Rationale:**
- **No external dependencies**: Works in air-gapped environments, no Let's Encrypt dependency
- **Developer experience**: No manual certificate generation required
- **Production ready**: Can replace with external CA certificates in production (future: import custom certs)
- **Immediate rotation**: No manual service restarts, UI triggers container restart via Docker API

**Alternatives Considered:**
- Let's Encrypt: Rejected for Phase 1 - requires public DNS, doesn't work in air-gapped or internal-only deployments
- Manual certificate generation: Rejected - poor developer experience, error-prone
- External CA required: Rejected - increases deployment complexity for self-hosted users

**Trade-offs:**
- Self-signed certificates: Browsers show warnings for portals
- Mitigation: Documentation for importing CA into browser trust store; Phase 2 can add Let's Encrypt support
- Certificate storage in database: Database compromise exposes private keys
- Mitigation: Acceptable for Phase 1; Phase 3 can migrate to HashiCorp Vault or AWS Secrets Manager

### Decision 13: Comprehensive Audit Logging
**Choice:** Audit all CRUD operations and sensitive actions to PostgreSQL `audit_logs` table

**Scope of Audit Logging:**
- Tenant CRUD (create, update, delete)
- API key generation/regeneration/deletion
- Certificate regeneration
- User authentication (login, logout, failed attempts)
- RBAC changes (role assignments, permission changes)
- System configuration changes (retention policies, rate limits, SMTP settings)
- Log query API calls (who queried what, when, result count)

**Audit Log Schema:**
```sql
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id INTEGER REFERENCES users(id),
    tenant_id UUID REFERENCES tenants(id),
    action VARCHAR(50) NOT NULL,  -- e.g., 'tenant.create', 'apikey.regenerate'
    resource_type VARCHAR(50),     -- e.g., 'tenant', 'apikey', 'certificate'
    resource_id VARCHAR(255),      -- UUID or identifier of affected resource
    ip_address INET,
    user_agent TEXT,
    request_method VARCHAR(10),
    request_path TEXT,
    status_code INTEGER,
    metadata JSONB                 -- Action-specific data (e.g., old vs. new values)
);
```

**Retention:**
- Audit logs retained for 1 year minimum (configurable)
- Separate retention policy from security logs (ClickHouse)

**UI Features:**
- Audit log viewer in SOC Portal (Phase 1B)
- Filter by user, tenant, action, date range
- Export to CSV for compliance reporting

**Rationale:**
- **Compliance**: SOC 2, ISO 27001, HIPAA require audit trails
- **Incident response**: Trace actions during security incidents
- **Accountability**: Non-repudiation for sensitive actions
- **Debugging**: Understand system state changes over time

**Alternatives Considered:**
- No audit logging: Rejected - compliance and security requirement
- Audit logs in ClickHouse: Rejected - ACID compliance needed, PostgreSQL better suited
- External SIEM: Rejected - O.A.S.I.S. should audit itself (dogfooding)

**Trade-offs:**
- Storage overhead: Audit logs grow over time
- Mitigation: Partition by month, separate retention policy from security logs

### Decision 14: Three-Phase Configuration UI Approach
**Choice:** Iterative UI development with prioritized features across three sub-phases

**Phase 1A (Weeks 1-3): Core Multi-Tenancy**
- Tenant CRUD (create, list, edit, delete with confirmation)
- API key management (view, regenerate with confirmation)
- Health dashboard (service status, resource usage, ingestion rate)

**Phase 1B (Weeks 4-6): Security & Configuration**
- Certificate management (view, download, regenerate)
- RBAC management (assign roles, view permissions)
- Retention policies (configure per-tenant or global)
- Rate limits (configure per-tenant)

**Phase 1C (Week 7+): Advanced System Configuration**
- Database connection strings (ClickHouse, PostgreSQL)
- SMTP settings (email notifications for alerts)
- Backup/restore UI (trigger backups, restore from backup)
- Docker resource limits (adjust container memory/CPU via UI)
- Audit log viewer (filter, export CSV)

**Re-authentication Requirement:**
- All system configuration changes (Phase 1C) require password re-entry + TOTP
- Prevents unauthorized changes if session hijacked or admin leaves workstation unlocked

**Rationale:**
- **Progressive disclosure**: Don't overwhelm users with all config options at once
- **MVP focus**: Phase 1A delivers core value (multi-tenancy), later phases add polish
- **Risk management**: Security-critical features (certificates, RBAC) in Phase 1B after core proven
- **Feedback-driven**: Iterate on UX based on Phase 1A user feedback

**Alternatives Considered:**
- All configuration in Phase 1: Rejected - too much scope, delays initial release
- Configuration files only: Rejected - poor UX, requires SSH access and service restarts

**Trade-offs:**
- Feature fragmentation: Users get partial functionality in Phase 1A
- Mitigation: Clear roadmap communicated, each sub-phase delivers usable feature set

### Decision 9: Distributed GPU/VRAM Service Architecture
**Choice:** Design AI/LLM services to run in separate containers, instances, or bare-metal hardware

**Rationale:**
- **Hardware flexibility**: Organizations can dedicate GPU servers for LLM inference while running core SIEM on CPU-only infrastructure
- **Cost optimization**: GPU resources expensive; allow selective scaling
- **Development/production parity**: Develop without GPU on 32GB workstation, deploy with GPU in production
- **Resource isolation**: GPU workloads don't compete with database/ingestion for memory/CPU
- **Technology evolution**: Easy to upgrade GPU hardware without touching core SIEM infrastructure

**Architecture Design:**
- **Service communication**: REST API + message queue (Redis/RabbitMQ) between core and GPU services
- **Deployment options**:
  1. Single-host: Ollama + MCP in Docker with GPU passthrough (development)
  2. Separate container: Ollama on same Docker host, different network
  3. Separate instance: Ollama on different server, networked via secure API
  4. Bare-metal: Ollama on dedicated GPU workstation/server with direct hardware access
- **Network security**: Mutual TLS for inter-service communication, API key authentication
- **Graceful degradation**: Core SIEM functions (ingestion, search, alerting) work without GPU services; AI features return "service unavailable" when GPU offline

**Service Boundaries:**
- **Core SIEM**: Ingestion, storage, query API, web UI (runs anywhere, no GPU required)
- **AI Services**: Ollama (LLM inference), embedding generation, MCP server (requires VRAM)

**Configuration:**
- Environment variables define AI service endpoints (e.g., `OLLAMA_API_URL=http://gpu-server:11434`)
- Docker Compose profiles: `default` (no GPU), `gpu-dev` (local GPU), `gpu-remote` (external GPU service)
- Kubernetes: Node affinity for GPU workloads with dedicated node pools

**Trade-offs:**
- Network latency: Remote GPU adds 1-10ms latency vs. local
- Mitigation: Async processing for most AI tasks; only interactive chat requires low latency
- Operational complexity: More deployment permutations to test
- Mitigation: Clear documentation, Docker Compose profiles for common scenarios

## Data Flow

### Ingestion Flow (Write Path)
```
Endpoint (Vector agent) → External/Internal Gateway → Ingestion Service → OCSF Normalization → Router
                                                        ↓                                          ├→ ClickHouse (logs_{tenant_uuid})
                                                    API Key Auth                                   └→ Qdrant (future: embeddings)
                                                    Rate Limit
                                                    Input Validation

Network Device (Syslog) → Gateway (UDP/TCP 514, TLS 6514) → Ingestion Service → ClickHouse
```

**Flow Details:**
1. Vector agent sends HTTP/JSON to gateway (port 443) with API key header
2. Gateway validates API key, checks rate limit, validates payload size/schema
3. Gateway forwards to ingestion-service (port 8080) via mTLS
4. Ingestion service normalizes to OCSF, writes to tenant-specific ClickHouse table
5. Future: Generate embeddings and write to Qdrant (Phase 3)

### Query Flow (Read Path)
```
User → SOC Portal (Port 443) → API Service (Port 8000) → PostgreSQL (auth) → ClickHouse (tenant-scoped query) → Response
                                      ↓
                                  JWT Validation
                                  Tenant Isolation
                                  Audit Logging
```

**Flow Details:**
1. User authenticates via SOC Portal (username/password + TOTP)
2. API service issues JWT with tenant_id claim
3. User queries logs via API with JWT in Authorization header
4. API service validates JWT, extracts tenant_id, queries `logs_{tenant_uuid}` table
5. Results returned to portal, query logged to audit_logs table

### Configuration Management Flow
```
SOC Admin → SOC Portal → API Service → PostgreSQL (config tables) → Docker API (restart services if needed)
                              ↓
                        Re-authentication (password + TOTP)
                        Audit Logging
```

**Example: Certificate Regeneration**
1. Admin clicks "Regenerate Gateway Certificate" in UI
2. Portal prompts for password + TOTP re-authentication
3. API service validates credentials, generates new certificate
4. New certificate written to PostgreSQL `certificates` table
5. API service calls Docker API to restart gateway containers
6. Action logged to `audit_logs` table

### Future AI Flow (Phase 3+) - Distributed Architecture
```
User Query → SOC Portal → API Service → MCP Server (remote/local) → LLM (Ollama, GPU service) → Database Tools → Response
                                                                              ↓
                                                                     Runs on separate container/instance/bare-metal
```

## Network Topology

### Development Environment (Docker Networks)
```
┌─────────────────────────────────────────────────────────────┐
│ Host Machine (localhost)                                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ dmz-network (172.20.0.0/24)                          │  │
│  │   - external-gateway:443,514,6514 (Phase 1)          │  │
│  │   - customer-portal:443 (Phase 2)                    │  │
│  └─────────────────────┬────────────────────────────────┘  │
│                        │                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ internal-network (172.21.0.0/24)                     │  │
│  │   - internal-gateway:443,514,6514                    │  │
│  │   - soc-portal:443                                   │  │
│  └─────────────────────┬────────────────────────────────┘  │
│                        │                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ backend-network (172.22.0.0/24)                      │  │
│  │   - ingestion-service:8080 (mTLS)                    │  │
│  │   - api-service:8000 (TLS)                           │  │
│  │   - clickhouse:9000 (auth required)                  │  │
│  │   - postgresql:5432 (auth required)                  │  │
│  │   - qdrant:6333 (Phase 3)                            │  │
│  │   - ollama:11434 (optional, GPU service)             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Port Mappings (Host → Container):**
- `0.0.0.0:443 → external-gateway:443` (external log ingestion)
- `0.0.0.0:514 → external-gateway:514` (syslog UDP)
- `0.0.0.0:6514 → external-gateway:6514` (syslog TLS)
- `0.0.0.0:8443 → internal-gateway:443` (internal log ingestion)
- `0.0.0.0:3000 → soc-portal:443` (SOC web UI)
- All backend services on internal network only (no host exposure)

### Production Environment (Multi-Subnet)
```
┌─────────────────────────────────────────────────────────────┐
│ DMZ Subnet (Public VLAN, 10.1.0.0/24)                       │
│   - External Gateway (10.1.0.10)                            │
│   - Load Balancer (10.1.0.5) → Multiple Gateways (Phase 2) │
│   - Customer Portal (10.1.0.11, Phase 2)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ Firewall Rules:
                       │ - Allow 443,514,6514 inbound from Internet
                       │ - Allow outbound to Internal Subnet on port 8080 (mTLS)
┌─────────────────────────────────────────────────────────────┐
│ Internal Subnet (Corporate VLAN, 10.2.0.0/24)               │
│   - Internal Gateway (10.2.0.10)                            │
│   - SOC Portal (10.2.0.11)                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ Firewall Rules:
                       │ - Allow inbound from Corporate Network
                       │ - Allow outbound to Backend Subnet on ports 8080,8000
┌─────────────────────────────────────────────────────────────┐
│ Backend Subnet (Database VLAN, 10.3.0.0/24)                 │
│   - Ingestion Service (10.3.0.10)                           │
│   - API Service (10.3.0.11)                                 │
│   - ClickHouse Cluster (10.3.0.20-29)                       │
│   - PostgreSQL HA (10.3.0.30-31)                            │
│   - Qdrant (10.3.0.40, Phase 3)                             │
└─────────────────────────────────────────────────────────────┘
                       │ Optional: Separate GPU Subnet
┌─────────────────────────────────────────────────────────────┐
│ GPU Subnet (Optional, 10.4.0.0/24)                          │
│   - Ollama Service (10.4.0.10)                              │
│   - MCP Server (10.4.0.11)                                  │
└─────────────────────────────────────────────────────────────┘
```

### Network Ports Summary

| Service | Port | Protocol | Purpose | Exposed To |
|---------|------|----------|---------|------------|
| External Gateway | 443 | HTTPS | Vector agent ingestion | Internet |
| External Gateway | 514 | UDP/TCP | Syslog ingestion | Internet |
| External Gateway | 6514 | TCP | Syslog over TLS | Internet |
| Internal Gateway | 443 | HTTPS | Internal log ingestion | Corporate |
| Internal Gateway | 514 | UDP/TCP | Syslog ingestion | Corporate |
| Internal Gateway | 6514 | TCP | Syslog over TLS | Corporate |
| SOC Portal | 443 | HTTPS | Web UI | Corporate |
| Customer Portal | 443 | HTTPS | Tenant web UI | Internet (Phase 2) |
| Ingestion Service | 8080 | HTTPS (mTLS) | Log processing | Gateways only |
| API Service | 8000 | HTTPS (TLS) | REST API | Portals only |
| ClickHouse | 9000 | Native | Database queries | Backend services |
| PostgreSQL | 5432 | Native | Database queries | Backend services |
| Qdrant | 6333 | HTTP | Vector search | Backend services (Phase 3) |
| Ollama | 11434 | HTTP | LLM inference | Backend services (Phase 3) |

## Database Schema Highlights

### ClickHouse: Multi-Tenant Table Isolation

**Table-per-tenant approach:**
```sql
-- Tenant: Internal (auto-created)
CREATE TABLE logs_550e8400_e29b_41d4_a716_446655440000 (
    timestamp DateTime64(3),
    event_id UUID,
    category_name String,      -- OCSF category (e.g., 'Authentication')
    class_name String,          -- OCSF class (e.g., 'Login')
    severity LowCardinality(String),
    raw_log String,
    metadata Map(String, String),
    -- Denormalized fields for common filters
    src_ip IPv4,
    dst_ip IPv4,
    user_name String,
    hostname String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, severity, category_name)
TTL timestamp + INTERVAL 90 DAY;  -- Configurable per-tenant retention

-- Additional tenants get their own tables: logs_{tenant_uuid}
```

**Rationale for table-per-tenant:**
- **Data isolation**: Query bugs can't leak data across tenants (no WHERE tenant_id clause to forget)
- **Independent retention**: Each tenant can have different retention policies
- **Performance**: No tenant_id in WHERE clause for every query, better index locality
- **Scalability**: Can move tenant tables to different ClickHouse clusters (future)

### PostgreSQL: Application Schema

**Tenants Table:**
```sql
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    retention_days INTEGER NOT NULL DEFAULT 90,
    rate_limit_eps INTEGER NOT NULL DEFAULT 10000,  -- Events per second
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Auto-create "Internal" tenant on first startup
INSERT INTO tenants (name) VALUES ('Internal') ON CONFLICT DO NOTHING;
```

**API Keys Table:**
```sql
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    key_hash VARCHAR(255) NOT NULL UNIQUE,  -- bcrypt hash of API key
    key_prefix VARCHAR(16) NOT NULL,        -- First 8 chars for display (e.g., "oasis_pk...")
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(tenant_id)  -- 1:1 relationship: one API key per tenant
);
```

**Users Table:**
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    totp_secret VARCHAR(32),  -- Base32-encoded TOTP secret
    role VARCHAR(50) NOT NULL DEFAULT 'soc_operator',  -- super_admin, internal_soc, soc_operator, tenant_user
    tenant_id UUID REFERENCES tenants(id),  -- NULL for super_admin/internal_soc
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);
```

**RBAC Roles:**
- **super_admin**: Full system access (tenant management, system config, certificate management)
- **internal_soc**: Access to Internal tenant logs, no system config
- **soc_operator**: Read-only access to Internal tenant logs
- **tenant_user**: Access to own tenant logs only (Phase 2 Customer Portal)

**Certificates Table:**
```sql
CREATE TABLE certificates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,  -- e.g., 'ca', 'external-gateway', 'ingestion-service'
    certificate_pem TEXT NOT NULL,
    private_key_pem TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    regenerated_by INTEGER REFERENCES users(id)
);
```

**Audit Logs Table:**
```sql
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id INTEGER REFERENCES users(id),
    tenant_id UUID REFERENCES tenants(id),
    action VARCHAR(50) NOT NULL,  -- e.g., 'tenant.create', 'apikey.regenerate', 'certificate.regenerate'
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    request_method VARCHAR(10),
    request_path TEXT,
    status_code INTEGER,
    metadata JSONB  -- Action-specific data
);

-- Partitioning by month for performance
CREATE INDEX idx_audit_logs_timestamp ON audit_logs (timestamp DESC);
CREATE INDEX idx_audit_logs_user ON audit_logs (user_id, timestamp DESC);
CREATE INDEX idx_audit_logs_tenant ON audit_logs (tenant_id, timestamp DESC);
```

**System Config Table:**
```sql
CREATE TABLE system_config (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by INTEGER REFERENCES users(id)
);
```

### Qdrant: Vector Collections (Phase 3)
- Collection: `log_embeddings` (dimension: 768 for Llama-3)
- Payload: event_id, tenant_id, timestamp, metadata
- **Note**: Vector search also enforces tenant isolation via payload filtering

## Performance Considerations

### Development Memory Budget (32GB Total - Development Environment Only)
- OS/System: ~4GB
- ClickHouse: 8-12GB (configurable, includes cache)
- PostgreSQL: 2GB
- Qdrant: 2GB (Phase 3)
- Ingestion Service: 1-2GB
- API Service: 1GB
- External Gateway: 512MB
- Internal Gateway: 512MB
- SOC Portal: 1GB
- Nginx (reverse proxy): 256MB
- Ollama/LLM: Disabled in development OR run on separate GPU instance
- Buffer: 3-5GB

**Total: ~24-28GB under normal load**

**Note**: This budget is for development only. Production deployments on server infrastructure are not constrained by 32GB and should be sized according to log volume and performance requirements.

### Production Resource Allocation (Recommended Minimums)

**Small Deployment** (< 10k EPS):
- **Core Services**: 64GB RAM, 16 CPU cores, 1TB SSD
  - ClickHouse: 32GB
  - PostgreSQL: 8GB
  - Ingestion Service: 8GB
  - API Service: 4GB
  - Gateways (2x): 2GB each
  - Portals: 4GB total
- **Optional GPU Server**: 24GB+ VRAM for AI features (Phase 3)

**Medium Deployment** (10k-50k EPS):
- **Core Services**: 128GB RAM, 32 CPU cores, 2TB NVMe
  - ClickHouse: 64GB
  - PostgreSQL: 16GB
  - Ingestion Service: 16GB (scale horizontally)
  - API Service: 8GB
  - Gateways (3x behind load balancer): 2GB each
  - Portals: 8GB total
- **Recommended GPU Server**: 48GB+ VRAM (A40, A6000)

**Large Deployment** (50k+ EPS):
- **Core Services**: Distributed architecture
  - ClickHouse cluster (3+ nodes, 128GB each)
  - PostgreSQL HA (primary + standby, 32GB each)
  - Load-balanced ingestion services (5+ instances, 16GB each)
  - Load-balanced API services (3+ instances, 8GB each)
  - Load-balanced gateways (5+ instances, 2GB each)
- **GPU Server Farm**: Multiple GPU servers for LLM inference (Phase 3)

### Gateway Performance Tuning

**External Gateway (Internet-facing):**
- Connection limits: 10,000 concurrent connections
- Rate limiting: Configurable per tenant (default 10k EPS)
- Request timeout: 30s
- Max request size: 10MB
- Keep-alive: 60s
- TLS 1.2+ only, modern cipher suites

**Internal Gateway (Corporate network):**
- Connection limits: 5,000 concurrent connections
- Rate limiting: Higher limits for trusted internal sources
- Request timeout: 30s
- Max request size: 10MB

### Write Optimization
- ClickHouse batch inserts (1000 rows or 5s interval)
- Async ingestion queue (Redis or in-memory for Phase 1)
- Back-pressure handling: Return HTTP 429 (Too Many Requests) when buffer full
- Gateway circuit breaker: Stop forwarding if ingestion service unhealthy

### Query Optimization
- ClickHouse materialized views for common aggregations (Phase 2)
- Query result caching (Redis - Phase 2)
- Pagination for large result sets (limit 10k rows per query)
- Query complexity limits: Max 60s execution time, kill slow queries
- API service connection pooling to ClickHouse (10 connections per process)

### API Service Performance
- FastAPI with Gunicorn (4 workers in development, 16+ in production)
- JWT validation with caching (30s cache for public key verification)
- Database connection pooling (SQLAlchemy, 20 connections max per worker)
- Async I/O for all database queries

## Git Workflow and Branching Strategy

### Branch Structure
- **`main`**: Production-ready code, always deployable, protected
- **`develop`**: Integration branch for features, protected
- **Feature branches**: `feature/{ticket-id}-{short-description}` (e.g., `feature/OASIS-123-add-tenant-mgmt`)
- **Bugfix branches**: `bugfix/{ticket-id}-{short-description}`
- **Hotfix branches**: `hotfix/{ticket-id}-{short-description}` (for production emergencies)

### Commit Conventions
Use **Conventional Commits** for all commits:
- `feat: Add tenant management UI` (new feature)
- `fix: Resolve race condition in ingestion service` (bug fix)
- `chore: Update dependencies` (maintenance, no functional change)
- `docs: Add API documentation for authentication` (documentation only)
- `refactor: Extract gateway auth logic to middleware` (code restructuring)
- `test: Add unit tests for OCSF normalization` (test additions)
- `perf: Optimize ClickHouse batch insert logic` (performance improvements)
- `ci: Update GitHub Actions workflow for security scanning` (CI/CD changes)

**Commit message format:**
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Examples:**
```
feat(api): Add JWT authentication middleware

Implement JWT validation for all API endpoints with role-based
access control. Tokens expire after 1 hour and include tenant_id claim.

Closes #42
```

```
fix(ingestion): Handle malformed syslog messages gracefully

Previously, invalid syslog messages would crash the ingestion service.
Now, malformed messages are logged to error queue and processing continues.

Fixes #128
```

### Branching Workflow
1. **Create feature branch** from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/OASIS-123-add-tenant-mgmt
   ```

2. **Develop and commit** using conventional commits:
   ```bash
   git add .
   git commit -m "feat(ui): Add tenant CRUD UI components"
   ```

3. **Keep branch up-to-date** with develop:
   ```bash
   git fetch origin
   git rebase origin/develop
   ```

4. **Push and create PR**:
   ```bash
   git push -u origin feature/OASIS-123-add-tenant-mgmt
   gh pr create --base develop --title "feat: Add tenant management UI" --body "Implements tenant CRUD operations with API key management"
   ```

5. **Code review**: PR auto-assigned to @0xgruber via CODEOWNERS
   - Requires 1 approval
   - Must pass all CI checks
   - Dismiss stale reviews if new changes pushed

6. **Merge to develop**: Squash merge (single commit per PR)
   ```bash
   # Via GitHub UI: "Squash and merge"
   # Commit message: PR title + body
   ```

7. **Release to main** (periodic releases):
   ```bash
   git checkout main
   git pull origin main
   git merge --no-ff develop -m "chore: Release v1.2.0"
   git tag v1.2.0
   git push origin main --tags
   ```

### Branch Protection Rules
**`main` and `develop` branches:**
- Require pull request before merging
- Require 1 approval from @0xgruber
- Dismiss stale pull request approvals when new commits are pushed
- Require status checks to pass before merging:
  - CI/CD pipeline (linting, tests, security scans)
  - Security: No HIGH/CRITICAL vulnerabilities (Trivy)
  - Coverage: Minimum 80% code coverage
- Prevent force pushes
- Prevent branch deletion

### Merge Strategy
- **Feature → Develop**: Squash merge (clean history)
- **Develop → Main**: Merge commit (preserve release history)
- **Hotfix → Main**: Merge commit, then cherry-pick to develop

## CI/CD Pipeline Architecture

### GitHub Actions Workflows

**Workflow: CI Pipeline** (`.github/workflows/ci.yml`)
Triggers: Push to any branch, pull requests to `develop` or `main`

**Stages:**

1. **Linting & Formatting** (runs in parallel):
   - **Python**: `ruff check backend/` (fast linter), `black --check backend/` (formatter)
   - **TypeScript**: `npm run lint` (ESLint), `npm run format:check` (Prettier)
   - **YAML/JSON**: `yamllint`, `jsonlint`
   - **Exit code**: Non-zero fails the build

2. **Type Checking** (runs in parallel with linting):
   - **Python**: `mypy backend/ --strict`
   - **TypeScript**: `npm run type-check` (tsc --noEmit)

3. **Unit Tests** (runs after linting/type-checking):
   - **Python**: `pytest backend/tests/unit --cov=backend --cov-report=xml`
     - Coverage requirement: 80% minimum
     - Upload coverage to Codecov
   - **TypeScript**: `npm run test:unit` (Jest)
     - Coverage requirement: 80% minimum

4. **Security Scanning** (runs in parallel):
   - **Vulnerability scanning**: `trivy filesystem --severity HIGH,CRITICAL .`
     - Fails build if HIGH/CRITICAL vulnerabilities found
   - **Secret scanning**: `gitleaks detect --source . --verbose`
     - Fails build if secrets detected
   - **SBOM generation**: `syft dir:. -o spdx-json=sbom.json`
     - Uploaded as artifact for auditing

5. **Integration Tests** (runs after unit tests):
   - Start services with Docker Compose (test profile)
   - Run integration tests: `pytest backend/tests/integration`
   - Test database migrations, API endpoints, gateway auth

6. **Docker Build** (runs on `develop` and `main` branches only):
   - Build all service images: ingestion, api, gateway, portal
   - Tag with commit SHA: `ghcr.io/0xgruber/oasis-api:sha-abc123`
   - Tag develop builds as `latest-dev`, main builds as `latest`
   - Push to GitHub Container Registry (ghcr.io)

**Workflow: Release** (`.github/workflows/release.yml`)
Triggers: Push tag `v*` (e.g., `v1.0.0`)

**Stages:**
1. Run full CI pipeline
2. Build production Docker images with version tag
3. Generate release notes from conventional commits
4. Create GitHub Release with changelog
5. Push Docker images to GHCR with version tags

**Workflow: Dependency Updates** (Dependabot)
Triggers: Monthly (1st of month)

**Configuration:**
- Check npm packages (frontend)
- Check pip packages (backend)
- Check Docker base images
- Create PRs for updates
- Auto-merge minor/patch updates if CI passes

### Test Matrix

**Python Tests** (Ubuntu 24.04 LTS):
- Python 3.11, 3.12

**TypeScript Tests** (Ubuntu 24.04 LTS):
- Node.js 20.x LTS

**Docker Builds** (Ubuntu 24.04 LTS):
- Multi-arch: `linux/amd64`, `linux/arm64`

### CI/CD Environment Variables

**Required Secrets** (GitHub Secrets):
- `GHCR_TOKEN`: GitHub token for pushing to ghcr.io
- `CODECOV_TOKEN`: Token for uploading coverage reports

**Environment Variables** (per job):
- `PYTHONUNBUFFERED=1`: Real-time Python output
- `DOCKER_BUILDKIT=1`: Enable BuildKit for faster builds
- `COMPOSE_DOCKER_CLI_BUILD=1`: Use BuildKit with Docker Compose

### Resource Limits for CI

**GitHub Actions Runners:**
- OS: Ubuntu 24.04 LTS
- CPU: 2 cores
- RAM: 7GB
- Disk: 14GB SSD

**Docker Compose for Integration Tests:**
- ClickHouse: 2GB limit
- PostgreSQL: 1GB limit
- Ingestion Service: 1GB limit
- API Service: 1GB limit
- Gateways: 512MB each

### Caching Strategy

**Python Dependencies:**
- Cache pip packages: `~/.cache/pip`
- Cache key: `py-${{ hashFiles('**/requirements.txt') }}`

**Node.js Dependencies:**
- Cache npm packages: `~/.npm`
- Cache key: `node-${{ hashFiles('**/package-lock.json') }}`

**Docker Layers:**
- Use GitHub Actions Docker layer caching
- Cache base images to reduce build time from 10min to ~2min

### Notifications

**PR Checks:**
- Status checks visible in PR UI
- Block merge if any check fails

**Failed Builds:**
- GitHub notifications to PR author
- Optional: Slack webhook for main/develop failures (Phase 2)

### Security Scanning Details

**Trivy Configuration:**
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    severity: 'HIGH,CRITICAL'
    exit-code: '1'  # Fail build if vulnerabilities found
    ignore-unfixed: true  # Ignore vulnerabilities with no fix available
```

**Gitleaks Configuration:**
```yaml
- name: Run Gitleaks secret scanner
  uses: gitleaks/gitleaks-action@v2
  with:
    path: '.'
    args: '--verbose --redact'
```

**SBOM Generation:**
```yaml
- name: Generate SBOM with Syft
  uses: anchore/sbom-action@v0
  with:
    format: spdx-json
    output-file: sbom.json
    upload-artifact: true
```

## Risks / Trade-offs

### Risk 1: Memory Exhaustion in Development
**Risk:** Three databases + services exceed 32GB under load during development

**Mitigation:**
- Strict container memory limits with Docker for development environment
- Continuous monitoring (Prometheus + Grafana - Phase 2)
- ClickHouse query complexity limits
- Graceful degradation: Prioritize ingestion over queries
- Production deployments not constrained - scale resources as needed

### Risk 2: OCSF Mapping Complexity
**Risk:** Building normalization for diverse log sources is time-consuming

**Mitigation:**
- Leverage syslog-ng built-in parsers for common log formats
- Start with 5 well-documented sources (Syslog, Windows, Linux, Firewall, Proxy)
- Community contribution model for additional sources
- Fallback: Store raw logs even if normalization fails

### Risk 3: ClickHouse Learning Curve
**Risk:** Team unfamiliar with ClickHouse query language and optimization

**Mitigation:**
- Comprehensive documentation with examples
- Start with simple queries, iterate based on performance profiling
- Leverage ClickHouse community resources and examples

### Risk 4: Scope Creep
**Risk:** Pressure to add AI features in Phase 1

**Mitigation:**
- Strict adherence to OpenSpec proposal approval process
- Clear phase gates in SoW
- MCP infrastructure prep (design) but no implementation until Phase 3

### Risk 5: Distributed GPU Service Complexity
**Risk:** Multiple deployment configurations (local GPU, remote GPU, no GPU) increase testing surface area

**Mitigation:**
- Docker Compose profiles provide clear templates for each scenario
- Core SIEM functionality works without GPU services (graceful degradation)
- Comprehensive documentation for each deployment model
- CI/CD tests against multiple configurations

## Migration Plan

### Phase 1 → Phase 2
- Add Qdrant vector storage (already containerized, activate when ready)
- Implement authentication/authorization (PostgreSQL schema already includes users table)
- Add API rate limiting and monitoring

### Phase 1 → Phase 3 (AI Integration)
- Deploy Ollama on GPU-enabled infrastructure (separate container/instance/bare-metal)
- Deploy MCP server with API endpoints to Ollama service
- Configure secure communication between core SIEM and GPU services
- Backfill embeddings for existing logs (batch job)
- Test graceful degradation when GPU services unavailable

### Rollback Strategy
Phase 1 is the initial release. If critical issues are found:
1. Stop ingestion service (logs buffer at source)
2. Export critical data from PostgreSQL
3. Roll back to last known good commit
4. Restart services with previous Docker images

## Open Questions

1. **Log Retention Policy**: Default to 90 days or make configurable from day one?
   - **Decision**: Configurable per-tenant via UI (Phase 1B), default 90 days

2. **API Authentication**: JWT or session-based for Phase 1?
   - **Decision**: JWT (stateless, easier to scale, 1h expiration, includes tenant_id claim)

3. **Vector Agent Deployment**: Provide pre-built packages or installation scripts?
   - **Decision needed by:** Week 2
   - **Recommendation**: Both - MSI for Windows, deb/rpm for Linux, Homebrew for macOS, plus Docker image

4. **ClickHouse Replication**: Single node or multi-node for Phase 1?
   - **Decision needed by:** Week 2
   - **Recommendation**: Single node for Phase 1, design schema for future replication

5. **GPU Service Default**: Should development environment include commented Ollama service or completely omit?
   - **Decision**: Include commented with clear documentation for enabling (Phase 3)

6. **Certificate Management**: Rolling restart or immediate restart after certificate regeneration?
   - **Decision**: Immediate restart via Docker API for Phase 1 (simple, acceptable downtime for cert rotation)
   - **Note**: Phase 2 can implement rolling restart with load-balanced gateways

7. **External Gateway Syslog Support**: Support both syslog and Vector in Phase 1, or Vector only?
   - **Decision needed by:** Week 1
   - **Recommendation**: Support both - Vector for endpoints, syslog (UDP/TCP/TLS 514/6514) for network devices

8. **Multi-Gateway Load Balancing**: Implement in Phase 1 or Phase 2?
   - **Decision**: Phase 2 - architecture documented for scalability, single gateway per subnet sufficient for Phase 1

9. **Audit Log Retention**: Same as security logs (90 days) or separate policy (1 year)?
   - **Decision**: Separate policy - 1 year minimum for compliance, configurable via system config UI (Phase 1C)

## Success Metrics

### Phase 1 Completion Criteria
- [ ] All services start successfully with `docker-compose up`
- [ ] External and internal gateways accept Vector and syslog logs
- [ ] Gateway validates API keys and enforces rate limits
- [ ] Ingestion service normalizes logs to OCSF and writes to tenant-specific ClickHouse tables
- [ ] API service authenticates users with JWT and enforces tenant isolation
- [ ] SOC Portal displays logs with filtering, pagination, and search
- [ ] Configuration UI (Phase 1A): Tenant CRUD, API key management, health dashboard
- [ ] Certificate management: Auto-generate on first startup, regenerate via UI
- [ ] Audit logging: All CRUD operations and sensitive actions logged to PostgreSQL
- [ ] Development environment memory usage stays under 28GB under normal load
- [ ] CI/CD pipeline runs with linting, tests, security scanning (Trivy, gitleaks, Syft)
- [ ] Documentation complete for setup and operation (dev and production)
- [ ] Vector agent example configs for Windows, Linux, macOS, Docker
- [ ] 80%+ test coverage for backend services
- [ ] All HIGH/CRITICAL vulnerabilities addressed

### Performance Baselines (to measure)
- **Ingestion latency**: p99 < 100ms per log event (gateway → ClickHouse)
- **Query response time**: p95 < 2s for last 24h queries (10k rows)
- **Gateway throughput**: 10k EPS per gateway instance sustained
- **API service latency**: p95 < 200ms for authenticated requests
- **Development memory usage**: Baseline (idle) and peak (under load) documented
- **Production scalability**: Document resource requirements for 10k, 50k, 100k EPS

### Security Validation
- [ ] All services run as non-root (UID 1000+)
- [ ] mTLS between gateways and ingestion service
- [ ] TLS between portals and API service
- [ ] Database authentication enforced (no passwordless access)
- [ ] No secrets in Git history (gitleaks passes)
- [ ] SBOM generated for all Docker images
- [ ] Trivy scan passes with 0 HIGH/CRITICAL vulnerabilities

### Multi-Tenancy Validation
- [ ] "Internal" tenant auto-created on first startup
- [ ] API keys unique per tenant, validated at gateway
- [ ] ClickHouse tables isolated per tenant (`logs_{tenant_uuid}`)
- [ ] Query API enforces tenant isolation (can't query other tenant's data)
- [ ] Rate limits enforced per tenant
- [ ] Retention policies configurable per tenant
