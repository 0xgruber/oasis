# O.A.S.I.S. Phase Tracker

**Last Updated:** 2026-01-11 (AI assistants: update this when phases change)

## Current Status

**Active Phase:** Phase 2A - Multi-Portal Foundation & RBAC  
**Branch:** `develop`  
**Production Release:** v1.0.0 (when ALL phases complete)

## Production Release Criteria

The following MUST be complete before merging to `main` branch:

- [x] Phase 1: Foundation (Infrastructure, Frontend, Service Monitoring, Agent Integration)
- [ ] Phase 2: Customer Portal & RBAC
- [ ] Phase 3: AI/LLM Integration
- [ ] Phase 4: Testing & CI/CD Pipeline
- [ ] Phase 5: Operations & Polish
- [ ] All security scans passing (Trivy, gitleaks)
- [ ] 80%+ test coverage across all services
- [ ] Production deployment tested
- [ ] Documentation complete

**Remember:** `main` = production-ready ONLY. All development merges to `develop`.

## Phase Details

### ✅ Phase 1: Foundation
**Status:** Complete  
**Completed:** 2026-01-11  
**Branch:** `develop`

Phase 1 encompasses the complete foundational infrastructure for O.A.S.I.S., including backend services, frontend portal, and agent integration. This phase is subdivided into the following completed components:

#### Phase 1A: Infrastructure & Services
**Completed:** 2026-01-09 | **Commit:** 2a597f9

**Goals:**
- Multi-tenant PostgreSQL schema
- ClickHouse log storage with per-tenant tables
- Three-subnet Docker architecture (DMZ, Internal, Backend)
- External & Internal gateway services (API key auth, rate limiting)
- Ingestion service (OCSF normalization)
- API service (JWT auth, log queries)

**Completion Criteria:**
- [x] Docker Compose with 8 services running
- [x] PostgreSQL schema with default "Internal" tenant
- [x] ClickHouse table-per-tenant architecture
- [x] Gateway services with API key authentication
- [x] Ingestion service with OCSF normalization
- [x] API service with JWT authentication

#### Phase 1B: Frontend & API Integration
**Completed:** 2026-01-09 | **Commit:** 2a597f9

**Goals:**
- Next.js SOC Portal
- Authentication UI (login, JWT tokens)
- Dashboard with service status cards
- Tenant management UI
- API key management UI
- Log viewer (basic)

**Completion Criteria:**
- [x] SOC Portal running on port 3000
- [x] Login page with JWT authentication
- [x] Dashboard with 8 service status cards (static)
- [x] Tenant management CRUD operations
- [x] API key generation and listing
- [x] Basic log viewer with filtering

#### Phase 1B-1: UX Enhancements & Themes
**Completed:** 2026-01-09 | **Commit:** 2a597f9

**Goals:**
- Dark/light theme toggle
- Improved navigation
- Status badge components
- Loading states and animations
- Mobile responsiveness

**Completion Criteria:**
- [x] Theme toggle in dashboard header
- [x] Dark mode styling for all components
- [x] Status badge color coding (green/yellow/red/gray)
- [x] Loading spinners and skeleton screens
- [x] Responsive layout for tablet/mobile

#### Phase 1C: Service Monitoring & Account APIs
**Completed:** 2026-01-10

**Goals:**
- Dynamic service status monitoring (Docker SDK)
- Real-time health checks via Docker daemon
- Account management API endpoints
- User profile updates
- Password change functionality

**Completion Criteria:**
- [x] API endpoint: `GET /api/services/status` (Docker SDK)
- [x] Frontend: Poll service status every 30 seconds
- [x] Dynamic status cards (no hardcoded services)
- [x] Status color coding (green/yellow/red/gray based on health)
- [x] Uptime display and network subnet badges
- [x] Unit tests for new endpoints (80% coverage)

**Implementation Details:**
See [IMPROVEMENTS.md](IMPROVEMENTS.md) - Dynamic Service Status Monitoring section

#### Phase 1D: Fluent Bit Agent Integration
**Completed:** 2026-01-11 | **Commits:** f9ec061, 242d787

**Goals:**
- Fluent Bit agent deployment
- Universal ingestion endpoint
- Gateway-side log transformation
- Agent configuration management
- End-to-end log flow verification

**Completion Criteria:**
- [x] Universal `/ingest` endpoint (accepts Fluent Bit native format)
- [x] Gateway-side transformation (Fluent Bit format → OCSF)
- [x] Automated `tenant.conf` deployment script
- [x] Multi-tenant isolation verified (per-tenant ClickHouse tables)
- [x] End-to-end log ingestion tested (VM → Gateway → ClickHouse)
- [x] Agent heartbeat tracking (updates `last_seen_at` on ingestion)

### 🔄 Phase 2: Customer Portal & RBAC
**Status:** In Progress (Phase 2A)  
**Branch:** `develop`

**Business Context:**  
O.A.S.I.S. operates as a managed SOC service. Customers deploy Fluent Bit agents on their infrastructure, and our SOC analysts monitor security events across all tenants. Phase 2 builds the three-portal architecture to support this business model.

**Architecture Overview:**

**Three-Portal System:**
1. **Platform Admin Portal** - `https://<internal-fqdn>:3000/admin/*`
   - For OASIS platform operators (super admins)
   - Manage tenants, API keys, system settings, users
   
2. **S.O.C.A.P. (SOC Analyst Portal)** - `https://<internal-fqdn>:3000/`
   - For internal SOC analysts
   - Monitor ALL tenants' security events and agents
   - Subscribe to specific tenants for focused monitoring
   - Custom dashboards (single or multi-tenant views)
   
3. **Customer Portal** - `https://<external-fqdn>:3002/`
   - For external customers (tenant users)
   - Tenant-isolated self-service log viewing
   - Download agent configs, manage API keys

**Deployment:**
- Single internal portal container (port 3000) with route-based access control
- Separate customer portal container (port 3002) in DMZ network
- Role-based middleware: `platform_admin`, `soc_analyst`, `customer_user`

---

#### Phase 2A: Multi-Portal Foundation & RBAC
**Status:** In Progress  
**Estimated Duration:** 1-2 weeks

**Goals:**
- Three-portal architecture setup
- User role system implementation
- Route-based access control middleware
- Basic agent registration tracking
- System settings management (global defaults)

**Completion Criteria:**
- [ ] Next.js route groups: `(socap)/`, `admin/`, separate customer portal
- [ ] PostgreSQL schema: `users.role` enum (platform_admin, soc_analyst, customer_user)
- [ ] Middleware: Route-based access control (`/admin/*` requires `platform_admin`)
- [ ] Admin Portal: User management UI (list, create, edit roles)
- [ ] Admin Portal: System settings UI (global agent thresholds)
- [ ] Database: `agents` table (hostname, IP, type, version, metadata, last_seen_at)
- [ ] Database: `system_settings` table (key-value config store)
- [ ] API: `POST /api/agents/register` (agent registration endpoint)

**Key Decisions:**
- Route-based admin portal (`/admin`) instead of separate port
- Single internal portal container for simplicity
- Self-signed TLS certs acceptable for now

---

#### Phase 2B: Agent Management & Monitoring
**Status:** Pending  
**Estimated Duration:** 2-3 weeks

**Goals:**
- Agent data model and heartbeat mechanism
- Dynamic status calculation (online/offline/dead)
- Per-tenant threshold overrides
- Agent management UIs across all portals

**Completion Criteria:**
- [ ] Agent heartbeat: Update `last_seen_at` on log ingestion
- [ ] Dynamic status calculation: online (<480m), offline (480m-30d), dead (>30d)
- [ ] Database: `tenant_settings` table (per-tenant threshold overrides)
- [ ] API: `GET /api/agents` (with status, filters, pagination)
- [ ] API: `GET /api/agents/:id` (agent details)
- [ ] Admin Portal: Agent management UI (list, edit, delete)
- [ ] S.O.C.A.P.: Global agent dashboard (all tenants, status breakdown)
- [ ] Customer Portal: Agent view (tenant-isolated, download config)
- [ ] Config download: Generate fresh API key on `tenant.conf` download

**Agent Status System:**
- States: `online`, `offline`, `dead`, `error`
- Thresholds configurable globally + per-tenant overrides
- Status computed dynamically (no stored state)

---

#### Phase 2C: S.O.C.A.P. - Analyst Dashboards & Workflows
**Status:** Pending  
**Estimated Duration:** 2-3 weeks

**Goals:**
- Analyst subscription system
- Custom tenant dashboards (single or multi-tenant)
- Agent drill-downs and timelines
- Alert placeholders for Phase 3

**Completion Criteria:**
- [ ] Database: `analyst_tenant_subscriptions` (analyst_id, tenant_id, notification_level)
- [ ] API: `POST /api/subscriptions` (subscribe/unsubscribe to tenants)
- [ ] API: `GET /api/subscriptions` (list analyst's subscribed tenants)
- [ ] S.O.C.A.P.: "My Tenants" vs "All Tenants" toggle
- [ ] S.O.C.A.P.: Custom dashboard builder (drag-drop widgets)
- [ ] S.O.C.A.P.: Agent status timeline (last 7 days)
- [ ] S.O.C.A.P.: Clickable drill-downs (tenant → agents → logs)
- [ ] UI components: Alert placeholders (for Phase 3 integration)

**Subscription Model:**
- Analysts can see ALL tenants (no hard restrictions)
- Subscribe to tenants for focused monitoring and notifications
- Subscription level: `all`, `critical_only`, `none`

---

#### Phase 2D: Customer Portal - Self-Service Features
**Status:** Pending  
**Estimated Duration:** 2-3 weeks

**Goals:**
- Customer authentication (separate from internal)
- Tenant-isolated log viewing and export
- Saved searches and basic dashboards
- API key management UI

**Completion Criteria:**
- [ ] Customer portal authentication (JWT, tenant-isolated)
- [ ] Log viewer: Tenant-isolated queries (ClickHouse per-tenant tables)
- [ ] Log export: CSV/JSON downloads
- [ ] Saved searches: Save/load queries
- [ ] Basic dashboards: Pre-built templates (log volume, top sources)
- [ ] API key management: List keys (prefix, created, last used)
- [ ] API key management: Revoke keys
- [ ] Config download: `tenant.conf` with fresh API key

**Security:**
- Customers can ONLY query their own tenant's logs
- API keys scoped to tenant (enforced at gateway)
- Audit trail for all key operations

---

#### Phase 2E: Enhanced Search & Audit Trail
**Status:** Pending  
**Estimated Duration:** 1-2 weeks

**Goals:**
- Advanced log search capabilities
- Query builder UI
- Comprehensive audit logging
- Search performance optimization

**Completion Criteria:**
- [ ] Advanced search: Regex, boolean operators, multi-field search
- [ ] Query builder: Visual interface (field, operator, value)
- [ ] Database: `audit_log` table (user_id, action, resource, changes, timestamp)
- [ ] Audit logging: All sensitive operations (user CRUD, API keys, config changes)
- [ ] Admin Portal: Audit viewer (filterable, searchable)
- [ ] API: `GET /api/audit` (pagination, filters)
- [ ] Search optimization: ClickHouse query performance tuning
- [ ] Frontend: Search result caching and pagination

**Audit Events:**
- User created/updated/deleted
- API key created/revoked
- Tenant created/updated
- Agent registered/deleted
- Config downloaded
- System settings changed

---

**Total Phase 2 Duration:** 8-13 weeks

### ⏸️ Phase 3: AI/LLM Integration
**Status:** Pending  
**Branch:** TBD

**Goals:**
- Local LLM integration via Ollama
- Model Context Protocol (MCP) implementation
- Natural language log queries
- Semantic search with Qdrant vector embeddings
- AI-powered threat analysis

**Completion Criteria:**
- [ ] Ollama service integration
- [ ] MCP client implementation
- [ ] Natural language query interface
- [ ] Qdrant vector database setup
- [ ] Log embedding generation
- [ ] Semantic search functionality
- [ ] AI-powered log analysis
- [ ] Threat detection with LLM assistance

---

### ⏸️ Phase 4: Testing & CI/CD Pipeline
**Status:** Pending  
**Branch:** TBD

**Rationale:** Moved from Phase 1D. Testing and CI/CD are more effective after all features are built (Phase 2-3), allowing for comprehensive test coverage of the complete system.

**Goals:**
- Comprehensive test suite (80%+ coverage)
- GitHub Actions CI/CD pipeline
- Security scanning (Trivy, gitleaks, Syft)
- Automated Docker builds
- Integration tests across all portals and services

**Completion Criteria:**
- [ ] Pytest test suite for all Python services (API, Ingestion, Gateways)
- [ ] Jest/React Testing Library for all three portals
- [ ] 80%+ code coverage across all services
- [ ] GitHub Actions workflow (`.github/workflows/ci.yml`)
- [ ] Trivy vulnerability scanning (container images)
- [ ] gitleaks secret scanning (repository)
- [ ] Integration tests (gateway → ingestion → ClickHouse)
- [ ] End-to-end tests (agent → portal workflows)
- [ ] RBAC and multi-tenant isolation tests
- [ ] Performance and load testing

---

### ⏸️ Phase 5: Operations & Polish
**Status:** Pending  
**Branch:** TBD

**Rationale:** Moved from Phase 4. Operational tooling and production hardening come last, after all features and tests are complete.

**Goals:**
- Production deployment automation
- Monitoring and alerting
- Backup and disaster recovery
- Performance optimization
- Documentation finalization

**Completion Criteria:**
- [ ] Production deployment scripts (Terraform/Ansible)
- [ ] Prometheus/Grafana monitoring dashboards
- [ ] Alert rules for critical failures
- [ ] Automated backup system (PostgreSQL, ClickHouse)
- [ ] Disaster recovery runbook
- [ ] Performance tuning (ClickHouse queries, API caching)
- [ ] Complete user documentation
- [ ] API documentation (OpenAPI/Swagger)
- [ ] Deployment guide
- [ ] Security hardening checklist

## Git Workflow Reference

For detailed branching and merging instructions, see [GIT_WORKFLOW.md](GIT_WORKFLOW.md).

**Quick Reference:**
- Feature branches → `develop` (direct merge or PR)
- `develop` → `main` **ONLY when v1.0.0 ready** (all phases complete)
- Use command: `gh pr merge --admin --squash` for `develop` → `main`

**Decision Tree:**
```
Is this production-ready? (All phases complete + tested)
  ├─ YES → PR to main, use gh pr merge --admin
  └─ NO  → Merge to develop (direct push or simple PR)
```

## Related Documentation

- [GIT_WORKFLOW.md](GIT_WORKFLOW.md) - Complete git workflow and branching strategy
- [IMPROVEMENTS.md](IMPROVEMENTS.md) - Phase requirements and technical details
- [INDEX.md](INDEX.md) - Complete documentation catalog
- [README.md](README.md) - Project overview
