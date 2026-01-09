# Implementation Tasks

## 1. Repository Setup (Phase 0 - COMPLETED)
- [x] 1.1 Initialize Git repository with .gitignore
- [x] 1.2 Create monorepo structure (/backend, /frontend, /infrastructure)
- [x] 1.3 Add LICENSE (MIT)
- [x] 1.4 Create README.md with project overview
- [x] 1.5 Create SECURITY.md with vulnerability reporting process
- [x] 1.6 Create CODEOWNERS file (@0xgruber)
- [x] 1.7 Create GitHub repository (https://github.com/0xgruber/oasis)
- [x] 1.8 Configure branch protection (main, develop)

## 2. Infrastructure & Docker Environment
- [ ] 2.1 Create docker-compose.yml for development environment with three networks (dmz, internal, backend)
- [ ] 2.2 Configure ClickHouse container with optimal settings for 32GB RAM (8-12GB limit)
- [ ] 2.3 Configure PostgreSQL container with initial schema (2GB limit)
- [ ] 2.4 Add Qdrant container for vector storage (2GB limit, Phase 3 activation)
- [ ] 2.5 Create .env.example with required environment variables (database creds, JWT secret, API keys)
- [ ] 2.6 Add health check endpoints for all database services
- [ ] 2.7 Create database initialization scripts (schema creation, "Internal" tenant auto-create)
- [ ] 2.8 Add Docker network configurations (dmz-network: 172.20.0.0/24, internal-network: 172.21.0.0/24, backend-network: 172.22.0.0/24)
- [ ] 2.9 Configure Docker resource limits for all services
- [ ] 2.10 Create docker-compose.prod.yml for production deployment

## 3. Gateway Services
- [ ] 3.1 Design gateway service architecture (FastAPI-based, lightweight)
- [ ] 3.2 Implement external gateway (DMZ, internet-facing)
- [ ] 3.3 Implement internal gateway (corporate network-facing)
- [ ] 3.4 Add API key authentication middleware (validate against PostgreSQL api_keys table)
- [ ] 3.5 Implement rate limiting per tenant (configurable EPS limits)
- [ ] 3.6 Add input validation (payload size limits, schema validation)
- [ ] 3.7 Implement mTLS client for forwarding to ingestion service
- [ ] 3.8 Add syslog listener (UDP/TCP 514, TLS 6514) with RFC 3164/5424 parsing
- [ ] 3.9 Implement health check endpoints (/health, /ready)
- [ ] 3.10 Add request logging for audit trail
- [ ] 3.11 Implement circuit breaker for ingestion service failures
- [ ] 3.12 Write unit tests for gateway authentication and rate limiting
- [ ] 3.13 Write integration tests for gateway → ingestion flow

## 4. Backend - Data Ingestion Service
- [ ] 4.1 Set up FastAPI project structure with async support
- [ ] 4.2 Implement HTTP/JSON ingestion endpoint (POST /ingest)
- [ ] 4.3 Add mTLS server configuration (authenticate gateways)
- [ ] 4.4 Create OCSF normalization module with common log source mappings
- [ ] 4.5 Implement data routing logic (logs → ClickHouse tenant tables)
- [ ] 4.6 Add batch insert optimization (1000 rows or 5s interval)
- [ ] 4.7 Implement back-pressure handling (HTTP 429 when buffer full)
- [ ] 4.8 Add input validation and error handling (malformed OCSF fallback)
- [ ] 4.9 Create ClickHouse client with connection pooling (ingestion_user credentials)
- [ ] 4.10 Implement dynamic table creation for new tenants (logs_{tenant_uuid})
- [ ] 4.11 Add logging and monitoring infrastructure (structured JSON logs)
- [ ] 4.12 Write unit tests for OCSF normalization (>80% coverage)
- [ ] 4.13 Write unit tests for batch insert logic
- [ ] 4.14 Write integration tests for ingestion pipeline

## 5. Backend - API Service
- [ ] 5.1 Set up separate FastAPI project for API service
- [ ] 5.2 Implement JWT authentication (1h expiration, tenant_id claim)
- [ ] 5.3 Create user authentication endpoints (POST /auth/login, POST /auth/logout)
- [ ] 5.4 Implement JWT validation middleware
- [ ] 5.5 Add password hashing (bcrypt) and validation
- [ ] 5.6 Implement TOTP (Time-based One-Time Password) generation and validation
- [ ] 5.7 Create log query API (GET /logs with tenant isolation)
- [ ] 5.8 Implement tenant-scoped ClickHouse queries (SELECT from logs_{tenant_uuid})
- [ ] 5.9 Add pagination for log queries (limit 10k rows per request)
- [ ] 5.10 Implement tenant CRUD API (POST, GET, PUT, DELETE /tenants)
- [ ] 5.11 Implement API key management API (POST /tenants/{id}/apikey/regenerate)
- [ ] 5.12 Create audit logging middleware (log all CRUD operations to audit_logs table)
- [ ] 5.13 Add rate limiting for API endpoints (per-user limits)
- [ ] 5.14 Implement re-authentication endpoint for sensitive operations (POST /auth/reauth)
- [ ] 5.15 Create OpenAPI specification for all endpoints
- [ ] 5.16 Add Swagger UI at /docs
- [ ] 5.17 Write unit tests for authentication logic (>80% coverage)
- [ ] 5.18 Write unit tests for tenant isolation enforcement
- [ ] 5.19 Write integration tests for API endpoints

## 6. Backend - Database Layer
- [ ] 6.1 Design ClickHouse multi-tenant schema (table-per-tenant: logs_{tenant_uuid})
- [ ] 6.2 Create ClickHouse table creation SQL (MergeTree engine, partitioning by month)
- [ ] 6.3 Design PostgreSQL schema (tenants, api_keys, users, certificates, audit_logs, system_config)
- [ ] 6.4 Create PostgreSQL migration system (Alembic)
- [ ] 6.5 Implement initial migration (create all tables)
- [ ] 6.6 Add migration for "Internal" tenant auto-creation
- [ ] 6.7 Create database connection pooling (SQLAlchemy for PostgreSQL, ClickHouse native client)
- [ ] 6.8 Implement database authentication (separate users: ingestion_user, api_user)
- [ ] 6.9 Add ClickHouse user creation scripts (ingestion_user: INSERT only, api_user: SELECT only)
- [ ] 6.10 Add PostgreSQL role creation scripts (principle of least privilege)
- [ ] 6.11 Implement query optimization (indexes on audit_logs.timestamp, audit_logs.user_id, audit_logs.tenant_id)
- [ ] 6.12 Create database backup procedures (pg_dump for PostgreSQL, ClickHouse snapshots)
- [ ] 6.13 Create database restore procedures
- [ ] 6.14 Write unit tests for database operations

## 7. Certificate Management
- [ ] 7.1 Design certificate schema (PostgreSQL certificates table)
- [ ] 7.2 Implement auto-generation of self-signed CA on first startup
- [ ] 7.3 Implement auto-generation of service certificates (gateway, ingestion, api, portals)
- [ ] 7.4 Create certificate generation utility (cryptography library)
- [ ] 7.5 Implement certificate storage in PostgreSQL (PEM format)
- [ ] 7.6 Create certificate retrieval API (GET /certificates)
- [ ] 7.7 Implement certificate regeneration API (POST /certificates/{name}/regenerate)
- [ ] 7.8 Add certificate download endpoint (GET /certificates/{name}/download)
- [ ] 7.9 Implement Docker API client for container restart after cert regeneration
- [ ] 7.10 Add certificate expiration monitoring (flag certs expiring < 30 days)
- [ ] 7.11 Write unit tests for certificate generation
- [ ] 7.12 Write integration tests for certificate regeneration and service restart

## 8. Multi-Tenancy Implementation
- [ ] 8.1 Create tenant model (Pydantic schema, SQLAlchemy ORM)
- [ ] 8.2 Implement tenant CRUD logic in API service
- [ ] 8.3 Create API key generation logic (secrets.token_urlsafe, bcrypt hashing)
- [ ] 8.4 Implement API key regeneration with confirmation
- [ ] 8.5 Add API key validation logic in gateway
- [ ] 8.6 Implement dynamic ClickHouse table creation for new tenants
- [ ] 8.7 Add tenant isolation enforcement in query API (verify tenant_id from JWT matches table)
- [ ] 8.8 Implement per-tenant retention policies (TTL in ClickHouse table)
- [ ] 8.9 Implement per-tenant rate limits (enforced at gateway)
- [ ] 8.10 Add tenant activation/deactivation logic
- [ ] 8.11 Write unit tests for tenant isolation
- [ ] 8.12 Write integration tests for multi-tenant data isolation

## 9. Frontend - SOC Portal (Phase 1A: Weeks 1-3)
- [ ] 9.1 Initialize Next.js project with TypeScript
- [ ] 9.2 Set up Tailwind CSS and shadcn/ui components
- [ ] 9.3 Create authentication UI (login form with username/password + TOTP)
- [ ] 9.4 Implement JWT storage and refresh logic (localStorage, auto-refresh before expiry)
- [ ] 9.5 Create protected route wrapper (redirect to login if not authenticated)
- [ ] 9.6 Implement basic dashboard layout (sidebar navigation, header, content area)
- [ ] 9.7 Create tenant management UI (list, create, edit, delete tenants)
- [ ] 9.8 Add tenant delete confirmation modal
- [ ] 9.9 Create API key management UI (view key prefix, regenerate button)
- [ ] 9.10 Add API key regeneration confirmation modal (show new key once)
- [ ] 9.11 Create health dashboard (service status, resource usage, ingestion rate)
- [ ] 9.12 Add real-time metrics display (WebSocket or polling)
- [ ] 9.13 Implement API client for backend communication (axios with JWT interceptor)
- [ ] 9.14 Add error handling and loading states (toast notifications)
- [ ] 9.15 Write unit tests for UI components (Jest + React Testing Library)

## 10. Frontend - SOC Portal (Phase 1B: Weeks 4-6)
- [ ] 10.1 Create certificate management UI (list certificates, view details)
- [ ] 10.2 Add certificate download button
- [ ] 10.3 Create certificate regeneration UI with re-authentication modal
- [ ] 10.4 Add certificate status indicators (valid, expiring soon, expired)
- [ ] 10.5 Create RBAC management UI (assign roles to users)
- [ ] 10.6 Add user list view with role filtering
- [ ] 10.7 Create retention policy configuration UI (per-tenant and global)
- [ ] 10.8 Add rate limit configuration UI (per-tenant EPS limits)
- [ ] 10.9 Implement settings save confirmation with re-authentication
- [ ] 10.10 Write unit tests for Phase 1B components

## 11. Frontend - SOC Portal (Phase 1C: Week 7+)
- [ ] 11.1 Create database connection configuration UI (ClickHouse, PostgreSQL connection strings)
- [ ] 11.2 Add SMTP settings UI (email server config for alert notifications)
- [ ] 11.3 Create backup/restore UI (trigger backup, restore from file upload)
- [ ] 11.4 Add Docker resource limit configuration UI (adjust container memory/CPU)
- [ ] 11.5 Create audit log viewer (table with filtering by user, tenant, action, date range)
- [ ] 11.6 Add audit log export to CSV
- [ ] 11.7 Implement re-authentication modal for all Phase 1C changes
- [ ] 11.8 Add system configuration change confirmation modals
- [ ] 11.9 Write unit tests for Phase 1C components

## 12. Frontend - Log Viewer
- [ ] 12.1 Create log viewer component with table display (TanStack Table)
- [ ] 12.2 Add column configuration (show/hide columns, reorder)
- [ ] 12.3 Implement search interface (full-text search, field-specific filters)
- [ ] 12.4 Add time range picker (last 1h, 24h, 7d, custom range)
- [ ] 12.5 Implement pagination (client-side and server-side)
- [ ] 12.6 Add severity filtering (info, warning, error, critical)
- [ ] 12.7 Create log detail view (expandable row with full OCSF fields)
- [ ] 12.8 Add export to CSV/JSON functionality
- [ ] 12.9 Implement saved searches feature (save filters, load later)
- [ ] 12.10 Add real-time log streaming (WebSocket, optional)
- [ ] 12.11 Write unit tests for log viewer components

## 13. RBAC Implementation
- [ ] 13.1 Design RBAC model (roles: super_admin, internal_soc, soc_operator, tenant_user)
- [ ] 13.2 Create permission matrix (role → allowed operations)
- [ ] 13.3 Implement role-based access control middleware in API service
- [ ] 13.4 Add role checking decorators for API endpoints
- [ ] 13.5 Implement UI permission enforcement (hide/disable features based on role)
- [ ] 13.6 Create role assignment logic (super_admin can assign roles)
- [ ] 13.7 Add role-based navigation menu (show/hide menu items)
- [ ] 13.8 Write unit tests for RBAC enforcement
- [ ] 13.9 Write integration tests for role-based access

## 14. Audit Logging
- [ ] 14.1 Design audit log schema (PostgreSQL audit_logs table)
- [ ] 14.2 Implement audit logging middleware (log all API requests)
- [ ] 14.3 Add audit logging for tenant CRUD operations
- [ ] 14.4 Add audit logging for API key regeneration
- [ ] 14.5 Add audit logging for certificate regeneration
- [ ] 14.6 Add audit logging for user authentication (login, logout, failed attempts)
- [ ] 14.7 Add audit logging for RBAC changes
- [ ] 14.8 Add audit logging for system configuration changes
- [ ] 14.9 Add audit logging for log query API calls
- [ ] 14.10 Implement audit log retention policy (1 year minimum)
- [ ] 14.11 Write unit tests for audit logging

## 15. Vector Agent Integration
- [ ] 15.1 Create Vector configuration examples for Windows Event Log
- [ ] 15.2 Create Vector configuration example for Linux syslog
- [ ] 15.3 Create Vector configuration example for Linux systemd journals
- [ ] 15.4 Create Vector configuration example for macOS Unified Log
- [ ] 15.5 Create Vector configuration example for Docker container logs
- [ ] 15.6 Create Vector deployment README (installation instructions for each platform)
- [ ] 15.7 Document Vector agent setup for Windows (MSI installation)
- [ ] 15.8 Document Vector agent setup for Linux (deb/rpm packages)
- [ ] 15.9 Document Vector agent setup for macOS (Homebrew)
- [ ] 15.10 Create Docker image for Vector agent (optional sidecar deployment)
- [ ] 15.11 Test Vector agent → gateway ingestion flow

## 16. Security & Hardening
- [ ] 16.1 Configure all containers to run as non-root users (UID 1000+)
- [ ] 16.2 Add AppArmor/Seccomp profiles for containers
- [ ] 16.3 Implement secrets management (environment variables, never committed)
- [ ] 16.4 Add input sanitization across all API endpoints
- [ ] 16.5 Configure mTLS for gateway → ingestion service communication
- [ ] 16.6 Configure TLS for portal → API service communication
- [ ] 16.7 Create security headers configuration (HSTS, CSP, X-Frame-Options)
- [ ] 16.8 Implement password complexity requirements (min 12 chars, uppercase, lowercase, number, symbol)
- [ ] 16.9 Add brute force protection (rate limit login attempts)
- [ ] 16.10 Implement session timeout (JWT expiration enforcement)
- [ ] 16.11 Add TOTP setup flow for new users
- [ ] 16.12 Write security tests (SQL injection, XSS, CSRF)

## 17. CI/CD Pipeline
- [ ] 17.1 Create GitHub Actions workflow for CI (.github/workflows/ci.yml)
- [ ] 17.2 Add Python linting (ruff) and formatting (black) checks
- [ ] 17.3 Add TypeScript linting (ESLint) and formatting (Prettier) checks
- [ ] 17.4 Add Python type checking (mypy --strict)
- [ ] 17.5 Add TypeScript type checking (tsc --noEmit)
- [ ] 17.6 Add Python unit tests (pytest with coverage)
- [ ] 17.7 Add TypeScript unit tests (Jest with coverage)
- [ ] 17.8 Integrate SBOM generation (Syft)
- [ ] 17.9 Add vulnerability scanning (Trivy, fail on HIGH/CRITICAL)
- [ ] 17.10 Add secret scanning (gitleaks)
- [ ] 17.11 Create Docker image build workflow (multi-arch: amd64, arm64)
- [ ] 17.12 Add Docker image push to GHCR (ghcr.io/0xgruber/oasis-*)
- [ ] 17.13 Create integration test workflow (Docker Compose + pytest integration tests)
- [ ] 17.14 Add coverage reporting (Codecov)
- [ ] 17.15 Configure Dependabot (monthly updates for npm, pip, Docker)
- [ ] 17.16 Create release workflow (tag → build → GitHub release)
- [ ] 17.17 Add Docker layer caching for faster builds

## 18. Testing & Quality Assurance
- [ ] 18.1 Write unit tests for gateway authentication (target: >80% coverage)
- [ ] 18.2 Write unit tests for gateway rate limiting
- [ ] 18.3 Write unit tests for ingestion OCSF normalization (>80% coverage)
- [ ] 18.4 Write unit tests for ingestion batch insert logic
- [ ] 18.5 Write unit tests for API authentication (JWT validation)
- [ ] 18.6 Write unit tests for API tenant isolation
- [ ] 18.7 Write unit tests for multi-tenant data isolation
- [ ] 18.8 Write unit tests for RBAC enforcement
- [ ] 18.9 Write unit tests for audit logging
- [ ] 18.10 Write integration tests for Vector → gateway → ingestion → ClickHouse flow
- [ ] 18.11 Write integration tests for user authentication → query API → ClickHouse flow
- [ ] 18.12 Write integration tests for tenant CRUD operations
- [ ] 18.13 Write integration tests for certificate regeneration
- [ ] 18.14 Create test data fixtures (sample OCSF logs, test tenants, test users)
- [ ] 18.15 Set up test coverage reporting (pytest-cov, istanbul)
- [ ] 18.16 Add performance baseline tests (ingestion throughput, query latency)
- [ ] 18.17 Add load testing scripts (Locust or k6)

## 19. Documentation
- [ ] 19.1 Create architecture diagrams (Mermaid: network topology, data flow)
- [ ] 19.2 Create OCSF schema mapping documentation (common log sources)
- [ ] 19.3 Write API documentation (OpenAPI/Swagger)
- [ ] 19.4 Create development setup guide (prerequisites, docker-compose up, first login)
- [ ] 19.5 Create production deployment guide (server requirements, network topology, firewall rules)
- [ ] 19.6 Document database schemas (ClickHouse, PostgreSQL with ERD diagrams)
- [ ] 19.7 Write troubleshooting guide (common issues, log locations, debug mode)
- [ ] 19.8 Create Vector agent deployment guide (per-platform instructions)
- [ ] 19.9 Document multi-tenancy model (table-per-tenant rationale, API key management)
- [ ] 19.10 Create security hardening guide (mTLS setup, certificate management, RBAC)
- [ ] 19.11 Write contribution guide (branch strategy, commit conventions, PR process)
- [ ] 19.12 Create Git workflow documentation (GIT_WORKFLOW.md)
- [ ] 19.13 Create CI/CD pipeline documentation (CI_CD_PIPELINE.md)
- [ ] 19.14 Create improvements roadmap (IMPROVEMENTS.md - Phase 2+ features)
- [ ] 19.15 Document performance baselines (ingestion EPS, query latency, resource usage)

## 20. Performance & Optimization
- [ ] 20.1 Profile memory usage under 32GB constraint (Docker stats monitoring)
- [ ] 20.2 Optimize ClickHouse settings for write performance (batch size, buffer size)
- [ ] 20.3 Optimize ClickHouse settings for query performance (cache size, merge tree settings)
- [ ] 20.4 Implement connection pooling optimization (tune pool sizes)
- [ ] 20.5 Benchmark ingestion rates (measure sustained EPS)
- [ ] 20.6 Benchmark query latency (p50, p95, p99 for common queries)
- [ ] 20.7 Optimize gateway rate limiting algorithm (token bucket with Redis)
- [ ] 20.8 Optimize API service query performance (connection pooling, query optimization)
- [ ] 20.9 Add query complexity limits (max execution time, kill slow queries)
- [ ] 20.10 Create performance monitoring dashboard (Prometheus + Grafana - Phase 2)
- [ ] 20.11 Document performance tuning recommendations

## 21. Validation & Delivery
- [ ] 21.1 Verify all services start successfully with docker-compose up
- [ ] 21.2 Test Vector agent → gateway ingestion flow (Windows, Linux, macOS)
- [ ] 21.3 Test syslog → gateway ingestion flow (UDP, TCP, TLS)
- [ ] 21.4 Verify gateway API key authentication and rate limiting
- [ ] 21.5 Test complete ingestion flow (gateway → ingestion → OCSF normalization → ClickHouse)
- [ ] 21.6 Verify multi-tenant data isolation (create 2 tenants, verify query isolation)
- [ ] 21.7 Test user authentication (login, JWT validation, logout)
- [ ] 21.8 Test RBAC enforcement (verify role-based access to UI and API)
- [ ] 21.9 Verify SOC Portal displays logs from ClickHouse with filtering and pagination
- [ ] 21.10 Test tenant CRUD operations via UI
- [ ] 21.11 Test API key regeneration via UI
- [ ] 21.12 Test certificate regeneration via UI (verify service restart)
- [ ] 21.13 Verify audit logging for all operations
- [ ] 21.14 Run full security scan suite (Trivy, gitleaks, OWASP ZAP)
- [ ] 21.15 Address all HIGH/CRITICAL security findings
- [ ] 21.16 Verify 80%+ test coverage for all backend services
- [ ] 21.17 Run end-to-end load test (sustained 10k EPS for 1 hour)
- [ ] 21.18 Verify development environment memory usage stays under 28GB under load
- [ ] 21.19 Complete final documentation review and updates
- [ ] 21.20 Create Phase 1 release notes
- [ ] 21.21 Tag Phase 1 release (v1.0.0)
- [ ] 21.22 Push Docker images to GHCR with v1.0.0 tag
- [ ] 21.23 Create GitHub release with changelog

## Task Summary
- **Total Tasks:** 161
- **Phase 0 (Completed):** 8 tasks (Repository setup, GitHub configuration)
- **Infrastructure:** 10 tasks (Docker Compose, databases, networks)
- **Gateway Services:** 13 tasks (API authentication, rate limiting, syslog support)
- **Ingestion Service:** 14 tasks (OCSF normalization, multi-tenant tables, batch insert)
- **API Service:** 19 tasks (JWT auth, TOTP, tenant CRUD, audit logging)
- **Database Layer:** 14 tasks (Multi-tenant schema, migrations, authentication)
- **Certificate Management:** 12 tasks (Auto-generation, regeneration, Docker restart)
- **Multi-Tenancy:** 12 tasks (Tenant isolation, API keys, per-tenant policies)
- **Frontend Phase 1A:** 15 tasks (Tenant mgmt, API key mgmt, health dashboard)
- **Frontend Phase 1B:** 10 tasks (Certificates, RBAC, retention, rate limits)
- **Frontend Phase 1C:** 9 tasks (Advanced config, audit log viewer)
- **Log Viewer:** 11 tasks (Search, filtering, export, real-time streaming)
- **RBAC:** 9 tasks (Roles, permissions, enforcement)
- **Audit Logging:** 11 tasks (Middleware, retention, viewer)
- **Vector Integration:** 11 tasks (Config examples, deployment docs)
- **Security:** 12 tasks (mTLS, TLS, TOTP, brute force protection)
- **CI/CD:** 17 tasks (Linting, tests, security scans, Docker builds)
- **Testing:** 17 tasks (Unit tests, integration tests, load tests)
- **Documentation:** 15 tasks (Architecture, API docs, deployment guides)
- **Performance:** 11 tasks (Benchmarking, optimization, monitoring)
- **Validation:** 23 tasks (End-to-end testing, security validation, release)

## Estimated Timeline
- **Week 1:** Infrastructure, Docker Compose, database setup, gateway skeleton
- **Week 2:** Gateway services (auth, rate limiting), ingestion service, multi-tenant tables
- **Week 3:** API service (JWT, tenant CRUD, audit logging), certificate auto-generation
- **Week 4:** Frontend Phase 1A (tenant mgmt, API key mgmt, health dashboard)
- **Week 5:** Frontend Phase 1B (certificate mgmt, RBAC, retention policies)
- **Week 6:** Frontend Phase 1C (advanced config, audit log viewer), log viewer
- **Week 7:** Vector integration, security hardening, CI/CD pipeline
- **Week 8:** Testing (unit, integration, load), documentation, performance tuning
- **Week 9:** Validation, security scanning, final testing, release preparation
