# Git Workflow

This document describes the Git branching strategy, commit conventions, and PR process for the O.A.S.I.S. project.

## Branch Structure

### Main Branches
- **`main`**: Production-ready code, always deployable, protected
- **`develop`**: Integration branch for features, protected

### Supporting Branches
- **Feature branches**: `feature/{ticket-id}-{short-description}`
  - Example: `feature/OASIS-123-add-tenant-mgmt`
- **Bugfix branches**: `bugfix/{ticket-id}-{short-description}`
  - Example: `bugfix/OASIS-456-fix-race-condition`
- **Hotfix branches**: `hotfix/{ticket-id}-{short-description}`
  - Example: `hotfix/OASIS-789-security-patch`
  - Used for production emergencies only

## Commit Conventions

We use **Conventional Commits** for all commits:

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `chore`: Maintenance, no functional change
- `docs`: Documentation only
- `refactor`: Code restructuring, no behavior change
- `test`: Test additions or modifications
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `style`: Code formatting (not CSS)
- `revert`: Revert previous commit

### Commit Message Format
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Examples

**Feature commit:**
```
feat(api): Add JWT authentication middleware

Implement JWT validation for all API endpoints with role-based
access control. Tokens expire after 1 hour and include tenant_id claim.

Closes #42
```

**Bugfix commit:**
```
fix(ingestion): Handle malformed syslog messages gracefully

Previously, invalid syslog messages would crash the ingestion service.
Now, malformed messages are logged to error queue and processing continues.

Fixes #128
```

**Chore commit:**
```
chore(deps): Update Python dependencies

- Update FastAPI to 0.109.0
- Update ClickHouse client to 0.6.0
```

## Branching Workflow

### 1. Create Feature Branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/OASIS-123-add-tenant-mgmt
```

### 2. Develop and Commit

```bash
# Make changes
git add .
git commit -m "feat(ui): Add tenant CRUD UI components"
```

### 3. Keep Branch Up-to-Date

```bash
git fetch origin
git rebase origin/develop
```

**Resolve conflicts if any:**
```bash
# Fix conflicts in files
git add <resolved-files>
git rebase --continue
```

### 4. Push and Create PR

```bash
git push -u origin feature/OASIS-123-add-tenant-mgmt
gh pr create --base develop --title "feat: Add tenant management UI" --body "Implements tenant CRUD operations with API key management"
```

### 5. Code Review

- PR auto-assigned to @0xgruber via CODEOWNERS
- Requires 1 approval
- Must pass all CI checks (linting, tests, security scans)
- Dismiss stale reviews if new changes pushed

### 6. Merge to Develop

**Via GitHub UI: "Squash and merge"**
- Single commit per PR for clean history
- Commit message: PR title + body

**Command line (if needed):**
```bash
git checkout develop
git pull origin develop
git merge --squash feature/OASIS-123-add-tenant-mgmt
git commit -m "feat: Add tenant management UI

Implements tenant CRUD operations with API key management

Closes #123"
git push origin develop
```

### 7. Production Release to Main (Only When v1.0.0 Ready)

**CRITICAL:** Do NOT merge to `main` until ALL phases complete and production-ready.

**Decision Tree:**
```
Is this production-ready? (All phases complete + tested)
  ├─ YES → Continue below (PR to main)
  └─ NO  → Merge to develop instead (stop here)
```

**When Ready for Production (v1.0.0):**
```bash
# 1. Ensure all phases complete (check PHASE_TRACKER.md)
# 2. Create PR from develop to main
gh pr create --base main --head develop --title "chore: Release v1.0.0" --body "Production release - all phases complete"

# 3. Merge using admin flag (main is protected)
gh pr merge --admin --squash

# 4. Tag the release
git checkout main
git pull origin main
git tag v1.0.0
git push origin main --tags
```

**Why `--admin` flag?**
- `main` branch has protection rules (requires PR + approval)
- `--admin` bypasses protection for authorized users
- Use ONLY for production releases (v1.0.0+)
- See [PHASE_TRACKER.md](PHASE_TRACKER.md) for release criteria

## Phase-Based Development Workflow

O.A.S.I.S. uses a phase-driven approach with strict branch discipline.

### Visual Workflow

```
feature/phase1c ──┐
                  ├──> develop (accumulate all phases)
feature/phase1d ──┤            │
                  │            │
feature/phase2 ───┤            │
                  │            │
feature/phase3 ───┘            │
                               │
                        (all phases complete)
                               │
                               ├──> main (PR + gh pr merge --admin)
                               │            │
                               └──────> Tag v1.0.0
```

### Creating Phase Branches

```bash
# 1. Check current phase status
cat PHASE_TRACKER.md

# 2. Create phase branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/phase1c

# 3. Implement phase (see IMPROVEMENTS.md for requirements)
git add .
git commit -m "feat(monitoring): add dynamic service status endpoint"

# 4. Push to remote
git push -u origin feature/phase1c
```

### Merging Phase to Develop

**Option A: Direct Merge (Simple Phase)**
```bash
# When phase complete (all tasks in PHASE_TRACKER.md checked)
git checkout develop
git pull origin develop
git merge --no-ff feature/phase1c -m "feat: Complete Phase 1C - Service Monitoring & Account APIs"
git push origin develop

# Update PHASE_TRACKER.md to mark phase complete
```

**Option B: Pull Request (Complex Phase)**
```bash
# Create PR for review
gh pr create --base develop --head feature/phase1c \
  --title "feat: Phase 1C - Service Monitoring & Account APIs" \
  --body "Implements dynamic service status monitoring with Docker SDK. See IMPROVEMENTS.md lines 7-103."

# After approval, squash merge
gh pr merge --squash
```

### Important Phase Rules

1. **Branch Naming:** `feature/phase{number}` (e.g., `feature/phase1c`, `feature/phase2`)
2. **Merge Target:** Always merge to `develop` first (NEVER directly to `main`)
3. **Completion Check:** Update [PHASE_TRACKER.md](PHASE_TRACKER.md) before merging
4. **Commit Convention:** Use `feat:` prefix for phase completions
5. **Phase Dependencies:** Complete phases in order (1C before 1D)

### When to Use Hotfix Branches

**Hotfixes** are for production emergencies ONLY. Since `main` is currently documentation-only (no code until v1.0.0), hotfixes are NOT needed until post-v1.0.0 releases.

**Post-v1.0.0 Hotfix Process:**
See section "Handling Hotfixes" below (lines 172-200).

## Branch Protection Rules

### `main` branch (Production Only):
- ✅ **Protected** - Requires PR + `--admin` flag to merge
- ✅ Require 1 approval from @0xgruber
- ✅ Dismiss stale pull request approvals when new commits pushed
- ✅ Require status checks to pass:
  - CI/CD pipeline (linting, tests, security scans)
  - Security: No HIGH/CRITICAL vulnerabilities (Trivy)
  - Coverage: Minimum 80% code coverage
- ❌ Prevent force pushes (except emergency revert)
- ❌ Prevent branch deletion
- **Merge Strategy:** Squash merge ONLY (clean history)
- **Purpose:** Production releases ONLY (v1.0.0+)

### `develop` branch (Active Development):
- ❌ **Unprotected** - Direct push allowed for fast iteration
- ✅ Requires PR for major changes (recommended, not enforced)
- **Merge Strategy:** Squash merge from feature branches
- **Purpose:** All phase development (Phase 1C, 1D, 2, 3, etc.)
- **Testing:** CI runs on push (linting, tests, security scans)

## Merge Strategy

| Source → Target | Strategy | Reason | When |
|-----------------|----------|--------|------|
| Feature (Phase) → Develop | **Squash merge** or **Merge commit** | Clean history per phase | After phase complete |
| Develop → Main | **Squash merge** (via `gh pr merge --admin --squash`) | Production release only | v1.0.0+ (all phases done) |
| Hotfix → Main | **Merge commit**, then cherry-pick to develop | Emergency fixes | Post-v1.0.0 only |

**Current Strategy (Pre-v1.0.0):**
- Phase branches → `develop`: Merge frequently as phases complete
- `develop` → `main`: **DO NOT MERGE** until v1.0.0 ready (see [PHASE_TRACKER.md](PHASE_TRACKER.md))

## Handling Hotfixes

**For production emergencies:**

```bash
# Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/OASIS-789-security-patch

# Fix the issue
git add .
git commit -m "fix(auth): Patch authentication bypass vulnerability"

# Merge to main
git checkout main
git merge --no-ff hotfix/OASIS-789-security-patch
git tag v1.2.1
git push origin main --tags

# Merge to develop
git checkout develop
git merge hotfix/OASIS-789-security-patch
git push origin develop

# Delete hotfix branch
git branch -d hotfix/OASIS-789-security-patch
git push origin --delete hotfix/OASIS-789-security-patch
```

## Common Commands

### View commit history
```bash
git log --oneline --graph --all
```

### Undo last commit (keep changes)
```bash
git reset --soft HEAD~1
```

### Amend last commit message
```bash
git commit --amend -m "New commit message"
```

### Cherry-pick specific commit
```bash
git cherry-pick <commit-sha>
```

### Squash multiple commits interactively
```bash
git rebase -i HEAD~3  # Squash last 3 commits
```

## Pre-commit Hooks (Optional)

Install pre-commit hooks for automatic linting:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Troubleshooting

### Merge Conflict During Rebase
```bash
# View conflicted files
git status

# Edit files to resolve conflicts
# Then:
git add <resolved-files>
git rebase --continue

# Or abort rebase:
git rebase --abort
```

### Accidentally Committed to Wrong Branch
```bash
# Create new branch with current changes
git branch feature/correct-branch

# Reset current branch
git reset --hard HEAD~1

# Switch to correct branch
git checkout feature/correct-branch
```

### Push Rejected (Branch Diverged)
```bash
# Fetch latest
git fetch origin

# Rebase on top of remote
git rebase origin/develop

# Force push (only for feature branches, never main/develop)
git push --force-with-lease
```

## Best Practices

1. **Commit often**: Small, focused commits are easier to review and revert
2. **Write descriptive messages**: Explain *why* not *what* (code shows what)
3. **Keep branches short-lived**: Merge within 1-3 days to avoid merge conflicts
4. **Rebase before PR**: Clean up history before requesting review
5. **Test before push**: Run tests locally before pushing
6. **Review your own PR**: Check diff on GitHub before requesting review

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Branching Model](https://nvie.com/posts/a-successful-git-branching-model/)
- [Semantic Versioning](https://semver.org/)
