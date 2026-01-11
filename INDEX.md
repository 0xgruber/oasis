# O.A.S.I.S. Documentation Index

**Last Updated:** 2026-01-11

Complete catalog of project documentation organized by category.

## 🚀 Quick Navigation

**I'm a...**
- **New Developer** → Start with [README.md](README.md), then [GIT_WORKFLOW.md](GIT_WORKFLOW.md)
- **Contributor** → Read [CONTRIBUTING.md](CONTRIBUTING.md) and [openspec/AGENTS.md](openspec/AGENTS.md)
- **AI Assistant** → Check [openspec/AGENTS.md](openspec/AGENTS.md) and [PHASE_TRACKER.md](PHASE_TRACKER.md)
- **Security Researcher** → See [SECURITY.md](SECURITY.md)

## 📚 Documentation by Category

### Project Management
| Document | Description | Audience |
|----------|-------------|----------|
| [PHASE_TRACKER.md](PHASE_TRACKER.md) | Current phase status and roadmap tracker | All |
| [IMPROVEMENTS.md](IMPROVEMENTS.md) | Phase requirements and feature details | Developers |
| [CHANGELOG.md](CHANGELOG.md) | Release history and version notes | All |

### Development Workflow
| Document | Description | Audience |
|----------|-------------|----------|
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | Branching strategy, commit conventions, PR process | Developers, AI |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute to the project | Contributors |
| [TESTING.md](TESTING.md) | Test strategy, coverage requirements, running tests | Developers |

### OpenSpec Documentation
| Document | Description | Audience |
|----------|-------------|----------|
| [openspec/AGENTS.md](openspec/AGENTS.md) | AI assistant workflow instructions (CRITICAL) | AI Assistants |
| [openspec/project.md](openspec/project.md) | Project conventions, tech stack, constraints | AI Assistants, Developers |
| [openspec/specs/](openspec/specs/) | Current capabilities (what IS built) | Developers, AI |
| [openspec/changes/](openspec/changes/) | Active proposals (what SHOULD change) | Developers, AI |

### Architecture & Design
| Document | Description | Audience |
|----------|-------------|----------|
| [README.md](README.md) | Project overview, architecture, tech stack | All |
| [openspec/changes/*/design.md](openspec/changes/) | Technical design decisions | Developers |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Deep dive into system architecture (coming soon) | Developers |

### Backend Services
| Document | Description | Audience |
|----------|-------------|----------|
| [services/external-gateway/README.md](services/external-gateway/README.md) | External gateway service documentation | Developers |
| [services/internal-gateway/README.md](services/internal-gateway/README.md) | Internal gateway service documentation | Developers |
| [services/ingestion-service/README.md](services/ingestion-service/README.md) | Ingestion service documentation | Developers |
| [services/api-service/README.md](services/api-service/README.md) | API service documentation | Developers |
| [services/metrics-service/README.md](services/metrics-service/README.md) | Metrics service documentation | Developers |

### Frontend
| Document | Description | Audience |
|----------|-------------|----------|
| [frontend/soc-portal/README.md](frontend/soc-portal/README.md) | SOC Portal documentation | Developers |
| [UI_COMPONENTS.md](UI_COMPONENTS.md) | Reusable component library (coming soon) | Developers |

### Security & Operations
| Document | Description | Audience |
|----------|-------------|----------|
| [SECURITY.md](SECURITY.md) | Security policy and vulnerability reporting | All |
| [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md) | CI/CD workflow and deployment process | DevOps, Developers |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Production deployment guide (coming soon) | DevOps |

### AI Assistant Configuration
| Document | Description | Audience |
|----------|-------------|----------|
| [AGENTS.md](AGENTS.md) | AI assistant workflow and git workflow instructions | AI Assistants (symlink to openspec/AGENTS.md) |

## 🔍 Finding Documentation

**By Task:**
- **Creating a feature** → [openspec/AGENTS.md](openspec/AGENTS.md) → [PHASE_TRACKER.md](PHASE_TRACKER.md)
- **Fixing a bug** → [GIT_WORKFLOW.md](GIT_WORKFLOW.md) → Service-specific README
- **Reviewing code** → [CONTRIBUTING.md](CONTRIBUTING.md)
- **Running tests** → [TESTING.md](TESTING.md)
- **Deploying** → [CI_CD_PIPELINE.md](CI_CD_PIPELINE.md) → [DEPLOYMENT.md](DEPLOYMENT.md)

**By Phase:**
- **Phase 1** → [PHASE_TRACKER.md](PHASE_TRACKER.md) (complete)
- **Phase 2-5** → [PHASE_TRACKER.md](PHASE_TRACKER.md)

## 📖 Documentation Standards

**Format:** GitHub-flavored Markdown (`.md` files)  
**Style:** Concise, scannable, actionable  
**Code Examples:** Use triple backticks with language tags  
**Links:** Relative paths within repository  
**Maintenance:** "Last Updated" fields in key documents

## 🤝 Contributing to Documentation

Documentation improvements are welcome! Please:
1. Follow existing formatting and structure
2. Update "Last Updated" fields when editing
3. Add new documents to this INDEX.md
4. Use conventional commits: `docs: update INDEX.md`
5. See [CONTRIBUTING.md](CONTRIBUTING.md) for PR process

## 📌 Related Resources

**External Documentation:**
- [OCSF Schema](https://schema.ocsf.io/) - Log normalization standard
- [OpenSpec](https://github.com/openspec-dev/openspec) - Spec-driven development framework
- [Docker Compose](https://docs.docker.com/compose/) - Container orchestration
- [FastAPI](https://fastapi.tiangolo.com/) - Backend framework
- [Next.js](https://nextjs.org/docs) - Frontend framework

---

**Not finding what you need?** Open an issue or check [CONTRIBUTING.md](CONTRIBUTING.md) to add new documentation.
