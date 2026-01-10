# OpenSpec Instructions

Instructions for AI coding assistants using OpenSpec for spec-driven development.

## ⚠️ CRITICAL: Git Workflow Checklist

**BEFORE creating branches or merging code, ALWAYS complete this checklist:**

1. **Recall Workflow from MCP Memory:**
   ```
   unified-mcp_recall_memory "oasis git workflow"
   ```
   - Review full workflow (branch structure, decision tree, validation checklist)

2. **Verify Current Phase:**
   - Read [../PHASE_TRACKER.md](../PHASE_TRACKER.md)
   - Check "Active Phase" and "Branch" fields
   - Confirm phase dependencies met (e.g., Phase 1C complete before 1D)

3. **Decision Tree: Where to Merge?**
   ```
   Is this production-ready? (All phases complete + tested)
     ├─ YES → PR to main (use gh pr merge --admin --squash)
     └─ NO  → Merge to develop (direct push or simple PR)
   ```
   - **Default:** Merge to `develop` (safer than `main`)
   - **Exception:** ONLY merge to `main` when v1.0.0 ready (see PHASE_TRACKER.md)

4. **Branch Protection Awareness:**
   - **`main`:** Protected (requires PR + `--admin` flag)
   - **`develop`:** Unprotected (direct push allowed)
   - **Purpose:** `main` = production-only, `develop` = active development

5. **Pre-Merge Validation:**
   - [ ] Conventional commit format (`feat:`, `fix:`, `chore:`, etc.)
   - [ ] PHASE_TRACKER.md updated if phase complete
   - [ ] OpenSpec validated if applicable (`openspec validate --strict`)
   - [ ] Tests passing (80% coverage minimum)
   - [ ] Security scans passing (Trivy, gitleaks)

6. **Phase-Based Branch Naming:**
   - Use `feature/phase{number}` (e.g., `feature/phase1c`)
   - NOT `feature/add-endpoint` or generic names
   - Ensures traceability to PHASE_TRACKER.md

7. **Emergency Override Procedure:**
   - If unsure about merge target: **default to `develop`**
   - Never force push to `main` (except authorized revert)
   - Consult [../GIT_WORKFLOW.md](../GIT_WORKFLOW.md) for edge cases

**CRITICAL REMINDER:** Do NOT merge to `main` until v1.0.0 (all phases complete). Check [../PHASE_TRACKER.md](../PHASE_TRACKER.md) production release criteria.

---

## 🔄 CRITICAL: Automatic Context Preservation

**AI Assistant MUST follow this protocol to prevent context loss during compaction:**

### When to Auto-Checkpoint

1. **Every 10 User Messages:**
   - Internally track message count
   - After 10th message, call `unified-mcp_should_compact(session_id, current_tokens, threshold=40000)`
   - If `recommended: true`, execute checkpoint immediately

2. **After Major Milestones:**
   - All TodoWrite tasks marked complete
   - Git commit/push successful
   - More than 500 lines of code changed
   - Phase completion (PHASE_TRACKER.md updated)

3. **Pre-Exit Triggers (IMMEDIATE checkpoint before responding):**
   - User says: "close", "done", "switching", "switch computer"
   - User says: "continue later", "have to go", "goodbye"
   - User says: "move to different computer", "pause here"

### How to Checkpoint

**Step 1: Create Session ID**
```
Format: "oasis-{YYYY-MM-DD}-{brief-topic}"
Example: "oasis-2026-01-10-phase1c-monitoring"
```

**Step 2: Execute Checkpoint (with redundant backup)**
```javascript
// Primary: Session compaction
unified-mcp_compact_session(
  session_id: "oasis-2026-01-10-phase1c-monitoring",
  summary: "Concise 2-3 sentence summary of work completed",
  files_modified: ["file1.md", "file2.py", "file3.tsx"],
  key_decisions: [
    "Decision 1: Why this approach was chosen",
    "Decision 2: Trade-off made"
  ],
  next_steps: [
    "Next task 1",
    "Next task 2",
    "Next task 3"
  ],
  fast: true  // Immediate save, background embedding
)

// Backup: Memory storage (redundant retrieval path)
unified-mcp_save_to_memory(
  content: "SESSION CHECKPOINT: oasis-2026-01-10-phase1c-monitoring

SUMMARY: {2-3 sentence summary}

FILES MODIFIED:
- file1.md
- file2.py
- file3.tsx

KEY DECISIONS:
- Decision 1
- Decision 2

NEXT STEPS:
- Task 1
- Task 2
- Task 3",
  metadata: {
    category: "session-checkpoint",
    project: "oasis",
    tags: ["auto-save", "checkpoint", "2026-01-10"]
  }
)
```

**Step 3: Notify User**
```
✅ Context auto-saved (Session: oasis-2026-01-10-phase1c-monitoring)
```

### Recovery Protocol

**When starting new session, AI MUST:**

1. **Check for recent sessions:**
   ```javascript
   unified-mcp_get_recent_context(hours=24, project="oasis")
   ```

2. **If found, retrieve latest:**
   ```javascript
   unified-mcp_get_session_summary(session_id="{most-recent-id}")
   ```

3. **Notify user:**
   ```
   📥 Restored context from {X} hours ago
   Last session: {summary}
   Files modified: {files}
   Next steps: {next_steps}
   ```

4. **If session_id unknown, use backup:**
   ```javascript
   unified-mcp_recall_memory("oasis session checkpoint recent")
   ```

### Token Monitoring Strategy

**Approximate token tracking:**
- Average user message: ~200 tokens
- Average AI response: ~500 tokens
- Total per exchange: ~700 tokens
- **10 messages ≈ 7,000 tokens**
- **Threshold: 40,000 tokens (before 50k limit)**

**Internal counter (AI maintains):**
```
message_count = 0

on_user_message:
  message_count += 1
  
  if message_count >= 10:
    result = should_compact(current_session_id, estimated_tokens=message_count * 700)
    if result.recommended:
      execute_checkpoint()
      message_count = 0  # Reset counter
```

### Example Auto-Checkpoint Flow

**Scenario: Long implementation session**

```
[Message 1-9: Normal conversation]

[Message 10]
User: "Can you also add error handling for the Docker daemon?"

AI: *Internal check*
  - message_count = 10
  - estimated_tokens = 10 * 700 = 7,000
  - Calls should_compact()
  - Result: recommended = true (cumulative context > 40k)

AI: *Executes checkpoint*
  unified-mcp_compact_session(
    session_id: "oasis-2026-01-10-phase1c-monitoring",
    summary: "Implemented dynamic service status monitoring using Docker SDK. Added GET /api/services/status endpoint with real-time container health checks. Frontend polls every 30 seconds with color-coded status badges.",
    files_modified: [
      "services/api-service/src/main.py",
      "services/api-service/src/docker_client.py", 
      "frontend/soc-portal/src/app/dashboard/page.tsx"
    ],
    key_decisions: [
      "Use Docker SDK (not docker-py) for better async support",
      "30-second polling (not WebSocket) for simplicity",
      "Read-only Docker socket mount for security"
    ],
    next_steps: [
      "Add error handling for Docker daemon down scenarios",
      "Write unit tests for Docker client",
      "Update PHASE_TRACKER.md when complete"
    ],
    fast: true
  )

AI: ✅ Context auto-saved (Session: oasis-2026-01-10-phase1c-monitoring)

AI: "Absolutely! Let me add comprehensive error handling for cases where the Docker daemon is unavailable..."
[Continues normally]
```

### Pre-Exit Checkpoint Example

```
User: "I have to switch computers, continue later"

AI: *Detects exit trigger - IMMEDIATE checkpoint*

unified-mcp_compact_session(
  session_id: "oasis-2026-01-10-phase1c-monitoring-final",
  summary: "Completed Docker SDK integration with error handling. All unit tests passing. Ready to update PHASE_TRACKER.md.",
  files_modified: [...],
  key_decisions: [...],
  next_steps: [
    "Update PHASE_TRACKER.md to mark Phase 1C complete",
    "Commit changes to develop branch",
    "Start Phase 1D (Testing & CI/CD)"
  ],
  fast: true
)

AI: ✅ Final checkpoint created
📥 To resume: `unified-mcp_get_session_summary("oasis-2026-01-10-phase1c-monitoring-final")`

Have a great session on your other computer! 👋
```

### Error Handling

**If checkpoint fails:**
1. Try memory backup only: `unified-mcp_save_to_memory()`
2. Notify user: "⚠️ Checkpoint partially saved (memory only)"
3. Continue session normally
4. Retry checkpoint after next milestone

**If retrieval fails:**
1. Try alternate method: `unified-mcp_recall_memory("oasis checkpoint")`
2. Check git log for recent work: `git log --oneline -10`
3. Read PHASE_TRACKER.md for phase status
4. Notify user: "⚠️ Could not fully restore context, using git history"

### Session ID Naming Convention

**Format:** `oasis-{date}-{topic}-{optional-suffix}`

**Examples:**
- `oasis-2026-01-10-phase1c-monitoring`
- `oasis-2026-01-10-docs-update`
- `oasis-2026-01-10-bugfix-auth`
- `oasis-2026-01-10-phase1c-monitoring-final` (pre-exit)

**Rules:**
- Always start with `oasis-`
- Use ISO date format (YYYY-MM-DD)
- Topic should match current work (phase, feature, bugfix)
- Keep under 50 characters
- Use hyphens, not underscores

---

## TL;DR Quick Checklist

- Search existing work: `openspec spec list --long`, `openspec list` (use `rg` only for full-text search)
- Decide scope: new capability vs modify existing capability
- Pick a unique `change-id`: kebab-case, verb-led (`add-`, `update-`, `remove-`, `refactor-`)
- Scaffold: `proposal.md`, `tasks.md`, `design.md` (only if needed), and delta specs per affected capability
- Write deltas: use `## ADDED|MODIFIED|REMOVED|RENAMED Requirements`; include at least one `#### Scenario:` per requirement
- Validate: `openspec validate [change-id] --strict` and fix issues
- Request approval: Do not start implementation until proposal is approved

## Three-Stage Workflow

### Stage 1: Creating Changes
Create proposal when you need to:
- Add features or functionality
- Make breaking changes (API, schema)
- Change architecture or patterns  
- Optimize performance (changes behavior)
- Update security patterns

Triggers (examples):
- "Help me create a change proposal"
- "Help me plan a change"
- "Help me create a proposal"
- "I want to create a spec proposal"
- "I want to create a spec"

Loose matching guidance:
- Contains one of: `proposal`, `change`, `spec`
- With one of: `create`, `plan`, `make`, `start`, `help`

Skip proposal for:
- Bug fixes (restore intended behavior)
- Typos, formatting, comments
- Dependency updates (non-breaking)
- Configuration changes
- Tests for existing behavior

**Workflow**
1. Review `openspec/project.md`, `openspec list`, and `openspec list --specs` to understand current context.
2. Choose a unique verb-led `change-id` and scaffold `proposal.md`, `tasks.md`, optional `design.md`, and spec deltas under `openspec/changes/<id>/`.
3. Draft spec deltas using `## ADDED|MODIFIED|REMOVED Requirements` with at least one `#### Scenario:` per requirement.
4. Run `openspec validate <id> --strict` and resolve any issues before sharing the proposal.

### Stage 2: Implementing Changes
Track these steps as TODOs and complete them one by one.
1. **Read proposal.md** - Understand what's being built
2. **Read design.md** (if exists) - Review technical decisions
3. **Read tasks.md** - Get implementation checklist
4. **Implement tasks sequentially** - Complete in order
5. **Confirm completion** - Ensure every item in `tasks.md` is finished before updating statuses
6. **Update checklist** - After all work is done, set every task to `- [x]` so the list reflects reality
7. **Approval gate** - Do not start implementation until the proposal is reviewed and approved

### Stage 3: Archiving Changes
After deployment, create separate PR to:
- Move `changes/[name]/` → `changes/archive/YYYY-MM-DD-[name]/`
- Update `specs/` if capabilities changed
- Use `openspec archive <change-id> --skip-specs --yes` for tooling-only changes (always pass the change ID explicitly)
- Run `openspec validate --strict` to confirm the archived change passes checks

## Before Any Task

**Context Checklist:**
- [ ] Read relevant specs in `specs/[capability]/spec.md`
- [ ] Check pending changes in `changes/` for conflicts
- [ ] Read `openspec/project.md` for conventions
- [ ] Run `openspec list` to see active changes
- [ ] Run `openspec list --specs` to see existing capabilities

**Before Creating Specs:**
- Always check if capability already exists
- Prefer modifying existing specs over creating duplicates
- Use `openspec show [spec]` to review current state
- If request is ambiguous, ask 1–2 clarifying questions before scaffolding

### Search Guidance
- Enumerate specs: `openspec spec list --long` (or `--json` for scripts)
- Enumerate changes: `openspec list` (or `openspec change list --json` - deprecated but available)
- Show details:
  - Spec: `openspec show <spec-id> --type spec` (use `--json` for filters)
  - Change: `openspec show <change-id> --json --deltas-only`
- Full-text search (use ripgrep): `rg -n "Requirement:|Scenario:" openspec/specs`

## Quick Start

### CLI Commands

```bash
# Essential commands
openspec list                  # List active changes
openspec list --specs          # List specifications
openspec show [item]           # Display change or spec
openspec validate [item]       # Validate changes or specs
openspec archive <change-id> [--yes|-y]   # Archive after deployment (add --yes for non-interactive runs)

# Project management
openspec init [path]           # Initialize OpenSpec
openspec update [path]         # Update instruction files

# Interactive mode
openspec show                  # Prompts for selection
openspec validate              # Bulk validation mode

# Debugging
openspec show [change] --json --deltas-only
openspec validate [change] --strict
```

### Command Flags

- `--json` - Machine-readable output
- `--type change|spec` - Disambiguate items
- `--strict` - Comprehensive validation
- `--no-interactive` - Disable prompts
- `--skip-specs` - Archive without spec updates
- `--yes`/`-y` - Skip confirmation prompts (non-interactive archive)

## Directory Structure

```
openspec/
├── project.md              # Project conventions
├── specs/                  # Current truth - what IS built
│   └── [capability]/       # Single focused capability
│       ├── spec.md         # Requirements and scenarios
│       └── design.md       # Technical patterns
├── changes/                # Proposals - what SHOULD change
│   ├── [change-name]/
│   │   ├── proposal.md     # Why, what, impact
│   │   ├── tasks.md        # Implementation checklist
│   │   ├── design.md       # Technical decisions (optional; see criteria)
│   │   └── specs/          # Delta changes
│   │       └── [capability]/
│   │           └── spec.md # ADDED/MODIFIED/REMOVED
│   └── archive/            # Completed changes
```

## Creating Change Proposals

### Decision Tree

```
New request?
├─ Bug fix restoring spec behavior? → Fix directly
├─ Typo/format/comment? → Fix directly  
├─ New feature/capability? → Create proposal
├─ Breaking change? → Create proposal
├─ Architecture change? → Create proposal
└─ Unclear? → Create proposal (safer)
```

### Proposal Structure

1. **Create directory:** `changes/[change-id]/` (kebab-case, verb-led, unique)

2. **Write proposal.md:**
```markdown
# Change: [Brief description of change]

## Why
[1-2 sentences on problem/opportunity]

## What Changes
- [Bullet list of changes]
- [Mark breaking changes with **BREAKING**]

## Impact
- Affected specs: [list capabilities]
- Affected code: [key files/systems]
```

3. **Create spec deltas:** `specs/[capability]/spec.md`
```markdown
## ADDED Requirements
### Requirement: New Feature
The system SHALL provide...

#### Scenario: Success case
- **WHEN** user performs action
- **THEN** expected result

## MODIFIED Requirements
### Requirement: Existing Feature
[Complete modified requirement]

## REMOVED Requirements
### Requirement: Old Feature
**Reason**: [Why removing]
**Migration**: [How to handle]
```
If multiple capabilities are affected, create multiple delta files under `changes/[change-id]/specs/<capability>/spec.md`—one per capability.

4. **Create tasks.md:**
```markdown
## 1. Implementation
- [ ] 1.1 Create database schema
- [ ] 1.2 Implement API endpoint
- [ ] 1.3 Add frontend component
- [ ] 1.4 Write tests
```

5. **Create design.md when needed:**
Create `design.md` if any of the following apply; otherwise omit it:
- Cross-cutting change (multiple services/modules) or a new architectural pattern
- New external dependency or significant data model changes
- Security, performance, or migration complexity
- Ambiguity that benefits from technical decisions before coding

Minimal `design.md` skeleton:
```markdown
## Context
[Background, constraints, stakeholders]

## Goals / Non-Goals
- Goals: [...]
- Non-Goals: [...]

## Decisions
- Decision: [What and why]
- Alternatives considered: [Options + rationale]

## Risks / Trade-offs
- [Risk] → Mitigation

## Migration Plan
[Steps, rollback]

## Open Questions
- [...]
```

## Spec File Format

### Critical: Scenario Formatting

**CORRECT** (use #### headers):
```markdown
#### Scenario: User login success
- **WHEN** valid credentials provided
- **THEN** return JWT token
```

**WRONG** (don't use bullets or bold):
```markdown
- **Scenario: User login**  ❌
**Scenario**: User login     ❌
### Scenario: User login      ❌
```

Every requirement MUST have at least one scenario.

### Requirement Wording
- Use SHALL/MUST for normative requirements (avoid should/may unless intentionally non-normative)

### Delta Operations

- `## ADDED Requirements` - New capabilities
- `## MODIFIED Requirements` - Changed behavior
- `## REMOVED Requirements` - Deprecated features
- `## RENAMED Requirements` - Name changes

Headers matched with `trim(header)` - whitespace ignored.

#### When to use ADDED vs MODIFIED
- ADDED: Introduces a new capability or sub-capability that can stand alone as a requirement. Prefer ADDED when the change is orthogonal (e.g., adding "Slash Command Configuration") rather than altering the semantics of an existing requirement.
- MODIFIED: Changes the behavior, scope, or acceptance criteria of an existing requirement. Always paste the full, updated requirement content (header + all scenarios). The archiver will replace the entire requirement with what you provide here; partial deltas will drop previous details.
- RENAMED: Use when only the name changes. If you also change behavior, use RENAMED (name) plus MODIFIED (content) referencing the new name.

Common pitfall: Using MODIFIED to add a new concern without including the previous text. This causes loss of detail at archive time. If you aren’t explicitly changing the existing requirement, add a new requirement under ADDED instead.

Authoring a MODIFIED requirement correctly:
1) Locate the existing requirement in `openspec/specs/<capability>/spec.md`.
2) Copy the entire requirement block (from `### Requirement: ...` through its scenarios).
3) Paste it under `## MODIFIED Requirements` and edit to reflect the new behavior.
4) Ensure the header text matches exactly (whitespace-insensitive) and keep at least one `#### Scenario:`.

Example for RENAMED:
```markdown
## RENAMED Requirements
- FROM: `### Requirement: Login`
- TO: `### Requirement: User Authentication`
```

## Troubleshooting

### Common Errors

**"Change must have at least one delta"**
- Check `changes/[name]/specs/` exists with .md files
- Verify files have operation prefixes (## ADDED Requirements)

**"Requirement must have at least one scenario"**
- Check scenarios use `#### Scenario:` format (4 hashtags)
- Don't use bullet points or bold for scenario headers

**Silent scenario parsing failures**
- Exact format required: `#### Scenario: Name`
- Debug with: `openspec show [change] --json --deltas-only`

### Validation Tips

```bash
# Always use strict mode for comprehensive checks
openspec validate [change] --strict

# Debug delta parsing
openspec show [change] --json | jq '.deltas'

# Check specific requirement
openspec show [spec] --json -r 1
```

## Happy Path Script

```bash
# 1) Explore current state
openspec spec list --long
openspec list
# Optional full-text search:
# rg -n "Requirement:|Scenario:" openspec/specs
# rg -n "^#|Requirement:" openspec/changes

# 2) Choose change id and scaffold
CHANGE=add-two-factor-auth
mkdir -p openspec/changes/$CHANGE/{specs/auth}
printf "## Why\n...\n\n## What Changes\n- ...\n\n## Impact\n- ...\n" > openspec/changes/$CHANGE/proposal.md
printf "## 1. Implementation\n- [ ] 1.1 ...\n" > openspec/changes/$CHANGE/tasks.md

# 3) Add deltas (example)
cat > openspec/changes/$CHANGE/specs/auth/spec.md << 'EOF'
## ADDED Requirements
### Requirement: Two-Factor Authentication
Users MUST provide a second factor during login.

#### Scenario: OTP required
- **WHEN** valid credentials are provided
- **THEN** an OTP challenge is required
EOF

# 4) Validate
openspec validate $CHANGE --strict
```

## Multi-Capability Example

```
openspec/changes/add-2fa-notify/
├── proposal.md
├── tasks.md
└── specs/
    ├── auth/
    │   └── spec.md   # ADDED: Two-Factor Authentication
    └── notifications/
        └── spec.md   # ADDED: OTP email notification
```

auth/spec.md
```markdown
## ADDED Requirements
### Requirement: Two-Factor Authentication
...
```

notifications/spec.md
```markdown
## ADDED Requirements
### Requirement: OTP Email Notification
...
```

## Best Practices

### Simplicity First
- Default to <100 lines of new code
- Single-file implementations until proven insufficient
- Avoid frameworks without clear justification
- Choose boring, proven patterns

### Complexity Triggers
Only add complexity with:
- Performance data showing current solution too slow
- Concrete scale requirements (>1000 users, >100MB data)
- Multiple proven use cases requiring abstraction

### Clear References
- Use `file.ts:42` format for code locations
- Reference specs as `specs/auth/spec.md`
- Link related changes and PRs

### Capability Naming
- Use verb-noun: `user-auth`, `payment-capture`
- Single purpose per capability
- 10-minute understandability rule
- Split if description needs "AND"

### Change ID Naming
- Use kebab-case, short and descriptive: `add-two-factor-auth`
- Prefer verb-led prefixes: `add-`, `update-`, `remove-`, `refactor-`
- Ensure uniqueness; if taken, append `-2`, `-3`, etc.

## Tool Selection Guide

| Task | Tool | Why |
|------|------|-----|
| Find files by pattern | Glob | Fast pattern matching |
| Search code content | Grep | Optimized regex search |
| Read specific files | Read | Direct file access |
| Explore unknown scope | Task | Multi-step investigation |

## Error Recovery

### Change Conflicts
1. Run `openspec list` to see active changes
2. Check for overlapping specs
3. Coordinate with change owners
4. Consider combining proposals

### Validation Failures
1. Run with `--strict` flag
2. Check JSON output for details
3. Verify spec file format
4. Ensure scenarios properly formatted

### Missing Context
1. Read project.md first
2. Check related specs
3. Review recent archives
4. Ask for clarification

## Quick Reference

### Stage Indicators
- `changes/` - Proposed, not yet built
- `specs/` - Built and deployed
- `archive/` - Completed changes

### File Purposes
- `proposal.md` - Why and what
- `tasks.md` - Implementation steps
- `design.md` - Technical decisions
- `spec.md` - Requirements and behavior

### CLI Essentials
```bash
openspec list              # What's in progress?
openspec show [item]       # View details
openspec validate --strict # Is it correct?
openspec archive <change-id> [--yes|-y]  # Mark complete (add --yes for automation)
```

Remember: Specs are truth. Changes are proposals. Keep them in sync.
