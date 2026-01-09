# O.A.S.I.S.

**Open-Source AI SIEM Intelligence System**

O.A.S.I.S. is an open-source, AI-driven Security Information and Event Management (SIEM) platform that leverages local Large Language Models (LLMs) via the Model Context Protocol (MCP) for privacy-centric threat analysis without relying on external cloud AI providers.

## Key Features

- **AI-First Design**: Deep integration of local LLMs for natural language search, automated triage, and intelligent reporting
- **Privacy-Centric**: All AI processing occurs locally/on-premise - no external API dependencies
- **Multi-Tenant Architecture**: Support multiple customers with isolated data and configurable policies
- **Standards-Based**: OCSF (Open Cybersecurity Schema Framework) for log normalization, OpenSpec for API definitions
- **Scalable Architecture**: Designed for development on consumer-grade hardware, production deployment on server infrastructure
- **Distributed Deployment**: GPU/VRAM-intensive AI services can run on dedicated hardware separate from core SIEM services

## Architecture Overview

O.A.S.I.S. uses a three-subnet architecture for defense in depth:

- **DMZ Subnet**: External gateway for internet-facing log collection, customer portal for tenant access
- **Internal Subnet**: Internal gateway for corporate network logs, SOC portal for security team operations
- **Backend Subnet**: Ingestion services, API services, and multi-tier storage (ClickHouse, PostgreSQL, Qdrant)

### Core Components

- **Gateways (External/Internal)**: Smart ingestion points with API key authentication, rate limiting, and input validation
- **Ingestion Service**: OCSF normalization and routing to appropriate storage backends
- **API Service**: Authentication, log queries, configuration management for web portals
- **Storage Layer**:
  - ClickHouse: Columnar log storage with per-tenant tables and high compression
  - PostgreSQL: Application data (tenants, users, API keys, configuration, audit logs)
  - Qdrant: Vector database for semantic search (Phase 3)
- **Web Portals**:
  - SOC Portal: Comprehensive management interface for security operations teams
  - Customer Portal: Limited tenant-specific views for external customers (Phase 2)
- **AI Services** (Phase 3): Local LLM inference via Ollama, deployable on separate GPU-enabled hardware

### Log Collection

- **Vector Agents**: Deployed on Windows/Linux/macOS endpoints with example configurations included
- **Syslog**: UDP/TCP/TLS support for network devices and legacy systems
- **Direct HTTP/JSON**: API endpoints for custom integrations

## Technology Stack

- **Backend**: Python 3.11+ with FastAPI
- **Frontend**: Next.js 14+ with React, TypeScript, and Tailwind CSS
- **Databases**: ClickHouse (logs), PostgreSQL (app data), Qdrant (vectors)
- **AI/LLM**: Ollama serving local models (Llama-3, Mistral) with MCP integration
- **Deployment**: Docker Compose for development, multi-host Docker for production
- **CI/CD**: GitHub Actions with security scanning (Trivy, Syft, gitleaks)

## Development Constraints

- **Development Environment**: 32GB RAM, 2TB NVMe storage
- **Production**: Scalable server infrastructure with flexible resource allocation
- **Platform**: Ubuntu 24.04 LTS
- **Performance Target**: Foundation for 50k events per second (EPS) ingestion rate

## Project Phases

### Phase 1: Foundation (Current - Weeks 1-7+)
- Core infrastructure (gateways, ingestion, storage)
- Multi-tenant database architecture
- SOC portal with comprehensive configuration UI
- Vector agent integration
- CI/CD pipeline with security scanning

### Phase 2: Visibility (Weeks 8-12)
- Customer portal for tenant users
- Advanced RBAC and user management
- Enhanced search and filtering
- Access audit trail

### Phase 3: The Brain (Weeks 13-17)
- Local LLM integration via MCP
- Natural language query interface
- Semantic search with vector embeddings
- AI-powered log analysis

### Phase 4: Operations & Polish (Weeks 18-21)
- Alerting engine with detection rules
- Automated triage and reporting
- Performance optimization and benchmarking
- Full documentation site

## Security Model

- **Network Segmentation**: DMZ, Internal, and Backend subnets with mTLS between layers
- **Authentication**: API keys for log ingestion, JWT tokens for web portals, database credentials for services
- **Multi-Factor Authentication**: TOTP support for all user accounts (planned)
- **Audit Logging**: Complete audit trail of all configuration changes and sensitive operations
- **Hardening**: Non-root containers, AppArmor/Seccomp profiles, automated vulnerability scanning

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines (coming soon).

## Security

For security vulnerabilities, please see our [Security Policy](SECURITY.md).

## Project Status

**Current Phase**: Phase 0 - Initial setup and documentation

This project is in active development. The OpenSpec proposal for Phase 1 is currently being finalized.

## Repository Structure

```
oasis/
├── backend/           # Python/FastAPI services (coming soon)
├── frontend/          # Next.js application (coming soon)
├── infrastructure/    # Docker, configs, Vector examples (coming soon)
├── docs/             # Documentation (coming soon)
├── openspec/         # OpenSpec specifications and proposals
├── LICENSE           # MIT License
├── README.md         # This file
└── SECURITY.md       # Security policy
```

## Acknowledgments

- **OCSF**: Open Cybersecurity Schema Framework for log normalization
- **Vector**: High-performance log collection agent by Datadog
- **Ollama**: Local LLM inference engine
- **Model Context Protocol (MCP)**: Standard for LLM-application integration

---

**O.A.S.I.S.** - Where intelligence meets security, privately.
