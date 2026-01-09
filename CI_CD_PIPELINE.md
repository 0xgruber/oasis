# CI/CD Pipeline

This document describes the Continuous Integration and Continuous Deployment pipeline for the O.A.S.I.S. project using GitHub Actions.

## Overview

The CI/CD pipeline runs on every push and pull request to ensure code quality, security, and functionality. It consists of linting, type checking, testing, security scanning, and Docker image building.

## CI Optimization: Chore PRs

To preserve CI resources, pull requests with titles starting with `chore:` (case-insensitive) will skip heavy CI jobs while still running a lightweight validation check required by branch protection.

**When heavy tests are skipped:**
- PR titles starting with `chore:`, `Chore:`, or `CHORE:`
- Examples: `chore: fix typo in README`, `Chore: update docs`

**When heavy tests always run:**
- All `push` events to `main` or `develop`
- Pull requests with any non-chore prefix (`feat:`, `fix:`, `refactor:`, etc.)

**Why this matters:**
- Heavy CI includes security scanning (Trivy), Docker image builds, integration tests
- Can take 5-10+ minutes per run
- Chore PRs (docs, typos, formatting) don't need full validation
- Branch protection is still satisfied by the lightweight validation job

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed PR title conventions.

## Workflows

### 1. CI Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main` or `develop`

**Platform:** Ubuntu 24.04 LTS

**Jobs:**

#### Lightweight Validation (Always Runs)
- Quick validation check (~5 seconds)
- Satisfies branch protection requirements
- Indicates whether heavy tests will run based on PR title

#### Heavy CI Pipeline (Conditional)
- **Runs on:** All `push` events, non-chore PRs
- **Skips on:** Pull requests with `chore:` prefix
- **Timeout:** 30 minutes

**Stages:**

#### Stage 1: Linting & Formatting (Parallel)

**Python:**
```yaml
- name: Lint Python with Ruff
  run: ruff check backend/
  
- name: Check Python formatting with Black
  run: black --check backend/
```

**TypeScript:**
```yaml
- name: Lint TypeScript with ESLint
  run: npm run lint
  working-directory: frontend
  
- name: Check TypeScript formatting with Prettier
  run: npm run format:check
  working-directory: frontend
```

**YAML/JSON:**
```yaml
- name: Lint YAML
  run: yamllint .

- name: Lint JSON
  run: jsonlint .
```

#### Stage 2: Type Checking (Parallel with Linting)

**Python:**
```yaml
- name: Type check Python with mypy
  run: mypy backend/ --strict
```

**TypeScript:**
```yaml
- name: Type check TypeScript
  run: npm run type-check
  working-directory: frontend
```

#### Stage 3: Unit Tests (After Linting/Type Checking)

**Python:**
```yaml
- name: Run Python unit tests
  run: pytest backend/tests/unit --cov=backend --cov-report=xml --cov-report=term
  
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    flags: backend
```

**Coverage Requirement:** 80% minimum

**TypeScript:**
```yaml
- name: Run TypeScript unit tests
  run: npm run test:unit -- --coverage
  working-directory: frontend
  
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./frontend/coverage/coverage-final.json
    flags: frontend
```

**Coverage Requirement:** 80% minimum

#### Stage 4: Security Scanning (Parallel)

**Vulnerability Scanning with Trivy:**
```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    severity: 'HIGH,CRITICAL'
    exit-code: '1'  # Fail build if HIGH/CRITICAL found
    ignore-unfixed: true
```

**Secret Scanning with Gitleaks:**
```yaml
- name: Run Gitleaks secret scanner
  uses: gitleaks/gitleaks-action@v2
  with:
    path: '.'
    args: '--verbose --redact'
```

**SBOM Generation with Syft:**
```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    format: spdx-json
    output-file: sbom.json
    upload-artifact: true
```

#### Stage 5: Integration Tests (After Unit Tests)

```yaml
- name: Start services with Docker Compose
  run: docker-compose -f docker-compose.test.yml up -d
  
- name: Wait for services to be healthy
  run: |
    timeout 60s bash -c 'until docker-compose -f docker-compose.test.yml ps | grep -q "healthy"; do sleep 2; done'
  
- name: Run integration tests
  run: pytest backend/tests/integration
  
- name: Stop services
  if: always()
  run: docker-compose -f docker-compose.test.yml down -v
```

#### Stage 6: Docker Build (develop/main only)

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v2
  
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v2
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GHCR_TOKEN }}
  
- name: Build and push Docker images
  uses: docker/build-push-action@v4
  with:
    context: ./backend/ingestion
    platforms: linux/amd64,linux/arm64
    push: ${{ github.ref == 'refs/heads/develop' || github.ref == 'refs/heads/main' }}
    tags: |
      ghcr.io/0xgruber/oasis-ingestion:${{ github.sha }}
      ghcr.io/0xgruber/oasis-ingestion:${{ github.ref_name == 'main' && 'latest' || 'latest-dev' }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Images Built:**
- `oasis-ingestion`
- `oasis-api`
- `oasis-gateway`
- `oasis-portal`

**Tags:**
- Commit SHA: `sha-abc123`
- `latest` (main branch)
- `latest-dev` (develop branch)

### 2. Release Workflow (`.github/workflows/release.yml`)

**Triggers:** Push tag `v*` (e.g., `v1.0.0`)

**Steps:**
1. Run full CI pipeline
2. Build production Docker images with version tag
3. Generate release notes from conventional commits
4. Create GitHub Release with changelog
5. Push Docker images to GHCR with version tags

```yaml
- name: Generate changelog
  id: changelog
  uses: conventional-changelog/conventional-changelog-action@v3
  
- name: Create GitHub Release
  uses: actions/create-release@v1
  with:
    tag_name: ${{ github.ref }}
    release_name: Release ${{ github.ref }}
    body: ${{ steps.changelog.outputs.clean_changelog }}
```

### 3. Dependency Updates (Dependabot)

**Configuration:** `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/frontend"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 10
    
  - package-ecosystem: "pip"
    directory: "/backend"
    schedule:
      interval: "monthly"
    open-pull-requests-limit: 10
    
  - package-ecosystem: "docker"
    directory: "/infrastructure/docker"
    schedule:
      interval: "monthly"
```

**Auto-merge:** Minor/patch updates auto-merge if CI passes (future)

## Test Matrix

### Python Tests
- **Python Versions:** 3.11, 3.12
- **OS:** Ubuntu 24.04 LTS

### TypeScript Tests
- **Node.js Versions:** 20.x LTS
- **OS:** Ubuntu 24.04 LTS

### Docker Builds
- **Architectures:** `linux/amd64`, `linux/arm64`

## CI/CD Environment Variables

### Required Secrets (GitHub Secrets)

```bash
GHCR_TOKEN          # GitHub token for pushing to ghcr.io
CODECOV_TOKEN       # Token for uploading coverage reports
```

### Environment Variables (per job)

```yaml
env:
  PYTHONUNBUFFERED: 1
  DOCKER_BUILDKIT: 1
  COMPOSE_DOCKER_CLI_BUILD: 1
  NODE_ENV: test
```

## Resource Limits for CI

### GitHub Actions Runners
- **OS:** Ubuntu 24.04 LTS
- **CPU:** 2 cores
- **RAM:** 7GB
- **Disk:** 14GB SSD

### Docker Compose for Integration Tests
```yaml
services:
  clickhouse:
    mem_limit: 2g
  postgres:
    mem_limit: 1g
  ingestion:
    mem_limit: 1g
  api:
    mem_limit: 1g
  gateway:
    mem_limit: 512m
```

## Caching Strategy

### Python Dependencies
```yaml
- name: Cache pip packages
  uses: actions/cache@v3
  with:
    path: ~/.cache/pip
    key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
    restore-keys: |
      ${{ runner.os }}-pip-
```

### Node.js Dependencies
```yaml
- name: Cache npm packages
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

### Docker Layers
```yaml
- name: Cache Docker layers
  uses: docker/build-push-action@v4
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Cache Benefits:**
- Reduces build time from ~10min to ~2min
- Saves bandwidth for dependencies

## Notifications

### Pull Request Checks
- Status checks visible in PR UI
- ✅ Green checkmark if all pass
- ❌ Red X if any fail (blocks merge)

### Failed Builds
- GitHub notifications to PR author
- Email notification (configurable)

### Optional: Slack Webhook (Phase 2)
```yaml
- name: Notify Slack on failure
  if: failure() && (github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop')
  uses: slackapi/slack-github-action@v1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Build failed on ${{ github.ref }}"
      }
```

## Security Scanning Details

### Trivy Configuration

**Scan Types:**
- Filesystem scan (source code)
- Docker image scan (after build)

**Severity Levels:**
- HIGH
- CRITICAL

**Ignore unfixed:** True (don't fail on vulnerabilities with no fix available)

**Example Output:**
```
┌───────────────────┬──────────────────┬──────────┬───────────────────┐
│      Library      │  Vulnerability   │ Severity │ Installed Version │
├───────────────────┼──────────────────┼──────────┼───────────────────┤
│ fastapi           │ CVE-2023-12345   │ HIGH     │ 0.100.0           │
│ clickhouse-driver │ CVE-2023-67890   │ CRITICAL │ 0.5.0             │
└───────────────────┴──────────────────┴──────────┴───────────────────┘
```

### Gitleaks Configuration

**Scans for:**
- AWS keys
- API tokens
- Private keys
- Database passwords
- JWT secrets

**Example Output:**
```
Finding:  AWS Access Key
Secret:   AKIAIOSFODNN7EXAMPLE
File:     config/secrets.py
Line:     42
```

### SBOM (Software Bill of Materials)

**Format:** SPDX JSON

**Includes:**
- All Python packages (pip)
- All npm packages
- Base Docker images

**Use Cases:**
- Vulnerability tracking
- License compliance
- Supply chain security

## Performance Benchmarks

### Typical CI Pipeline Duration

| Stage | Duration |
|-------|----------|
| Linting & Type Checking | ~1min |
| Unit Tests | ~2min |
| Security Scanning | ~2min |
| Integration Tests | ~3min |
| Docker Builds (cached) | ~2min |
| **Total** | **~10min** |

**First run (no cache):** ~15-20min

## Troubleshooting

### Build Fails on Linting
```bash
# Run locally
ruff check backend/
black --check backend/

# Fix automatically
ruff check backend/ --fix
black backend/
```

### Test Coverage Below 80%
```bash
# Run with coverage report
pytest backend/tests/unit --cov=backend --cov-report=html

# Open report
open htmlcov/index.html
```

### Docker Build Fails
```bash
# Test build locally
docker build -t oasis-api backend/api

# Check logs
docker logs <container-id>
```

### Integration Tests Fail
```bash
# Run integration tests locally
docker-compose -f docker-compose.test.yml up -d
pytest backend/tests/integration -v
docker-compose -f docker-compose.test.yml logs
```

## Best Practices

1. **Run CI locally before push:** Use `pre-commit` hooks
2. **Fix linting first:** Fastest stage to fix
3. **Write tests before code:** Test-driven development
4. **Monitor coverage:** Don't let it drop below 80%
5. **Review security scan results:** Address HIGH/CRITICAL before merge
6. **Use Docker layer caching:** Significantly speeds up builds
7. **Keep dependencies updated:** Monthly Dependabot PRs

## Future Enhancements (Phase 2+)

- [ ] Performance regression testing
- [ ] Automated security penetration testing (OWASP ZAP)
- [ ] Load testing with k6 or Locust
- [ ] Kubernetes manifest validation
- [ ] Helm chart linting
- [ ] Database migration testing
- [ ] End-to-end UI testing with Playwright
- [ ] Canary deployments to staging
- [ ] Automated rollback on production errors

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Codecov Documentation](https://docs.codecov.com/)
