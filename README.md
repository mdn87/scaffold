# scaffold

A private scaffolding system for bootstrapping and standardizing AI-assisted development projects. Generates agent rules, Claude Code config, Codex CLI config, and injects a self-updating runtime layer that provides planning orchestration, cross-agent review, and session continuity across every project it touches.

---

## What it does

When you run `apply-scaffold` against a project directory it:

1. **Generates agent rules** — detects your stack, reads existing docs and entry points, and writes `CLAUDE.md`, `.agents/rules.md`, `.claude/settings.json`, and `.codex/config.toml` tailored to that project
2. **Injects the runtime layer** — copies `.scaffold/` into the project with orchestration templates, skill definitions, tool scripts, rules, and doc templates
3. **Stamps documentation structure** — creates `docs/project-brief.md`, `docs/architecture.md`, `docs/INDEX.md`, and `docs/decisions/` if they don't exist
4. **Keeps itself current** — the injected `sync.sh` checks this repo for updates on every agent session start and applies changes without touching your project-owned files

---

## Two-layer architecture

| Layer | Location | Purpose |
|-------|----------|---------|
| **Bootstrap** | `scripts/` in this repo | One-time or occasional — scaffolds a target project |
| **Runtime** | `.scaffold/` inside each project | Lives in the project — syncs from upstream, runs every session |

The bootstrap layer runs from this repo. The runtime layer travels with the project and self-updates.

---

## Quick start

### New project

```powershell
# Initialize the target project
mkdir C:/projects/my-app
cd C:/projects/my-app
git init

# Apply scaffold (add a README first for better signal quality)
pwsh -File C:/path/to/scaffold/scripts/apply-scaffold.ps1 -TargetPath . -ProjectName my-app
```

Then open the project in your agent and say **"init plan"** — the agent will follow `.scaffold/orchestration/plan-init.md` to build a structured plan.

### Existing project

```powershell
# Full adoption workflow — analyzes the project first, applies only if safe
pwsh -File C:/path/to/scaffold/scripts/invoke-scaffold.ps1 -TargetPath C:/projects/existing-app
```

### Sync a project's runtime layer

```bash
# Run from inside any scaffolded project
bash .scaffold/sync.sh
```

---

## Runtime layer overview

Once `.scaffold/` is in a project, agents use it throughout every session:

| Directory | Contents |
|-----------|---------|
| `.scaffold/orchestration/` | Plan and milestone templates, step-by-step agent orchestration |
| `.scaffold/skills/` | Self-update, session handoff, compute budget guard |
| `.scaffold/tools/` | Tool manifest, codex-review.sh, plan-overview-gen.sh |
| `.scaffold/references/` | MCP reference registry with auto-suggest triggers |
| `.scaffold/rules/` | Universal rules, stack-specific rules, per-platform rendering |
| `.scaffold/docs-templates/` | Source templates for project-brief, architecture, INDEX, ADR |
| `.scaffold/project/` | **Project-owned** — rules.md, tool-config.json, usage-log.json, handoff |
| `.scaffold/upstream.json` | Repo URL, branch, and last-synced commit (read by sync.sh) |
| `.scaffold/sync.sh` | Self-update script |

`.scaffold/project/` is never touched by `sync.sh` — it's yours.

---

## Planning workflow

Once a project is scaffolded, the agent follows a four-phase orchestration cycle:

```
plan-init        →  Creates PLAN.md + PLAN-M*.md + PLAN-OVERVIEW.md
milestone-run    →  Implements one milestone (12-step process)
milestone-review →  Cross-agent review across four dimensions (KISS / Style / Correctness / Goals)
better-engineering → Optional quality review after each milestone
```

All orchestration files live in `.scaffold/orchestration/` and are written for AI consumption.

---

## Directory structure

```
scaffold/
├── scripts/                  # Bootstrap scripts (run from this repo)
│   ├── apply-scaffold.ps1    # Core bootstrap — generates rules + injects runtime
│   ├── invoke-scaffold.ps1   # Full adoption workflow for existing projects
│   ├── inventory-project.ps1
│   ├── generate-architecture-context.ps1
│   ├── generate-migration-map.ps1
│   └── generate-risk-ledger.ps1
├── runtime/                  # Source for the .scaffold/ runtime layer
│   ├── orchestration/
│   ├── skills/
│   ├── tools/
│   ├── references/
│   ├── rules/
│   ├── docs-templates/
│   └── sync.sh
├── scaffold/templates/common/ # Baseline file templates applied during bootstrap
├── reports/                  # Generated analysis reports (gitignored in target projects)
└── docs/                     # This repo's own documentation
    ├── cli-reference.md      # All CLI commands and flags
    └── ...
```

---

## CLI reference

All commands, flags, and examples: **[docs/cli-reference.md](docs/cli-reference.md)**

---

## Requirements

| Tool | Used by |
|------|---------|
| PowerShell (`pwsh`) | All bootstrap scripts |
| `git` | `sync.sh`, upstream commit detection |
| `python3` or `node` | `sync.sh` JSON parsing |
| Codex CLI (optional) | `codex-review.sh` cross-agent review |
| `gh` CLI (optional) | `invoke-scaffold.ps1` GitHub repo creation |
