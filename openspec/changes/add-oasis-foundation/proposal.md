# Change: Add O.A.S.I.S. Foundation (Phase 1)

## Why

The O.A.S.I.S. (OSS AI SIEM Intelligence System) project requires a foundational architecture to support AI-driven security intelligence. This is the initial implementation (Phase 1) to establish core infrastructure for log ingestion, storage, and basic visualization.

The system is designed to be developed on consumer-grade hardware (32GB RAM, RTX 4070 Ti Super) but architectured for production deployment on server infrastructure with higher resource availability. The architecture supports distributed deployment where GPU/VRAM-intensive services (LLM inference) can run on dedicated hardware separate from core SIEM services.

The current landscape lacks an open-source SIEM that deeply integrates local LLMs via Model Context Protocol (MCP) for privacy-centric threat analysis without relying on external cloud AI providers.

## What Changes

### Phase 1: Foundation (Weeks 1-3)
- Initialize monorepo structure with proper governance (LICENSE, CONTRIBUTING.md)
- Set up Docker Compose environment with three database systems:
  - ClickHouse for columnar log storage (high compression)
  - PostgreSQL for application data (users, alerts, config)
  - Qdrant for semantic search vectors
- Integrate syslog-ng as the primary log collection agent (reduce development overhead)
- Implement basic ingestion service accepting HTTP/JSON and syslog-ng output
- Create OCSF (Open Cybersecurity Schema Framework) normalization pipeline
- Establish data routing logic: raw logs → ClickHouse, embeddings → Qdrant
- Design distributed architecture supporting separate GPU/VRAM service deployment
- Set up CI/CD with security scanning (SBOM generation, vulnerability scanning)
- Initialize web frontend with authentication stubs

### Technical Foundation
- Monorepo with clear separation: `/backend`, `/frontend`, `/infrastructure`
- Python (FastAPI) or Go for backend services
- Next.js/React for frontend
- Syslog-ng for log collection and initial processing
- OpenSpec for API definitions, OCSF for log schema normalization
- Development constraints: 32GB RAM, 2TB NVMe (production: scalable server infrastructure)
- Distributed deployment support: GPU services isolated in separate containers/instances

## Impact

### New Capabilities
- **data-ingestion**: Log reception and OCSF normalization
- **log-storage**: Multi-tier storage strategy (ClickHouse + Qdrant + PostgreSQL)
- **web-frontend**: Basic dashboard and authentication framework
- **ai-intelligence**: MCP infrastructure preparation (no LLM integration in Phase 1)

### Infrastructure
- Docker Compose environment for local development (32GB RAM constraint)
- Production deployment architecture supporting server-grade resources
- Distributed service model for GPU/VRAM workloads (separate container/instance deployment)
- CI/CD pipeline with security scanning
- Repository structure and governance documents
- Integration with syslog-ng for log collection

### Out of Scope for Phase 1
- LLM/MCP integration (Phase 3)
- Alert engine and reporting (Phase 4)
- Advanced search and analytics
- RBAC and multi-tenancy

### Performance Targets
- Development: Operate within 32GB RAM constraint
- Production: Scalable to server infrastructure with appropriate resource allocation
- Foundation for 50k EPS (Events Per Second) ingestion rate
- Database schemas optimized for write-heavy workloads
- GPU/VRAM services deployable on dedicated hardware for optimal performance

### Breaking Changes
None - this is the initial implementation.
