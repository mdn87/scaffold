# CLI Reference

All commands available in the scaffold system, grouped by layer.

---

## Bootstrap Scripts

Run from the scaffold repo against a target project. Require PowerShell (`pwsh`).

---

### `apply-scaffold.ps1`

The core bootstrap command. Injects agent rules, CLAUDE.md, Codex config, `.claude/settings.json`, and the full runtime layer (`.scaffold/`) into a target project. Also stamps doc templates into `docs/` if they don't exist.

```powershell
pwsh -File scripts/apply-scaffold.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the target project directory |
| `-ProjectName` | string | directory name | Override the detected project name |
| `-Force` | switch | off | Overwrite existing scaffold-generated files |
| `-UseRemoteGitHubContext` | switch | off | Enrich agent rules with GitHub repo description and README |

**Examples**

```powershell
# Minimal — new project
pwsh -File scripts/apply-scaffold.ps1 -TargetPath C:/projects/my-app

# Named project with GitHub enrichment
pwsh -File scripts/apply-scaffold.ps1 -TargetPath C:/projects/my-app -ProjectName my-app -UseRemoteGitHubContext

# Force overwrite existing scaffold files (re-scaffold)
pwsh -File scripts/apply-scaffold.ps1 -TargetPath C:/projects/my-app -Force
```

**What it produces**

| Path | Description |
|------|-------------|
| `CLAUDE.md` | Claude Code project rules, inferred from stack and docs |
| `.claude/settings.json` | Auto-approved command list for Claude Code |
| `.agents/rules.md` | Agent rules (Codex / AGENTS.md compatible) |
| `.agents/always-approve-whitelisted-commands.md` | Codex safe-run whitelist |
| `.agents/quota-drain-prevention.md` | Compute budget rules |
| `.agents/restart-api-host-as-needed.md` | API surface rule (if detected) |
| `.codex/config.toml` | Codex CLI config |
| `.scaffold/` | Full runtime layer (orchestration, skills, tools, rules, sync) |
| `docs/` | Doc templates (project-brief, architecture, INDEX, ADR) |
| `scaffold.config.json` | Scaffold metadata record |

---

### `invoke-scaffold.ps1`

Orchestrates the full adoption workflow for existing projects. Runs inventory → migration map → architecture context → risk ledger, then conditionally applies the scaffold baseline if the recommendation is `adopt`.

```powershell
pwsh -File scripts/invoke-scaffold.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the target project directory |
| `-Action` | string | `activate` | One of `inventory`, `apply`, `activate` |
| `-ProjectName` | string | directory name | Override the detected project name |
| `-Force` | switch | off | Pass `-Force` through to `apply-scaffold.ps1` |

**Actions**

| Action | What it does |
|--------|-------------|
| `inventory` | Scan target project and write `reports/<name>.inventory.json` only |
| `apply` | Run `apply-scaffold.ps1` directly (skips analysis reports) |
| `activate` | Full workflow: inventory → migration map → architecture context → risk ledger → apply if `adopt` recommended |

**Examples**

```powershell
# Full adoption workflow (recommended for existing projects)
pwsh -File scripts/invoke-scaffold.ps1 -TargetPath C:/projects/existing-app

# Inventory scan only — no changes made
pwsh -File scripts/invoke-scaffold.ps1 -TargetPath C:/projects/existing-app -Action inventory

# Force-apply without analysis
pwsh -File scripts/invoke-scaffold.ps1 -TargetPath C:/projects/existing-app -Action apply -Force
```

---

### `inventory-project.ps1`

Scans a target project and produces a structured inventory report (`reports/<name>.inventory.json` and `.md`). Used by `invoke-scaffold.ps1` but can be run standalone.

```powershell
pwsh -File scripts/inventory-project.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the project to inventory |
| `-OutputDirectory` | string | `.\reports` | Where to write the output files |

---

### `generate-architecture-context.ps1`

Reads an existing inventory report and generates an architecture context document (`reports/<name>.architecture-context.json` and `.md`) for use in AI-assisted migration planning.

```powershell
pwsh -File scripts/generate-architecture-context.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the target project |
| `-OutputDirectory` | string | `.\reports` | Where to write the output files |

---

### `generate-migration-map.ps1`

Produces a migration map (`reports/<name>.migration-map.json` and `.md`) that maps current project structure to scaffold conventions. Identifies what to adopt, adapt, or leave alone.

```powershell
pwsh -File scripts/generate-migration-map.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the target project |
| `-OutputDirectory` | string | `.\reports` | Where to write the output files |

---

### `generate-risk-ledger.ps1`

Generates a risk assessment (`reports/<name>.risk-ledger.json` and `.md`) covering structural, dependency, and adoption risks for a given project.

```powershell
pwsh -File scripts/generate-risk-ledger.ps1 -TargetPath <path> [options]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `-TargetPath` | string | *(required)* | Path to the target project |
| `-OutputDirectory` | string | `.\reports` | Where to write the output files |

---

## Runtime Tools

Run from inside a scaffolded project (a project that has `.scaffold/`). These are bash scripts.

---

### `sync.sh`

Checks the upstream scaffold repo for updates and applies any changes to `.scaffold/`. Never touches `.scaffold/project/` (your project-owned config and rules).

Reads connection info from `.scaffold/upstream.json`. Requires `git`, and either `python3` or `node` for JSON parsing.

```bash
bash .scaffold/sync.sh
```

No arguments. Intended to run automatically on every agent session start via the self-update skill.

**What it updates**

Overwrites these upstream-owned directories if the remote has a newer commit:
`orchestration/`, `skills/`, `tools/`, `references/`, `rules/`, `docs-templates/`, `sync.sh`

**What it never touches**

`.scaffold/project/` — your `rules.md`, `tool-config.json`, `usage-log.json`, and handoff files.

---

### `codex-review.sh`

Invokes Codex CLI to perform a cross-agent review of a completed milestone across one of four dimensions. Falls back to a structured paste prompt if Codex CLI is unavailable.

```bash
bash .scaffold/tools/codex-review.sh \
  --dimension <KISS|style|correctness|goals> \
  --milestone <path-to-milestone-file> \
  [--files "<space-separated file paths>"]
```

| Flag | Required | Description |
|------|----------|-------------|
| `--dimension` | yes | Review focus: `KISS`, `style`, `correctness`, or `goals` |
| `--milestone` | yes | Path to the milestone file (e.g. `docs/plans/PLAN-M1.md`) |
| `--files` | no | Space-separated list of changed files to include in review context |

**Examples**

```bash
# KISS review for M2
bash .scaffold/tools/codex-review.sh \
  --dimension KISS \
  --milestone docs/plans/PLAN-M2.md \
  --files "src/auth.py src/models.py"

# Goal fulfillment review, no file context
bash .scaffold/tools/codex-review.sh \
  --dimension goals \
  --milestone docs/plans/PLAN-M1.md
```

Run once per dimension (four total) per milestone. See `.scaffold/orchestration/milestone-review.md` for the full review workflow.

---

### `plan-overview-gen.sh`

Regenerates `PLAN-OVERVIEW.md` by scanning all `PLAN-M*.md` files in the plans directory. Run after completing a milestone to keep the overview current.

```bash
bash .scaffold/tools/plan-overview-gen.sh [plans-directory]
```

| Argument | Default | Description |
|----------|---------|-------------|
| `plans-directory` | `docs/plans` | Path to the directory containing `PLAN.md` and `PLAN-M*.md` files |

**Examples**

```bash
# Default location
bash .scaffold/tools/plan-overview-gen.sh

# Custom plans directory
bash .scaffold/tools/plan-overview-gen.sh docs/sprint-1
```

---

## Recommended Workflows

### New project

```powershell
# 1. Create project dir and initialize git
mkdir C:/projects/my-app && cd C:/projects/my-app && git init

# 2. Add a README or project-brief.md (improves signal quality)
# (optional but recommended before scaffolding)

# 3. Apply scaffold
pwsh -File C:/path/to/scaffold/scripts/apply-scaffold.ps1 -TargetPath . -ProjectName my-app

# 4. Start planning (in your agent session)
# Say: "init plan" — follow .scaffold/orchestration/plan-init.md
```

### Existing project

```powershell
# Full adoption workflow — analyzes first, applies only if safe
pwsh -File C:/path/to/scaffold/scripts/invoke-scaffold.ps1 -TargetPath C:/projects/existing-app
```

### Re-scaffold after upstream updates

```powershell
# Force re-apply to refresh CLAUDE.md and agent rules from current signals
pwsh -File C:/path/to/scaffold/scripts/apply-scaffold.ps1 -TargetPath . -Force
```

### Sync runtime layer mid-project

```bash
# Run from inside any scaffolded project
bash .scaffold/sync.sh
```
