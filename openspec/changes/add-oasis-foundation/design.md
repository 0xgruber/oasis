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

### Decision 8: Syslog-ng for Log Collection
**Choice:** Integrate syslog-ng as the primary log collection agent

**Rationale:**
- **Mature and proven**: Battle-tested in production environments for 20+ years
- **Reduced development overhead**: Avoid building custom log shippers; focus on normalization and analytics
- **Protocol support**: Native Syslog (RFC 3164/5424), TCP, UDP, TLS, and custom sources
- **Filtering and routing**: Built-in log filtering, parsing, and multi-destination routing
- **Performance**: High-throughput C implementation, minimal resource overhead
- **Integration**: Easy Docker deployment, standard configuration format

**Alternatives Considered:**
- Custom ingestion agent: Rejected - significant development time, reinventing proven solutions
- Fluentd: Considered but rejected - Ruby-based (higher memory), more complex configuration
- Logstash: Rejected - JVM overhead, tighter Elastic ecosystem coupling
- Vector (Datadog): Considered - newer Rust-based option, but syslog-ng more mature for syslog processing

**Integration Approach:**
- Syslog-ng runs as sidecar container or separate instance
- Receives logs from network sources (UDP/TCP 514, TLS 6514)
- Performs initial parsing and filtering
- Forwards structured logs to O.A.S.I.S. ingestion API (HTTP/JSON)
- Configuration file defines log sources, filters, and destinations

**Trade-offs:**
- External dependency: Adds another component to the stack
- Mitigation: Well-documented, stable project; minimal maintenance burden
- Configuration learning curve: syslog-ng has its own config syntax
- Mitigation: Provide templated configurations for common use cases

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

### Ingestion Flow
```
Log Source → syslog-ng → HTTP/JSON → Ingestion Service → OCSF Normalization → Router
                                                                                 ├→ ClickHouse (raw logs)
                                                                                 └→ Qdrant (future: embeddings)
```

### Query Flow (Phase 1)
```
Frontend → API Gateway → PostgreSQL (auth) → ClickHouse (logs) → Frontend
```

### Future AI Flow (Phase 3+) - Distributed Architecture
```
User Query → API Gateway → MCP Server (remote/local) → LLM (Ollama, GPU service) → Database Tools → Response
```

## Database Schema Highlights

### ClickHouse: `logs` table
```sql
CREATE TABLE logs (
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
TTL timestamp + INTERVAL 90 DAY;  -- Configurable retention
```

### PostgreSQL: Application schema
- `users`: Authentication and user profiles
- `api_keys`: API access management
- `saved_searches`: User-saved queries
- `system_config`: Application settings

### Qdrant: Vector collections (Phase 3)
- Collection: `log_embeddings` (dimension: 768 for Llama-3)
- Payload: event_id, timestamp, metadata

## Performance Considerations

### Development Memory Budget (32GB Total - Development Environment Only)
- OS/System: ~4GB
- ClickHouse: 8-12GB (configurable, includes cache)
- PostgreSQL: 2GB
- Qdrant: 2GB (Phase 3)
- Backend services: 2-4GB
- Frontend/Nginx: 1GB
- Syslog-ng: ~200MB
- Ollama/LLM: Disabled in development OR run on separate GPU instance
- Buffer: 3-5GB

**Note**: This budget is for development only. Production deployments on server infrastructure are not constrained by 32GB and should be sized according to log volume and performance requirements.

### Production Resource Allocation (Recommended Minimums)
- **Small Deployment** (< 10k EPS):
  - 64GB RAM, 16 CPU cores, 1TB SSD
  - Optional: Separate GPU server for AI features
- **Medium Deployment** (10k-50k EPS):
  - 128GB RAM, 32 CPU cores, 2TB NVMe
  - Recommended: Separate GPU server (24GB+ VRAM)
- **Large Deployment** (50k+ EPS):
  - Distributed ClickHouse cluster
  - Load-balanced ingestion services
  - Dedicated GPU server farm for LLM inference

### Write Optimization
- ClickHouse batch inserts (1000 rows or 5s interval)
- Async ingestion queue (Redis or in-memory)
- Back-pressure handling for burst traffic

### Query Optimization
- ClickHouse materialized views for common aggregations
- Query result caching (Redis - Phase 2)
- Pagination for large result sets (limit 10k rows per query)

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
   - **Decision needed by:** Week 2
   - **Recommendation:** Configurable via environment variable, default 90 days

2. **API Authentication**: JWT or session-based for Phase 1 stub?
   - **Decision needed by:** Week 4
   - **Recommendation:** JWT (stateless, easier to scale)

3. **Syslog-ng Configuration**: Deploy as sidecar container or separate instance?
   - **Decision needed by:** Week 1
   - **Recommendation:** Sidecar for development, separate instance for production

4. **ClickHouse Replication**: Single node or multi-node for Phase 1?
   - **Decision needed by:** Week 2
   - **Recommendation:** Single node for Phase 1, design for replication

5. **GPU Service Default**: Should development environment include commented Ollama service or completely omit?
   - **Decision needed by:** Week 2
   - **Recommendation:** Include commented with clear documentation for enabling

## Success Metrics

### Phase 1 Completion Criteria
- [ ] All services start successfully with `docker-compose up`
- [ ] Syslog-ng receives and forwards logs to ingestion service
- [ ] Ingestion service accepts HTTP JSON logs at 1000+ EPS
- [ ] Logs are normalized to OCSF and stored in ClickHouse
- [ ] Web frontend displays logs with basic filtering
- [ ] Development environment memory usage stays under 28GB under normal load
- [ ] CI/CD pipeline runs with security scanning
- [ ] Documentation complete for setup and operation (dev and production)
- [ ] Documentation for distributed GPU deployment options
- [ ] 80%+ test coverage for backend services

### Performance Baselines (to measure)
- Ingestion latency: p99 < 100ms per log event
- Query response time: p95 < 2s for last 24h queries
- Development memory usage: Baseline and peak measurements documented
- Production scalability: Document resource requirements for target EPS rates
