# O.A.S.I.S. Project Context

## Purpose

**O.A.S.I.S.** (Open-Source AI SIEM Intelligence System) is an open-source, AI-driven Security Information and Event Management (SIEM) platform that leverages local Large Language Models (LLMs) via the Model Context Protocol (MCP) for privacy-centric threat analysis without relying on external cloud AI providers.

**Key Goals:**
- Build a production-grade SIEM with AI-first design
- Enable privacy-centric threat analysis (no external AI APIs)
- Support multi-tenant architecture for managed security service providers (MSSPs)
- Standards-based log normalization (OCSF) and API definitions (OpenSpec)
- Scalable from development hardware to production infrastructure

**Target Audience:**
- Security Operations Centers (SOCs)
- Managed Security Service Providers (MSSPs)
- Enterprise security teams requiring on-premise AI
- Security researchers and open-source contributors

## Tech Stack

### Backend
- **Language:** Python 3.11+
- **Framework:** FastAPI (async REST APIs)
- **Databases:**
  - PostgreSQL 16+ (application data: tenants, users, API keys, configuration)
  - ClickHouse 23+ (columnar log storage with per-tenant tables)
  - Qdrant 1.7+ (vector database for semantic search - Phase 3)
- **Authentication:** JWT tokens (web portals), API keys (log ingestion)
- **Testing:** pytest, pytest-asyncio, pytest-cov (80% minimum coverage)
- **Linting:** Ruff, Black, mypy (strict type checking)

### Frontend
- **Framework:** Next.js 14+ (App Router)
- **Language:** TypeScript 5+
- **UI Library:** React 18+
- **Styling:** Tailwind CSS 3+
- **State Management:** React Context API (simple), Zustand (complex)
- **Testing:** Jest, React Testing Library (80% minimum coverage)
- **Linting:** ESLint, Prettier

### Infrastructure
- **Containerization:** Docker 24+, Docker Compose 2.20+
- **Orchestration (Dev):** Docker Compose (single-host development)
- **Orchestration (Prod):** Multi-host Docker, Docker Swarm, or Kubernetes (Phase 4+)
- **Networking:** Three-subnet architecture (DMZ, Internal, Backend)
- **Security:** mTLS between layers, AppArmor/Seccomp profiles

### AI/LLM (Phase 3)
- **LLM Runtime:** Ollama (local model serving)
- **Models:** Llama-3, Mistral, Deepseek (user-configurable)
- **Integration:** Model Context Protocol (MCP)
- **Vector Embeddings:** Qdrant with sentence-transformers

### CI/CD
- **Platform:** GitHub Actions
- **Security Scanning:** Trivy (vulnerabilities), gitleaks (secrets), Syft (SBOM)
- **Registry:** GitHub Container Registry (ghcr.io)

## Project Conventions

### Code Style

#### Python
- **Formatter:** Black (line length: 100)
- **Linter:** Ruff (fast all-in-one linter)
- **Type Checking:** mypy with `--strict` mode
- **Import Order:** isort (integrated into Ruff)
- **Docstrings:** Google-style docstrings for public functions/classes
- **Naming:**
  - Functions/variables: `snake_case`
  - Classes: `PascalCase`
  - Constants: `UPPER_SNAKE_CASE`
  - Private methods: `_leading_underscore`

#### TypeScript/JavaScript
- **Formatter:** Prettier (print width: 100)
- **Linter:** ESLint with Next.js config
- **Naming:**
  - Components: `PascalCase` (e.g., `DashboardCard.tsx`)
  - Functions/variables: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`
  - Files: `kebab-case` (except React components)

### Commit Conventions

**Format:** Conventional Commits (https://www.conventionalcommits.org/)

**Structure:**
```
<type>[optional scope]: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature (Phase completion, new capability)
- `fix`: Bug fix (restores intended behavior)
- `chore`: Maintenance (dependency updates, config changes)
- `docs`: Documentation changes
- `refactor`: Code restructuring (no behavior change)
- `test`: Test additions or modifications
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `style`: Code formatting (not CSS)
- `revert`: Revert previous commit

**Examples:**
```
feat(monitoring): add dynamic service status endpoint

Implements GET /api/services/status using Docker SDK.
Queries local Docker daemon for container health checks.

Closes #42

fix(ingestion): handle malformed syslog messages gracefully

chore(deps): update FastAPI to 0.109.0

docs: add Phase 1C to PHASE_TRACKER.md
```

**Rules:**
- Lowercase type and description
- Imperative mood ("add" not "added" or "adds")
- No period at end of description
- Body and footer are optional (use for complex changes)
- Reference issues/PRs in footer (e.g., `Closes #123`)

### Architecture Patterns

#### Three-Subnet Architecture
```
DMZ Subnet (172.20.0.0/24)
├─ External Gateway (172.20.0.10) - Internet-facing log collection
└─ Customer Portal (172.20.0.20) - Tenant user access (Phase 2)

Internal Subnet (172.21.0.0/24)
├─ Internal Gateway (172.21.0.10) - Corporate network logs
└─ SOC Portal (172.21.0.20) - Security team operations

Backend Subnet (172.22.0.0/24)
├─ Ingestion Service (172.22.0.30) - OCSF normalization
├─ API Service (172.22.0.40) - REST API
├─ ClickHouse (172.22.0.50) - Log storage
├─ PostgreSQL (172.22.0.60) - Application data
└─ Qdrant (172.22.0.70) - Vector database (Phase 3)
```

**Communication:**
- DMZ → Backend: mTLS only
- Internal → Backend: mTLS only
- Backend internal: No external exposure

#### Multi-Tenancy
- **Tenant Isolation:** Database-level (ClickHouse: per-tenant tables, PostgreSQL: tenant_id foreign keys)
- **API Keys:** Scoped to tenant, unique per integration
- **JWT Tokens:** Include `tenant_id` claim for web portal access
- **Rate Limiting:** Per-tenant ingestion rate limits
- **Resource Limits:** Configurable per-tenant (log retention TTL, query quotas)

#### Service Communication
- **Synchronous:** HTTP/REST with JSON payloads
- **Asynchronous:** (Future) Message queue for high-throughput ingestion (Phase 4+)
- **Authentication:** mTLS certificates for inter-service communication
- **Error Handling:** Graceful degradation, retry with exponential backoff

### Testing Strategy

**Coverage Requirements:**
- **Minimum:** 80% code coverage across all services
- **Critical Paths:** 100% coverage (authentication, authorization, log ingestion)
- **CI Enforcement:** Builds fail if coverage drops below 80%

**Test Types:**

#### Unit Tests
- **Backend:** pytest with fixtures for database mocks
- **Frontend:** Jest + React Testing Library
- **Scope:** Individual functions, classes, components
- **Mocking:** Use `unittest.mock` (Python), `jest.mock` (TypeScript)

#### Integration Tests
- **Scope:** Multi-service workflows (gateway → ingestion → ClickHouse)
- **Environment:** Docker Compose with test databases
- **Fixtures:** Seed data with realistic log samples

#### End-to-End Tests (Phase 4+)
- **Tool:** Playwright (browser automation)
- **Scope:** Full user workflows (login → create tenant → query logs)

**Test Organization:**
```
services/api-service/
├─ src/
│  └─ api/
│     └─ endpoints.py
└─ tests/
   ├─ unit/
   │  └─ test_endpoints.py
   └─ integration/
      └─ test_log_ingestion.py
```

### Git Workflow

**Branching Strategy:**
- **`main`:** Production-ready code ONLY (v1.0.0+). Protected, requires `--admin` flag to merge.
- **`develop`:** Active development, all phases merge here. Unprotected for fast iteration.
- **`feature/phase{number}`:** Phase development branches (e.g., `feature/phase1c`, `feature/phase2`).
- **`bugfix/*`:** Bug fixes (merge to `develop`).
- **`hotfix/*`:** Production emergencies (post-v1.0.0 only, merge to `main` then `develop`).

**Workflow:**
```
feature/phase1c → develop (merge when phase complete)
feature/phase1d → develop (merge when phase complete)
feature/phase2  → develop (merge when phase complete)
                    ↓
                 develop (all phases accumulate)
                    ↓
              (when v1.0.0 ready)
                    ↓
                  main (PR + gh pr merge --admin --squash)
                    ↓
                  Tag v1.0.0
```

**Decision Tree:**
```
Is this production-ready? (All phases complete + tested)
  ├─ YES → PR to main, use gh pr merge --admin
  └─ NO  → Merge to develop (direct push or simple PR)
```

**Key Rules:**
1. **NEVER merge to `main` until v1.0.0 ready** (all phases complete)
2. **ALWAYS check [PHASE_TRACKER.md](../PHASE_TRACKER.md) before branching/merging**
3. **Update PHASE_TRACKER.md "Last Updated" field when phase changes**
4. **Use Conventional Commits for all commits**
5. **Phase-based branch naming** (e.g., `feature/phase1c`, NOT `feature/add-endpoint`)

**For Complete Workflow:**
See [../GIT_WORKFLOW.md](../GIT_WORKFLOW.md) for detailed instructions and examples.

## Domain Context

### SIEM Concepts
- **Log Ingestion:** Collecting security events from endpoints, network devices, applications
- **Normalization:** Converting diverse log formats to standardized schema (OCSF)
- **Correlation:** Identifying relationships between events (e.g., failed logins → successful login)
- **Triage:** Prioritizing alerts by severity and business impact
- **Threat Hunting:** Proactive search for indicators of compromise (IOCs)
- **Incident Response:** Workflows for containment, eradication, recovery

### OCSF (Open Cybersecurity Schema Framework)
- **Purpose:** Vendor-neutral log schema for interoperability
- **Structure:** Event classes (e.g., `Authentication`, `Network Activity`, `File Activity`)
- **Attributes:** Common fields (timestamp, severity, actor, target, outcome)
- **Extensions:** Custom fields per event class
- **O.A.S.I.S. Usage:** All logs normalized to OCSF before storage

**Example OCSF Event:**
```json
{
  "class_name": "Authentication",
  "activity_id": 1,
  "activity_name": "Logon",
  "time": "2024-01-15T10:30:00Z",
  "severity_id": 1,
  "severity": "Informational",
  "actor": {
    "user": {
      "name": "jdoe",
      "uid": "1001"
    }
  },
  "dst_endpoint": {
    "ip": "10.0.1.50",
    "hostname": "workstation-42"
  },
  "outcome_id": 1,
  "outcome": "Success"
}
```

### Multi-Tenancy
- **Tenant:** Isolated customer environment (separate log storage, API keys, users)
- **Internal Tenant:** Reserved UUID (`ffffffff-ffff-ffff-ffff-ffffffffffff`) for O.A.S.I.S. system logs
- **Tenant Isolation:** Database-level (ClickHouse: separate tables, PostgreSQL: tenant_id foreign keys)
- **MSSP Use Case:** One O.A.S.I.S. instance serves multiple customers with complete data isolation

## Important Constraints

### Technical Constraints
- **Development Hardware:** 32GB RAM, 2TB NVMe storage
- **Resource Limits (Dev):**
  - ClickHouse: 12GB memory max
  - PostgreSQL: 2GB memory max
  - Qdrant: 2GB memory max
- **Platform:** Ubuntu 24.04 LTS (primary development/testing OS)
- **Python Version:** 3.11+ (for new async features and performance)
- **Node.js Version:** 20+ LTS (Next.js 14 requirement)

### Performance Constraints
- **Target Ingestion Rate:** 50,000 events per second (EPS) foundation
- **Query Latency:** <2 seconds for 90th percentile queries (1 million events)
- **Dashboard Load Time:** <3 seconds initial page load
- **Real-time Updates:** 30-second polling interval (Phase 1C+)

### Security Constraints
- **Authentication:** All APIs require authentication (JWT or API key)
- **Authorization:** Role-based access control (RBAC) enforced at API layer
- **Encryption:**
  - In-transit: TLS 1.3+ for all external connections, mTLS for inter-service
  - At-rest: Database encryption (Phase 4+)
- **Secrets Management:** Environment variables (dev), HashiCorp Vault (production - Phase 4+)
- **Vulnerability Scanning:** CI/CD fails on HIGH/CRITICAL Trivy findings
- **Secret Scanning:** gitleaks checks all commits

### Regulatory Constraints
- **GDPR Compliance:** User data deletion workflows (Phase 4+)
- **Audit Logging:** All configuration changes logged to `audit_logs` table
- **Data Retention:** Configurable per-tenant (default: 365 days)
- **No External AI APIs:** All LLM inference local/on-premise (privacy requirement)

## External Dependencies

### Required Services
- **ClickHouse:** Columnar database for log storage (https://clickhouse.com/)
- **PostgreSQL:** Relational database for application data (https://www.postgresql.org/)
- **Qdrant:** Vector database for semantic search (https://qdrant.tech/) - Phase 3+
- **Ollama:** Local LLM serving (https://ollama.com/) - Phase 3+

### Optional Integrations
- **Vector:** Log collection agent (https://vector.dev/) - Deployed on endpoints
- **Syslog Servers:** Network devices, legacy systems (RFC 5424, RFC 3164)
- **Cloud Providers:** AWS CloudTrail, Azure Monitor, GCP Cloud Logging (Phase 4+)

### Development Tools
- **Docker:** Container runtime (https://www.docker.com/)
- **Poetry:** Python dependency management (https://python-poetry.org/)
- **pnpm:** Fast Node.js package manager (https://pnpm.io/)
- **gh CLI:** GitHub command-line tool (https://cli.github.com/)
- **OpenSpec CLI:** Spec-driven development tool (https://openspec.dev/)

### CI/CD Dependencies
- **GitHub Actions:** Workflow automation (https://docs.github.com/en/actions)
- **Trivy:** Vulnerability scanner (https://trivy.dev/)
- **gitleaks:** Secret detection (https://github.com/gitleaks/gitleaks)
- **Syft:** SBOM generation (https://github.com/anchore/syft)

## Related Documentation

- [../PHASE_TRACKER.md](../PHASE_TRACKER.md) - Current phase status and roadmap
- [../GIT_WORKFLOW.md](../GIT_WORKFLOW.md) - Complete branching and commit strategy
- [../IMPROVEMENTS.md](../IMPROVEMENTS.md) - Phase requirements and technical details
- [../INDEX.md](../INDEX.md) - Complete documentation catalog
- [AGENTS.md](AGENTS.md) - AI assistant workflow instructions
