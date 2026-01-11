# Contributing to O.A.S.I.S.

Thank you for your interest in contributing to the Open-Source AI SIEM Intelligence System! This document provides guidelines for contributing to the project.

## Table of Contents
- [Pull Request Conventions](#pull-request-conventions)
- [Git Workflow](#git-workflow)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Security Guidelines](#security-guidelines)

---

## Pull Request Conventions

### PR Title Format

We follow [Conventional Commits](https://www.conventionalcommits.org/) for PR titles. Use one of these prefixes:

- `feat:` - New feature or functionality
- `fix:` - Bug fix
- `refactor:` - Code refactoring without feature changes
- `perf:` - Performance improvements
- `test:` - Adding or updating tests
- `docs:` - Documentation changes only
- `chore:` - Maintenance tasks, typos, formatting, dependency updates
- `ci:` - CI/CD pipeline changes
- `security:` - Security-related changes

**Examples:**
- `feat: add multi-tenant log ingestion with rate limiting`
- `fix: resolve ClickHouse connection timeout on startup`
- `docs: update Fluent Bit agent deployment guide`
- `chore: fix typo in README`

### Chore PRs (Skip Heavy CI)

If your change only updates documentation, fixes typos, or performs other non-functional maintenance tasks, please prefix your pull request title with `chore:` (case-insensitive). Pull requests with titles starting with `chore:` will skip the repository's heavy CI jobs (security scans, Docker builds, integration tests), while still running a lightweight validation check required by branch protection.

**When to use `chore:`**
- Documentation updates (README, guides, comments)
- Typo fixes
- Code formatting/linting fixes
- Dependency version updates (no code changes)
- Configuration file updates (gitignore, editor configs)

**When NOT to use `chore:`**
- Any code logic changes (use `feat:`, `fix:`, `refactor:`, etc.)
- Test additions or modifications (use `test:`)
- Security-related changes (use `security:`)
- Performance improvements (use `perf:`)

**Examples:**
- `chore: fix typo in API service documentation`
- `chore: update CONTRIBUTING guide with PR conventions`
- `Chore: format Docker Compose files`

**Note:** This convention helps preserve CI resources while maintaining branch protection requirements. Non-chore PRs will run the full CI pipeline including linting, type checking, tests, security scanning, and Docker image builds.

---

## Git Workflow

Please follow the Git workflow documented in [GIT_WORKFLOW.md](./GIT_WORKFLOW.md):

1. **Branch from `develop`**: All feature branches start from `develop`
2. **Use descriptive branch names**: `feature/add-fluent-bit-agent`, `fix/clickhouse-timeout`
3. **Keep commits atomic**: One logical change per commit
4. **Write clear commit messages**: Follow conventional commit format
5. **Rebase before PR**: Ensure your branch is up-to-date with `develop`
6. **Request review**: PRs require at least 1 approval from @0xgruber

---

## Code Standards

### Python (Backend Services)

- **Linting**: Use `ruff` for linting, `black` for formatting
- **Type hints**: All functions must have type annotations
- **Type checking**: Code must pass `mypy --strict`
- **Docstrings**: Use Google-style docstrings for all public functions/classes
- **Testing**: Minimum 80% code coverage

**Example:**
```python
def process_log_entry(entry: dict[str, Any], tenant_id: str) -> LogEntry:
    """Process and validate a raw log entry.
    
    Args:
        entry: Raw log data from ingestion gateway
        tenant_id: UUID of the tenant submitting the log
        
    Returns:
        Validated LogEntry object ready for storage
        
    Raises:
        ValidationError: If log entry is malformed
    """
    # Implementation...
```

### TypeScript (Frontend)

- **Linting**: Use ESLint with `@typescript-eslint`
- **Formatting**: Use Prettier
- **Type safety**: Use strict TypeScript configuration
- **Component structure**: Follow React best practices
- **Testing**: Unit tests with React Testing Library

### Docker

- **Multi-stage builds**: Minimize final image size
- **Non-root user**: Run services as non-root
- **Health checks**: Include HEALTHCHECK in all service images
- **Labels**: Add OCI labels (version, commit, build date)

---

## Testing Requirements

All PRs must include tests and maintain minimum 80% code coverage:

### Unit Tests
- Test individual functions and classes in isolation
- Mock external dependencies (databases, APIs)
- Cover edge cases and error conditions

### Integration Tests
- Test service interactions via Docker Compose
- Validate API endpoints end-to-end
- Test database operations with real ClickHouse/PostgreSQL

### Performance Tests
- Benchmark ingestion throughput
- Validate query response times
- Test rate limiting behavior

**Running tests locally:**
```bash
# Backend unit tests
cd services/<service-name>
poetry run pytest --cov=. --cov-report=html

# Frontend tests
cd frontend
npm test -- --coverage

# Integration tests
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

---

## Security Guidelines

### Security Scanning

All code must pass security checks before merge:

- **Trivy**: No HIGH or CRITICAL vulnerabilities in dependencies or Docker images
- **gitleaks**: No secrets or credentials committed
- **Syft**: SBOM (Software Bill of Materials) generated for all images

### Secure Coding Practices

- **Input validation**: Validate all user input at API boundaries
- **SQL injection**: Use parameterized queries, never string concatenation
- **Authentication**: Use JWT tokens with short expiry (15 minutes)
- **Authorization**: Enforce RBAC on all protected endpoints
- **Secrets**: Never commit secrets; use environment variables
- **Dependencies**: Keep dependencies up-to-date with Dependabot

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities. Instead, follow the process in [SECURITY.md](./SECURITY.md) to report privately.

---

## Development Setup

### Prerequisites

- **Git**: For version control
- **Docker & Docker Compose**: For local development environment
- **Poetry**: For Python dependency management (backend)
- **Node.js 20+**: For frontend development
- **OpenSpec CLI**: For validating proposals (`npm install -g openspec`)

### Local Environment

```bash
# Clone repository
git clone git@github.com:0xgruber/oasis.git
cd oasis

# Checkout develop branch
git checkout develop

# Start services (when implemented)
docker compose up -d

# Check service health
docker compose ps
```

### Making Changes

1. Create feature branch from `develop`
2. Make your changes with atomic commits
3. Write/update tests for your changes
4. Run linters and tests locally
5. Push branch and open PR to `develop`
6. Address review feedback
7. Squash or merge after approval

---

## Questions?

- Check [README.md](./README.md) for project overview
- Review [GIT_WORKFLOW.md](./GIT_WORKFLOW.md) for branching details
- See [CI_CD_PIPELINE.md](./CI_CD_PIPELINE.md) for CI/CD specifics
- Read OpenSpec proposals in `openspec/changes/`

For questions not covered in documentation, open a discussion on GitHub.

---

**Thank you for contributing to O.A.S.I.S.!** 🚀
