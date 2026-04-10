# Scaffold Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the scaffold project from a one-shot bootstrapper into a living, self-updating orchestration framework with milestone planning, cross-agent review, and a shared skill/tool library.

**Architecture:** Two-layer model — bootstrap (existing `scaffold/` + `scripts/`) handles one-shot project setup, runtime (new `runtime/`) gets injected into projects as `.scaffold/` and runs every session. The runtime layer syncs from a private GitHub repo. Projects own `.scaffold/project/`, everything else is upstream-controlled.

**Tech Stack:** Bash (sync scripts, tool wrappers), PowerShell (apply-scaffold.ps1 modifications), Markdown (orchestration docs, skills, rules, templates), JSON (manifests, configs)

**Spec:** `docs/superpowers/specs/2026-03-22-scaffold-runtime-design.md`

---

## File Structure

### New files to create in `runtime/`

```
runtime/
├── sync.sh                            # self-update script
├── orchestration/
│   ├── PLAN-TEMPLATE.md               # structured plan template for projects
│   ├── MILESTONE-TEMPLATE.md          # per-milestone file template
│   ├── plan-init.md                   # orchestration: how to build a plan
│   ├── milestone-run.md               # orchestration: how to implement
│   ├── milestone-review.md            # orchestration: cross-agent review
│   └── better-engineering.md          # orchestration: post-milestone review
├── skills/
│   ├── handoff.md                     # session continuity skill
│   ├── self-update.md                 # check upstream on session start
│   └── quota-guard.md                 # compute budget tiers
├── tools/
│   ├── manifest.json                  # tool registry with conflict declarations
│   ├── codex-review.sh               # invoke Codex CLI for review
│   └── plan-overview-gen.sh           # regenerate PLAN-OVERVIEW.md
├── references/
│   └── registry.json                  # external tool/MCP pointers
├── rules/
│   ├── always.md                      # universal rules
│   ├── catalog.md                     # cross-project rule index
│   ├── stacks/
│   │   ├── dotnet.md
│   │   ├── python.md
│   │   └── node.md
│   └── per-platform/
│       ├── claude.md
│       ├── codex.md
│       └── agents.md
└── docs-templates/
    ├── project-brief-template.md      # doc template for project init
    ├── architecture-template.md       # doc template for project init
    ├── index-template.md              # INDEX.md template
    └── adr-template.md                # ADR template
```

### Files to modify

```
scripts/apply-scaffold.ps1             # add runtime injection, upstream.json generation, tool discovery
```

---

## Milestone Overview

| Milestone | Scope | Dependencies |
|-----------|-------|-------------|
| M1 | Runtime directory structure + JSON manifests | None |
| M2 | Rule system (universal, stack, catalog, platform rendering) | M1 |
| M3 | Documentation templates and lifecycle | M1 |
| M4 | Self-update mechanism (sync.sh + self-update skill) | M1 |
| M5 | Skills library (handoff, quota-guard) | M1 |
| M6 | Planning orchestration (templates, plan-init, milestone-run) | M3, M5 |
| M7 | Cross-agent review + better engineering | M6 |
| M8 | Tool auditing and smart prompting | M1, M6 |
| M9 | apply-scaffold.ps1 integration | M1–M8 |

---

## Task 1: Runtime Directory Structure + JSON Manifests (M1)

**Files:**
- Create: `runtime/tools/manifest.json`
- Create: `runtime/references/registry.json`

This task creates the runtime directory tree and the two JSON manifests that all other milestones depend on.

- [ ] **Step 1: Create the runtime directory tree**

```bash
mkdir -p runtime/{orchestration,skills,tools,references,rules/stacks,rules/per-platform,docs-templates}
```

- [ ] **Step 2: Create tools/manifest.json**

```json
{
  "version": "1.0.0",
  "description": "Available tools for scaffold-managed projects",
  "tools": [
    {
      "name": "sync",
      "file": "sync.sh",
      "description": "Self-update script for fetching upstream scaffold changes",
      "platform": "all",
      "auto_activate": true,
      "conflicts": {}
    },
    {
      "name": "codex-review",
      "file": "codex-review.sh",
      "description": "Invoke Codex CLI with structured review prompt for cross-agent review",
      "platform": "all",
      "auto_activate": false,
      "conflicts": {},
      "requires": "codex"
    },
    {
      "name": "plan-overview-gen",
      "file": "plan-overview-gen.sh",
      "description": "Regenerate PLAN-OVERVIEW.md from milestone files",
      "platform": "all",
      "auto_activate": true,
      "conflicts": {}
    }
  ]
}
```

- [ ] **Step 3: Create references/registry.json**

```json
{
  "version": "1.0.0",
  "description": "Optional external tool and MCP references for scaffold-managed projects",
  "references": [
    {
      "name": "context7",
      "description": "Library documentation lookup via MCP",
      "type": "mcp",
      "url": "https://github.com/upstash/context7",
      "platform": "claude",
      "auto_suggest_when": ["any"],
      "conflicts": {}
    },
    {
      "name": "claude-preview",
      "description": "Browser preview for visual development",
      "type": "mcp",
      "url": "https://github.com/anthropics/claude-code-preview",
      "platform": "claude",
      "auto_suggest_when": ["frontend", "web"],
      "conflicts": {}
    }
  ]
}
```

Semantic code-intelligence references are intentionally omitted from the default registry. For
Lugos-family repos, if a future project needs one, add it as an explicit project-level opt-in that
defers to the Lugos umbrella code-intelligence docs rather than making it part of the starter
baseline.

- [ ] **Step 4: Validate JSON files parse correctly**

Run: `python -c "import json; json.load(open('runtime/tools/manifest.json')); json.load(open('runtime/references/registry.json')); print('OK')"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add runtime/
git commit -m "feat(runtime): create directory structure and JSON manifests"
```

---

## Task 2: Rule System (M2)

**Files:**
- Create: `runtime/rules/always.md`
- Create: `runtime/rules/catalog.md`
- Create: `runtime/rules/stacks/dotnet.md`
- Create: `runtime/rules/stacks/python.md`
- Create: `runtime/rules/stacks/node.md`
- Create: `runtime/rules/per-platform/claude.md`
- Create: `runtime/rules/per-platform/codex.md`
- Create: `runtime/rules/per-platform/agents.md`

- [ ] **Step 1: Create runtime/rules/always.md**

Universal rules that apply to every scaffold-managed project. Written in platform-neutral format.

```markdown
# Universal Rules

These rules apply to every scaffold-managed project regardless of stack or platform.

## Operating Principles

- Read and understand existing code before suggesting modifications
- Prefer small, reviewable changes over large rewrites
- Match existing path, naming, and runtime conventions
- Do not add features, comments, or error handling beyond what was asked
- Documentation updates are a completion requirement for every milestone

## Scaffold Awareness

- `.scaffold/` contains upstream-managed orchestration, skills, tools, references, and rules
- `.scaffold/project/` contains project-specific overrides — never modify upstream-owned paths for local customizations
- Check `.scaffold/upstream.json` for sync status on session start
- Read `.scaffold/tools/manifest.json` before each milestone to review available tools

## Session Lifecycle

- On session start: run self-update check, read handoff state
- On session end: write handoff state
- Before implementation: review tool manifest, confirm milestone scope
- After implementation: update documentation, run tool audit

## Compute Budget

- **LOW (default):** Read only files necessary for the task. Reuse loaded context.
- **HIGH:** Confirm before reading many files or running broad searches. Say: "Estimated quota impact: HIGH. Proceed?"
- **ULTRA:** Confirm before full codebase analysis or large refactors. Say: "Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed?"
```

- [ ] **Step 2: Create runtime/rules/catalog.md**

```markdown
# Cross-Project Rule Catalog

Index of project-specific rules that are interesting for reference but not generalizable enough for universal or stack rules.

| Rule | Project | Stack | Description |
|------|---------|-------|-------------|
| api-restart | SpecRebuilder | dotnet | Restart dev server after API endpoint changes |

## How to Use This Catalog

- Agents can reference this catalog to see patterns from other projects
- To promote a rule: move it to `rules/stacks/{stack}.md` or `rules/always.md` in the scaffold repo
- To add a reference: add a row to the table above with the rule name, source project, and description
```

- [ ] **Step 3: Create runtime/rules/stacks/dotnet.md**

```markdown
# .NET Stack Rules

## Build & Test

- Primary commands: `dotnet build`, `dotnet test`, `dotnet run`
- Always run `dotnet build` before `dotnet test` to catch compilation errors early
- Use `dotnet test --verbosity normal` for meaningful output

## Conventions

- Follow existing namespace and project structure
- Prefer `async/await` patterns for I/O operations
- Use dependency injection as established in the project

## Safe Commands

dotnet build, dotnet test, dotnet run, dotnet restore, dotnet clean, dotnet format
```

- [ ] **Step 4: Create runtime/rules/stacks/python.md**

```markdown
# Python Stack Rules

## Build & Test

- Check for `pyproject.toml`, `setup.py`, or `requirements.txt` to determine package manager
- Prefer `pytest` for testing. Run with `pytest -v` for verbose output
- Use virtual environments — never install to system Python

## Conventions

- Follow PEP 8 style as established in the project
- Prefer type hints where the project uses them
- Use `pathlib.Path` over `os.path` in new code

## Safe Commands

pytest, python -m pytest, pip install, pip install -e ., python -m, ruff check, ruff format, mypy
```

- [ ] **Step 5: Create runtime/rules/stacks/node.md**

```markdown
# Node.js Stack Rules

## Build & Test

- Check `package.json` for scripts: `npm test`, `npm run build`, `npm run lint`
- Detect package manager from lock files: `package-lock.json` (npm), `yarn.lock` (yarn), `pnpm-lock.yaml` (pnpm)
- Use the detected package manager consistently

## Conventions

- Follow existing module format (ESM vs CJS) as established
- Match existing code style (semicolons, quotes, etc.)
- Prefer `const` over `let`, never use `var`

## Safe Commands

npm test, npm run build, npm run lint, npm install, npx, node, yarn test, yarn build, pnpm test, pnpm build
```

- [ ] **Step 6: Create platform rendering rules**

Create `runtime/rules/per-platform/claude.md`:

```markdown
# Claude Code Platform Rules

## File Targets

- Agent rules → `CLAUDE.md` (project root)
- Command permissions → `.claude/settings.json`

## CLAUDE.md Structure

```
# {project-name}

## Project
- **Type**: {type}
- **Stack**: {stack}
- **Root**: {path}

## Purpose
{from project-brief.md}

## Key Commands
{from stack rules safe commands}

## Workflow Notes
{from scaffold orchestration}

## Operating Rules
{from rules/always.md, filtered for Claude Code}

## Compute Budget
{from rules/always.md compute budget section}
```

## settings.json Structure

```json
{
  "permissions": {
    "allow": ["Bash({command}:*)"],
    "deny": []
  }
}
```

## Rendering Notes

- Exclude PowerShell cmdlets — Claude Code uses bash
- Use `Bash(prefix:*)` wildcard format for command permissions
- Include scaffold-specific workflow notes referencing `.scaffold/` paths
```

Create `runtime/rules/per-platform/codex.md`:

```markdown
# Codex Platform Rules

## File Targets

- Agent rules → `AGENTS.md` (project root)

## AGENTS.md Structure

```
# {project-name}

## Project
{same content as CLAUDE.md Project section}

## Instructions
{from rules/always.md}

## Safe Commands
{from stack rules, as a flat list}
```

## Rendering Notes

- Codex reads AGENTS.md for project context
- Include milestone orchestration references
- Keep format flat and scannable
```

Create `runtime/rules/per-platform/agents.md`:

```markdown
# Generic AGENTS.md Platform Rules (Cursor, Windsurf)

## File Targets

- Agent rules → `.agents/rules.md`
- Command whitelist → `.agents/always-approve-whitelisted-commands.md`

## rules.md Structure

Uses frontmatter format:

```yaml
---
trigger: always_on
---
```

Followed by project context, workflow notes, and operating rules.

## Rendering Notes

- Include both PowerShell and bash commands in whitelist
- Support broader command formats than Claude Code
- Reference `.scaffold/` paths for orchestration
```

- [ ] **Step 7: Commit**

```bash
git add runtime/rules/
git commit -m "feat(runtime): add universal, stack, and platform rules"
```

---

## Task 3: Documentation Templates and Lifecycle (M3)

**Files:**
- Create: `runtime/docs-templates/project-brief-template.md`
- Create: `runtime/docs-templates/architecture-template.md`
- Create: `runtime/docs-templates/index-template.md`
- Create: `runtime/docs-templates/adr-template.md`

- [ ] **Step 1: Create project-brief-template.md**

```markdown
# {Project Name} — Project Brief

## Table of Contents
- [Summary](#summary)
- [Users](#users)
- [Core Capabilities](#core-capabilities)
- [Constraints](#constraints)
- [External Systems](#external-systems)
- [Success Criteria](#success-criteria)

## Metadata
- **Project:** {project_name}
- **Last Updated:** {date}
- **Status:** Draft | Active | Complete

## Summary

{One paragraph describing what this project is and why it exists.}

## Users

{Who uses this? What are their roles? What problems does it solve for them?}

## Core Capabilities

{Bulleted list of what the system does. Focus on capabilities, not implementation.}

## Constraints

{Technical constraints, business constraints, timeline constraints. What can't change?}

## External Systems

{What does this project depend on or integrate with? APIs, databases, services, hardware.}

## Success Criteria

{How do you know this project is done? Measurable outcomes.}
```

- [ ] **Step 2: Create architecture-template.md**

```markdown
# {Project Name} — Architecture

## Table of Contents
- [Purpose](#purpose)
- [System Boundaries](#system-boundaries)
- [Components](#components)
- [Key Decisions](#key-decisions)
- [Data Flow](#data-flow)

## Metadata
- **Project:** {project_name}
- **Last Updated:** {date}
- **Status:** Draft | Active

## Purpose

{One sentence: what does this system do at the highest level?}

## System Boundaries

{What is inside this system vs. outside? What does it own, what does it delegate?}

## Components

{List of major components/modules with one-line descriptions. Not exhaustive — focus on architecture-level units.}

| Component | Responsibility | Key Files |
|-----------|---------------|-----------|
| {name} | {what it does} | {where it lives} |

## Key Decisions

See `decisions/` for full ADRs. Summary of active decisions:

| ADR | Decision | Status |
|-----|----------|--------|
| ADR-001 | {title} | Accepted |

## Data Flow

{How does data move through the system? Entry points, processing, storage, output.}
```

- [ ] **Step 3: Create index-template.md**

```markdown
# Documentation Index — {Project Name}

## Metadata
- **Last Updated:** {date}

## Documents

| File | Purpose | Status | Last Updated |
|------|---------|--------|-------------|
| project-brief.md | Project concept and goals | {status} | {date} |
| architecture.md | System boundaries and decisions | {status} | {date} |
| decisions/ | Architecture Decision Records | — | — |
| plans/PLAN.md | Master plan | {status} | {date} |
| plans/PLAN-OVERVIEW.md | Milestone status at a glance | {status} | {date} |

## Plans

| File | Milestone | Status |
|------|-----------|--------|
| plans/PLAN-M1.md | {title} | {status} |

## Reviews

| File | Milestone | Type | Date |
|------|-----------|------|------|
| reviews/M1-review.md | M1 | Cross-agent review | {date} |
| reviews/M1-better-eng.md | M1 | Better engineering | {date} |
```

- [ ] **Step 4: Create adr-template.md**

```markdown
# ADR-{NNN}: {Title}

## Metadata
- **Status:** Proposed | Accepted | Superseded by ADR-{NNN}
- **Date:** {date}
- **Milestone:** {milestone that triggered this decision, if any}

## Context

{Why was this decision needed? What problem or trade-off prompted it?}

## Decision

{What was decided. Be specific.}

## Consequences

{What changes as a result of this decision? Both positive and negative.}

## Alternatives Considered

{What other options were evaluated? Why were they rejected?}
```

- [ ] **Step 5: Commit**

```bash
git add runtime/docs-templates/
git commit -m "feat(runtime): add documentation lifecycle templates"
```

---

## Task 4: Self-Update Mechanism (M4)

**Files:**
- Create: `runtime/sync.sh`
- Create: `runtime/skills/self-update.md`

- [ ] **Step 1: Create runtime/sync.sh**

```bash
#!/usr/bin/env bash
# sync.sh — Self-update .scaffold/ from upstream scaffold repo
# Usage: bash .scaffold/sync.sh
# Reads .scaffold/upstream.json for repo URL, branch, and last-synced commit.
# Overwrites upstream-owned directories. Never touches .scaffold/project/.

set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_JSON="$SCAFFOLD_DIR/upstream.json"

if [ ! -f "$UPSTREAM_JSON" ]; then
  echo "[scaffold] No upstream.json found — skipping sync"
  exit 0
fi

# Parse upstream.json (portable: python or node, fallback to grep)
parse_json() {
  local key="$1"
  if command -v python3 &>/dev/null; then
    python3 -c "import json,sys; print(json.load(sys.stdin)['$key'])" < "$UPSTREAM_JSON"
  elif command -v python &>/dev/null; then
    python -c "import json,sys; print(json.load(sys.stdin)['$key'])" < "$UPSTREAM_JSON"
  elif command -v node &>/dev/null; then
    node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('$UPSTREAM_JSON','utf8'))['$key'])"
  else
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$UPSTREAM_JSON" | sed 's/.*":\s*"//' | sed 's/"$//'
  fi
}

REPO_URL="$(parse_json repo_url)"
BRANCH="$(parse_json branch)"
LAST_COMMIT="$(parse_json last_synced_commit)"

echo "[scaffold] Checking upstream: $REPO_URL ($BRANCH)"

# Get current remote HEAD
REMOTE_HEAD="$(git ls-remote "$REPO_URL" "$BRANCH" 2>/dev/null | awk '{print $1}')" || {
  echo "[scaffold] WARNING: Could not reach upstream — continuing with local copy"
  exit 0
}

if [ -z "$REMOTE_HEAD" ]; then
  echo "[scaffold] WARNING: No remote HEAD found for branch '$BRANCH' — continuing with local copy"
  exit 0
fi

if [ "$REMOTE_HEAD" = "$LAST_COMMIT" ]; then
  echo "[scaffold] Up to date (${REMOTE_HEAD:0:8})"
  exit 0
fi

echo "[scaffold] Update available: ${LAST_COMMIT:0:8} → ${REMOTE_HEAD:0:8}"

# Clone to temp directory (sparse checkout of runtime/ only)
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

git clone --depth 1 --branch "$BRANCH" --filter=blob:none --sparse "$REPO_URL" "$TMPDIR/repo" 2>/dev/null
cd "$TMPDIR/repo"
git sparse-checkout set runtime 2>/dev/null

# Count changes
CHANGED=0
CHANGED_FILES=""

# Sync upstream-owned directories (never touch project/)
UPSTREAM_DIRS="orchestration skills tools references rules docs-templates"

for dir in $UPSTREAM_DIRS; do
  if [ -d "runtime/$dir" ]; then
    # Count files that differ
    if [ -d "$SCAFFOLD_DIR/$dir" ]; then
      while IFS= read -r file; do
        rel="${file#runtime/$dir/}"
        if [ ! -f "$SCAFFOLD_DIR/$dir/$rel" ] || ! diff -q "runtime/$dir/$rel" "$SCAFFOLD_DIR/$dir/$rel" &>/dev/null; then
          CHANGED=$((CHANGED + 1))
          CHANGED_FILES="$CHANGED_FILES $dir/$rel"
        fi
      done < <(find "runtime/$dir" -type f)
    else
      CHANGED=$((CHANGED + $(find "runtime/$dir" -type f | wc -l)))
    fi
    rm -rf "$SCAFFOLD_DIR/$dir"
    cp -r "runtime/$dir" "$SCAFFOLD_DIR/$dir"
  fi
done

# Sync root-level files (sync.sh itself)
if [ -f "runtime/sync.sh" ]; then
  if ! diff -q "runtime/sync.sh" "$SCAFFOLD_DIR/sync.sh" &>/dev/null 2>&1; then
    CHANGED=$((CHANGED + 1))
    CHANGED_FILES="$CHANGED_FILES sync.sh"
  fi
  cp "runtime/sync.sh" "$SCAFFOLD_DIR/sync.sh"
fi

# Update upstream.json with new commit
cd "$SCAFFOLD_DIR"
if command -v python3 &>/dev/null; then
  python3 -c "
import json
with open('upstream.json', 'r+') as f:
    data = json.load(f)
    data['last_synced_commit'] = '$REMOTE_HEAD'
    data['last_synced_date'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
elif command -v node &>/dev/null; then
  node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('upstream.json', 'utf8'));
data.last_synced_commit = '$REMOTE_HEAD';
data.last_synced_date = new Date().toISOString();
fs.writeFileSync('upstream.json', JSON.stringify(data, null, 2));
"
fi

if [ "$CHANGED" -gt 0 ]; then
  echo "[scaffold] Updated: $CHANGED files changed ($CHANGED_FILES)"
else
  echo "[scaffold] Synced to ${REMOTE_HEAD:0:8} (no file changes)"
fi
```

- [ ] **Step 2: Make sync.sh executable**

Run: `chmod +x runtime/sync.sh`

- [ ] **Step 3: Create runtime/skills/self-update.md**

```markdown
# Self-Update Skill

## Purpose

Check the upstream scaffold repo for updates on every session start. Keeps orchestration, skills, tools, references, and rules in sync across all projects.

## When to Run

- **Every session start**, before any other work
- After the handoff skill reads session state

## Instructions for Agent

On session start, perform these steps:

1. Check if `.scaffold/upstream.json` exists. If not, skip — this project is not scaffold-managed.

2. Run the sync script:
   ```bash
   bash .scaffold/sync.sh
   ```

3. Read the output:
   - "Up to date" → proceed normally
   - "Updated: N files changed" → note the changed files, they may affect current work
   - "WARNING: Could not reach upstream" → log the warning, proceed with local copy

4. If orchestration files changed, re-read any milestone files relevant to current work.

## Failure Handling

If sync fails, **do not block the session**. Log a warning and continue. The local copy is always functional — sync just keeps it current.

## upstream.json Format

```json
{
  "repo_url": "git@github.com:{owner}/scaffold.git",
  "branch": "main",
  "last_synced_commit": "{commit_hash}",
  "last_synced_date": "{ISO 8601 timestamp}"
}
```
```

- [ ] **Step 4: Test sync.sh parses upstream.json correctly**

Create a test upstream.json and verify parsing:

```bash
echo '{"repo_url":"git@github.com:test/scaffold.git","branch":"main","last_synced_commit":"abc123","last_synced_date":"2026-03-22T00:00:00Z"}' > /tmp/test-upstream.json
UPSTREAM_JSON=/tmp/test-upstream.json python3 -c "import json,sys,os; data=json.load(open(os.environ['UPSTREAM_JSON'])); assert data['repo_url']=='git@github.com:test/scaffold.git'; assert data['branch']=='main'; print('Parse OK')"
rm /tmp/test-upstream.json
```

Expected: `Parse OK`

- [ ] **Step 5: Commit**

```bash
git add runtime/sync.sh runtime/skills/self-update.md
git commit -m "feat(runtime): add self-update mechanism and skill"
```

---

## Task 5: Skills Library (M5)

**Files:**
- Create: `runtime/skills/handoff.md`
- Create: `runtime/skills/quota-guard.md`

- [ ] **Step 1: Create runtime/skills/handoff.md**

```markdown
# Session Handoff Skill

## Purpose

Maintain session continuity across agent sessions. Write a structured handoff file at session end, read it at session start.

## When to Run

- **Session start:** Check for existing handoff file and summarize where things left off
- **Session end:** Write handoff state when user signals completion

## Session Start Instructions

1. Check if `.scaffold/project/handoff.md` exists in the project root
2. If it exists and `last_updated` is within 7 days: greet with a one-line summary of where things left off, then proceed
3. If older than 7 days: mention it's stale and ask what to focus on
4. If no file: proceed normally

## Session End Instructions

When the user says "done", "wrap up", "end session", "that's it", or a major milestone completes:

1. If `.scaffold/project/handoff.md` exists, copy it to `.scaffold/project/handoff-history/handoff-{YYYYMMDD-HHmmss}.md` (create dir if needed)
2. Write a new `.scaffold/project/handoff.md` (keep under 40 lines):

```markdown
last_updated: YYYY-MM-DD HH:MM
session_summary: {one sentence}

## What Was Done
- {bullets}

## Current State
{brief description}

## Next Up
- {next steps from PLAN-OVERVIEW.md if available}

## Gotchas
- {watch out for these}
```

3. If a git repo, ensure `.scaffold/project/handoff.md` and `.scaffold/project/handoff-history/` are in `.gitignore`

## Important

- Do NOT read or write the handoff file mid-session — only at start and end
- Reference PLAN-OVERVIEW.md for "Next Up" if a plan exists
- Keep the handoff concise — it's for the next agent session, not a full report
```

- [ ] **Step 2: Create runtime/skills/quota-guard.md**

```markdown
# Quota Guard Skill

## Purpose

Prevent excessive token/compute usage by enforcing budget tiers with user confirmation gates.

## Budget Tiers

### LOW (Default)

No confirmation needed. Standard operating mode.

- Read only the files necessary for the task
- Reuse loaded context before fetching more
- Do not scan the whole workspace unless explicitly asked

### HIGH — Confirm First

Say: `Estimated quota impact: HIGH. Proceed? (yes/no)` before:

- Reading many files across the project (>10 files)
- Running broad workspace searches
- Generating multi-step plans from scratch
- Reading large files (>500 lines) in their entirety

### ULTRA — Confirm First

Say: `Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)` before:

- Full codebase analysis
- Large refactors spanning many files (>5 files)
- Architectural redesign
- Reading all files in a directory recursively

## Instructions for Agent

- Default to LOW for every operation
- Escalate to HIGH or ULTRA based on the criteria above
- If the user pre-authorizes a budget level ("go ahead and do a full analysis"), respect that for the current task only — reset to LOW for the next task
- Never silently perform ULTRA-level operations
```

- [ ] **Step 3: Commit**

```bash
git add runtime/skills/
git commit -m "feat(runtime): add handoff and quota-guard skills"
```

---

## Task 6: Planning Orchestration (M6)

**Files:**
- Create: `runtime/orchestration/PLAN-TEMPLATE.md`
- Create: `runtime/orchestration/MILESTONE-TEMPLATE.md`
- Create: `runtime/orchestration/plan-init.md`
- Create: `runtime/orchestration/milestone-run.md`

- [ ] **Step 1: Create PLAN-TEMPLATE.md**

```markdown
# {Project Name} — Master Plan

## Table of Contents
- [Concept](#concept)
- [Goals](#goals)
- [Constraints](#constraints)
- [Architecture Overview](#architecture-overview)
- [Milestone Breakdown](#milestone-breakdown)
- [Tool-Milestone Matrix](#tool-milestone-matrix)
- [Open Questions](#open-questions)

## Metadata
- **Project:** {project_name}
- **Created:** {date}
- **Last Updated:** {date}
- **Status:** Draft | Active | Complete

## Concept

{What is being built and why. 2-3 sentences. Derived from project context and user input.}

## Goals

{Bulleted list of concrete outcomes this plan achieves.}

## Constraints

{What limits the implementation? Technical, timeline, dependency constraints.}

## Architecture Overview

{High-level architecture for this plan's scope. Reference docs/architecture.md for the full system view.}

## Milestone Breakdown

| # | Title | Scope | Status | Dependencies |
|---|-------|-------|--------|-------------|
| M1 | {title} | {one-line scope} | Not Started | None |
| M2 | {title} | {one-line scope} | Not Started | M1 |

## Tool-Milestone Matrix

| Tool | M1 | M2 | M3 | Notes |
|------|----|----|-----|-------|
| {tool} | {active/inactive} | {active/inactive} | {active/inactive} | {why} |

## Open Questions

{Questions deferred from plan-init. Each tagged with the milestone that needs the answer.}

| Question | Relevant Milestone | Answered |
|----------|-------------------|----------|
| {question} | M{n} | No |
```

- [ ] **Step 2: Create MILESTONE-TEMPLATE.md**

```markdown
# PLAN-M{n}: {Milestone Title}

## Table of Contents
- [Scope](#scope)
- [Acceptance Criteria](#acceptance-criteria)
- [Deferred Questions](#deferred-questions)
- [Implementation Sequence](#implementation-sequence)
- [Orchestration Instructions](#orchestration-instructions)
- [Documentation Actions](#documentation-actions)
- [Validation](#validation)

## Metadata
- **Plan:** {plan_name}
- **Milestone:** M{n}
- **Status:** Not Started | In Progress | Review | Complete
- **Dependencies:** {list}

## Scope

{What this milestone delivers. Be specific about what is in scope and what is not.}

## Acceptance Criteria

{Bulleted list of measurable criteria. The milestone is done when all of these are true.}

## Deferred Questions

{Questions from plan-init that must be answered before this milestone can proceed. If empty, no blockers.}

| Question | Answer | Answered By |
|----------|--------|-------------|
| {question from PLAN.md} | {answer — filled when prompted} | {user/agent} |

## Implementation Sequence

{Ordered list of implementation steps. Each step should be concrete and actionable.}

1. {Step description}
   - Files: {paths}
   - Action: {what to do}

## Orchestration Instructions

> These instructions tell the implementing agent how to behave.

1. Read this entire file before starting
2. Confirm scope and acceptance criteria — if anything is unclear, ask before proceeding
3. Check deferred questions — prompt for answers if any are unanswered
4. Review `.scaffold/tools/manifest.json` — activate relevant tools for this milestone
5. Implement steps in the order defined above
6. After implementation, run all validation steps below
7. Trigger cross-agent review per `.scaffold/orchestration/milestone-review.md`
8. Update this file with validation results
9. Update `PLAN-OVERVIEW.md` status
10. Complete documentation actions listed below

## Documentation Actions

{Specific docs to create or update for this milestone.}

- [ ] Update `docs/INDEX.md`
- [ ] Update `PLAN-OVERVIEW.md` status to Complete
- [ ] Create ADRs for any architectural decisions made
- [ ] {Additional doc actions specific to this milestone}

## Validation

### Automated

{Commands to run. Fill these in during implementation.}

| Check | Command | Result | Pass |
|-------|---------|--------|------|
| {what} | {command} | {filled after run} | {yes/no} |

### Human-Verifiable

{Steps the human can perform to verify the milestone. Fill during implementation.}

- [ ] {verification step}

### Cross-Agent Review

{Filled by milestone-review.md orchestration after review completes.}

- **KISS:** {result}
- **Codebase Style:** {result}
- **Correctness:** {result}
- **Goal Fulfillment:** {result}
```

- [ ] **Step 3: Create plan-init.md**

```markdown
# Plan Initialization Orchestration

## Purpose

Guide an agent through creating a structured plan from existing project context. The output is a PLAN.md and individual PLAN-M{n}.md milestone files.

## Trigger

User says "init plan", "create a plan", "plan this project", or starts a new project with scaffold.

## Sequence

### 1. Gather Context (LOW compute)

Read these files if they exist (do not search broadly):
- `README.md` or `README`
- `docs/project-brief.md`
- `docs/architecture.md`
- `.scaffold/project/handoff.md`
- Any existing `docs/plans/PLAN.md`
- Project manifest files (`package.json`, `*.csproj`, `pyproject.toml`, `Cargo.toml`)

### 2. Assess Existing State

Determine:
- Is this a new project or an existing one?
- Is there an existing plan that needs updating or replacing?
- What is the detected stack?
- What context is already documented vs. needs to be gathered?

### 3. Prompt for Missing Information

Ask the user **one question at a time** for any information not derivable from existing files:

1. Project concept — what are we building and why?
2. Goals — what are the concrete outcomes?
3. Constraints — what limits the implementation?
4. Success criteria — how do we know it's done?
5. Milestone preferences — any specific breakdown the user has in mind?

**If the user skips a question:** Record it in PLAN.md's Open Questions table, tagged with the milestone that needs it. The agent implementing that milestone will prompt for it.

### 4. Build the Plan

Using `PLAN-TEMPLATE.md`:
1. Fill in all sections from gathered context and user input
2. Break the work into milestones — each should be a coherent, deliverable unit
3. Define dependencies between milestones
4. Write the plan to `docs/plans/PLAN.md`

### 5. Build Milestone Files

For each milestone, using `MILESTONE-TEMPLATE.md`:
1. Define scope, acceptance criteria, and implementation sequence
2. Copy relevant open questions to the milestone's Deferred Questions
3. Define documentation actions specific to this milestone
4. Embed the orchestration instructions (they're in the template)
5. Write to `docs/plans/PLAN-M{n}.md`

### 6. Build the Overview

Generate `docs/plans/PLAN-OVERVIEW.md`:

```markdown
# Plan Overview — {Project Name}

## Metadata
- **Last Updated:** {date}
- **Active Milestone:** None

## Milestones

| # | Title | Status | Dependencies | Key Deliverables |
|---|-------|--------|-------------|-----------------|
| M1 | {title} | Not Started | None | {deliverables} |

## Tool-Milestone Matrix

| Tool | M1 | M2 | M3 |
|------|----|----|-----|
| {tool} | ✓ | — | ✓ |
```

### 7. Update Architecture

If the plan introduced architecture assumptions, reflect them in `docs/architecture.md`.

### 8. Update Index

Add all new plan files to `docs/INDEX.md`.

## Output

After plan-init completes, present the user with:
1. A summary of the plan (milestone titles and one-line scopes)
2. Any open questions that were deferred
3. The command to start the first milestone: "To begin, prompt a fresh agent with: Please read docs/plans/PLAN-M1.md. Implement this plan per the instructions in that file."
```

- [ ] **Step 4: Create milestone-run.md**

```markdown
# Milestone Implementation Orchestration

## Purpose

Guide an agent through implementing a single milestone from a PLAN-M{n}.md file. This file defines the sequence of actions, validation, and documentation requirements.

## Trigger

Agent is prompted: "Please read PLAN-M{n}.md. Implement this plan per the instructions in that file."

## Pre-Implementation

### 1. Read and Confirm

- Read the entire milestone file
- Confirm understanding of scope and acceptance criteria
- If anything is ambiguous, ask the user before proceeding

### 2. Resolve Deferred Questions

- Check the Deferred Questions table
- If any questions are unanswered, prompt the user one at a time
- Record answers in the milestone file

### 3. Tool Check

- Read `.scaffold/tools/manifest.json`
- Review which tools are activated for this milestone (from PLAN-OVERVIEW.md tool-milestone matrix)
- Confirm or adjust tool activation based on milestone scope
- Read conflict declarations for activated tools
- Log: "Tools active for this milestone: {list}"

### 4. Context Loading

- Read `docs/architecture.md` and relevant ADRs
- Read any referenced files from previous milestones
- Note upfront if this milestone will change architecture: "This milestone will modify the architecture in the following ways: {list}"

## Implementation

### 5. Execute Steps

- Follow the Implementation Sequence in the milestone file, in order
- For each step:
  - Implement the change
  - Validate it works (build, test, type check as applicable)
  - If a step fails validation, fix before proceeding

### 6. Validation

- Run all automated validation steps defined in the milestone file
- Fill in the Validation table with results
- If any check fails, fix and re-run

## Post-Implementation

### 7. Tool Audit (Passive)

- Review `.scaffold/tools/manifest.json` against what was actually used
- Were any activated tools not used? Were any non-activated tools needed?
- Note observations in the milestone file's validation section

### 8. Cross-Agent Review

- Follow `.scaffold/orchestration/milestone-review.md` for the four-dimension review
- Address any objections from the reviewer
- Record review results in the milestone file

### 9. Documentation

- Complete all Documentation Actions listed in the milestone file
- Update `PLAN-OVERVIEW.md`: set this milestone to Complete, set next milestone to Active
- Update `docs/INDEX.md` with any new files created
- Create ADRs for architectural decisions made during implementation

### 10. Better Engineering Prompt

After all the above is complete, prompt the user:

> "Milestone M{n} complete. Run better-engineering review? (yes/no)"

If yes, follow `.scaffold/orchestration/better-engineering.md`.

### 11. Usage Log

Append to `.scaffold/project/usage-log.json`:

```json
{
  "milestone": "M{n}",
  "date": "{today}",
  "used": ["{list of tools/skills actually used}"],
  "available": ["{list of all activated tools/skills}"]
}
```

### 12. Handoff

If the session is ending, follow `.scaffold/skills/handoff.md` to write session state.
```

- [ ] **Step 5: Commit**

```bash
git add runtime/orchestration/
git commit -m "feat(runtime): add planning orchestration templates and instructions"
```

---

## Task 7: Cross-Agent Review + Better Engineering (M7)

**Files:**
- Create: `runtime/orchestration/milestone-review.md`
- Create: `runtime/orchestration/better-engineering.md`
- Create: `runtime/tools/codex-review.sh`

- [ ] **Step 1: Create milestone-review.md**

```markdown
# Cross-Agent Review Orchestration

## Purpose

After milestone implementation, get a second opinion from a different agent across four dimensions. This ensures quality before marking a milestone complete.

## Trigger

Called by `milestone-run.md` step 8, after implementation and validation pass.

## Review Dimensions

Each dimension is a separate review request:

### 1. KISS

> Review the implementation for this milestone. Focus ONLY on simplicity:
> - Is anything over-engineered?
> - Are there simpler approaches that achieve the same result?
> - Are there unnecessary abstractions, indirections, or future-proofing?
> Answer: PASS (no issues) or OBJECTION (with specific concerns and simpler alternatives).

### 2. Codebase Style

> Review the implementation for this milestone. Focus ONLY on codebase consistency:
> - Does the new code follow existing patterns and conventions?
> - Are naming conventions, file organization, and code structure consistent?
> - Does it feel like it belongs in this codebase?
> Answer: PASS (no issues) or OBJECTION (with specific inconsistencies).

### 3. Correctness

> Review the implementation for this milestone. Focus ONLY on correctness:
> - Are there bugs, logic errors, or unhandled edge cases?
> - Are there race conditions, resource leaks, or security issues?
> - Do the tests actually test the right things?
> Answer: PASS (no issues) or OBJECTION (with specific bugs or concerns).

### 4. Goal Fulfillment

> Review the implementation for this milestone. Focus ONLY on goal fulfillment:
> - Does the implementation achieve what the milestone's acceptance criteria defined?
> - Is anything missing from the acceptance criteria?
> - Is anything implemented that wasn't in scope?
> Answer: PASS (no issues) or OBJECTION (with specific gaps or scope creep).

## Execution

### Preferred: Codex CLI

For each dimension, invoke:

```bash
bash .scaffold/tools/codex-review.sh \
  --dimension "{KISS|style|correctness|goals}" \
  --milestone "docs/plans/PLAN-M{n}.md" \
  --files "{space-separated list of changed files}"
```

### Fallback: Manual Paste

If Codex CLI is not available, generate the four review prompts as structured text that the user can paste into a separate agent session. Format:

```
=== REVIEW REQUEST: {DIMENSION} ===
Milestone: PLAN-M{n}
Files changed: {list}

{review prompt from above}

Context:
{milestone scope and acceptance criteria}
===
```

## Handling Objections

- If the reviewer raises an OBJECTION on any dimension:
  1. Assess the objection — is it valid?
  2. If valid: make the fix, then re-submit that dimension for review
  3. If questionable: explain your reasoning and re-submit. If the reviewer insists, make the fix.
  4. Loop until all four dimensions PASS or escalate to user after 3 iterations
- Record all review results (including objections and fixes) in the milestone file

## Output

Update the milestone file's Cross-Agent Review section:

```markdown
### Cross-Agent Review

- **KISS:** PASS
- **Codebase Style:** PASS — minor naming fix applied (renamed X to Y)
- **Correctness:** OBJECTION → Fixed: added null check in Z — PASS on re-review
- **Goal Fulfillment:** PASS
```

Save the full review exchange to `docs/reviews/M{n}-review.md`.
```

- [ ] **Step 2: Create better-engineering.md**

```markdown
# Better Engineering Review Orchestration

## Purpose

After a milestone completes, assess opportunities for architectural improvement, code quality, and engineering excellence. This is the human's primary value-add — reviewing AI assessments and making taste decisions.

## Trigger

After milestone completion, the implementing agent prompts: "Milestone M{n} complete. Run better-engineering review? (yes/no)"

User must opt in.

## Sequence

### 1. Independent Assessments

Two agents independently assess better-engineering opportunities:

**Claude assessment prompt:**
> Review the codebase after milestone M{n} completion. Identify opportunities for better engineering:
> - Architecture: Are boundaries clean? Are responsibilities clear? Is coupling appropriate?
> - Code quality: Are there patterns that should be refactored? Duplication? Unclear naming?
> - Testing: Are tests meaningful? Is coverage appropriate? Are there testing gaps?
> - Performance: Any obvious bottlenecks or inefficiencies?
> - Maintainability: Would a new developer understand this code? Are there landmines?
>
> For each finding, rate severity (low/medium/high) and effort (small/medium/large).
> Focus on findings that matter, not style nitpicks.

**Codex assessment prompt:**
> {Same prompt, sent to Codex CLI or as a manual paste prompt}

### 2. Cross-Review

A fresh instance of each agent reviews the other's assessment:

**Cross-review prompt:**
> You are reviewing another agent's better-engineering assessment of milestone M{n}.
> Here is their assessment: {paste assessment}
>
> Evaluate each finding:
> - AGREE: The finding is valid and worth addressing
> - DISAGREE: The finding is incorrect, premature, or not worth the effort (explain why)
> - ENHANCE: The finding is valid but incomplete (add what's missing)

### 3. Present to User

Compile results into `docs/reviews/M{n}-better-eng.md`:

```markdown
# Better Engineering Review — M{n}

## Metadata
- **Date:** {date}
- **Milestone:** M{n}

## Findings

| # | Finding | Severity | Effort | Claude | Codex | Consensus |
|---|---------|----------|--------|--------|-------|-----------|
| 1 | {finding} | {sev} | {effort} | AGREE | AGREE | Unanimous |
| 2 | {finding} | {sev} | {effort} | AGREE | DISAGREE | Split |

## Detail

### Finding 1: {title}
**Claude says:** {assessment}
**Codex says:** {assessment}
**Cross-review:** {consensus or disagreement}

## Recommended Sub-Milestones

Based on findings with consensus, these sub-milestones are recommended:

| Sub-Milestone | Scope | Effort | Findings Addressed |
|--------------|-------|--------|-------------------|
| M{n}-BE1 | {scope} | {effort} | #1, #3 |
```

### 4. User Decides

Present the compiled review and ask:
> "Here are the better-engineering findings for M{n}. Which findings would you like to address? I'll create sub-milestones for the ones you select."

### 5. Create Sub-Milestones

For each selected finding (or group of related findings):
1. Create `docs/plans/PLAN-M{n}-BE{k}.md` using `MILESTONE-TEMPLATE.md`
2. Add to `PLAN-OVERVIEW.md`
3. Update `docs/INDEX.md`

## Important Notes

- The human reviews the assessments — they are the taste arbiter
- Not every finding needs to be addressed — the user decides what's worth the effort
- Better-engineering sub-milestones follow the same implementation orchestration as regular milestones
- Sub-milestones do NOT trigger another better-engineering review (avoid infinite recursion)
```

- [ ] **Step 3: Create codex-review.sh**

```bash
#!/usr/bin/env bash
# codex-review.sh — Invoke Codex CLI for cross-agent milestone review
# Usage: bash .scaffold/tools/codex-review.sh --dimension KISS --milestone PLAN-M1.md --files "src/foo.py src/bar.py"

set -euo pipefail

DIMENSION=""
MILESTONE=""
FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dimension) DIMENSION="$2"; shift 2 ;;
    --milestone) MILESTONE="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$DIMENSION" ] || [ -z "$MILESTONE" ]; then
  echo "Usage: codex-review.sh --dimension <KISS|style|correctness|goals> --milestone <path> [--files <paths>]"
  exit 1
fi

# Build the review prompt based on dimension
case "$DIMENSION" in
  KISS|kiss)
    PROMPT="Review the implementation for this milestone. Focus ONLY on simplicity: Is anything over-engineered? Are there simpler approaches that achieve the same result? Are there unnecessary abstractions, indirections, or future-proofing? Answer: PASS (no issues) or OBJECTION (with specific concerns and simpler alternatives)."
    ;;
  style)
    PROMPT="Review the implementation for this milestone. Focus ONLY on codebase consistency: Does the new code follow existing patterns and conventions? Are naming conventions, file organization, and code structure consistent? Does it feel like it belongs in this codebase? Answer: PASS (no issues) or OBJECTION (with specific inconsistencies)."
    ;;
  correctness)
    PROMPT="Review the implementation for this milestone. Focus ONLY on correctness: Are there bugs, logic errors, or unhandled edge cases? Are there race conditions, resource leaks, or security issues? Do the tests actually test the right things? Answer: PASS (no issues) or OBJECTION (with specific bugs or concerns)."
    ;;
  goals)
    PROMPT="Review the implementation for this milestone. Focus ONLY on goal fulfillment: Does the implementation achieve what the milestone's acceptance criteria defined? Is anything missing from the acceptance criteria? Is anything implemented that wasn't in scope? Answer: PASS (no issues) or OBJECTION (with specific gaps or scope creep)."
    ;;
  *)
    echo "Unknown dimension: $DIMENSION (expected: KISS, style, correctness, goals)"
    exit 1
    ;;
esac

# Read milestone file for context
if [ ! -f "$MILESTONE" ]; then
  echo "Milestone file not found: $MILESTONE"
  exit 1
fi

MILESTONE_CONTENT="$(cat "$MILESTONE")"

# Build file context
FILE_CONTEXT=""
if [ -n "$FILES" ]; then
  for f in $FILES; do
    if [ -f "$f" ]; then
      FILE_CONTEXT="$FILE_CONTEXT

--- $f ---
$(cat "$f")
"
    fi
  done
fi

# Check if codex CLI is available
if ! command -v codex &>/dev/null; then
  echo "=== CODEX CLI NOT AVAILABLE — MANUAL REVIEW PROMPT ==="
  echo ""
  echo "=== REVIEW REQUEST: $DIMENSION ==="
  echo "Milestone: $MILESTONE"
  echo "Files changed: $FILES"
  echo ""
  echo "$PROMPT"
  echo ""
  echo "Context:"
  echo "$MILESTONE_CONTENT"
  if [ -n "$FILE_CONTEXT" ]; then
    echo ""
    echo "=== FILES ==="
    echo "$FILE_CONTEXT"
  fi
  echo "==="
  exit 0
fi

# Invoke Codex CLI
FULL_PROMPT="$PROMPT

Milestone context:
$MILESTONE_CONTENT"

if [ -n "$FILE_CONTEXT" ]; then
  FULL_PROMPT="$FULL_PROMPT

Changed files:
$FILE_CONTEXT"
fi

codex --approval-mode full-auto -q "$FULL_PROMPT"
```

- [ ] **Step 4: Make codex-review.sh executable**

Run: `chmod +x runtime/tools/codex-review.sh`

- [ ] **Step 5: Commit**

```bash
git add runtime/orchestration/milestone-review.md runtime/orchestration/better-engineering.md runtime/tools/codex-review.sh
git commit -m "feat(runtime): add cross-agent review and better-engineering orchestration"
```

---

## Task 8: Tool Auditing and Smart Prompting (M8)

**Files:**
- Create: `runtime/tools/plan-overview-gen.sh`

The auditing logic itself is embedded in `milestone-run.md` (already created in M6). This task creates the plan-overview generator and defines the `tool-config.json` and `usage-log.json` schemas.

- [ ] **Step 1: Create plan-overview-gen.sh**

```bash
#!/usr/bin/env bash
# plan-overview-gen.sh — Regenerate PLAN-OVERVIEW.md from milestone files
# Usage: bash .scaffold/tools/plan-overview-gen.sh [docs/plans]
# Scans PLAN-M*.md files and rebuilds the overview table.

set -euo pipefail

PLANS_DIR="${1:-docs/plans}"

if [ ! -d "$PLANS_DIR" ]; then
  echo "Plans directory not found: $PLANS_DIR"
  exit 1
fi

if [ ! -f "$PLANS_DIR/PLAN.md" ]; then
  echo "No PLAN.md found in $PLANS_DIR"
  exit 1
fi

# Extract project name from PLAN.md first line
PROJECT_NAME="$(head -1 "$PLANS_DIR/PLAN.md" | sed 's/^# //' | sed 's/ — Master Plan//')"

echo "# Plan Overview — $PROJECT_NAME"
echo ""
echo "## Metadata"
echo "- **Last Updated:** $(date +%Y-%m-%d)"
echo ""
echo "## Milestones"
echo ""
echo "| # | Title | Status | Dependencies |"
echo "|---|-------|--------|-------------|"

# Parse each milestone file
for mfile in "$PLANS_DIR"/PLAN-M*.md; do
  [ -f "$mfile" ] || continue

  BASENAME="$(basename "$mfile" .md)"
  NUM="$(echo "$BASENAME" | grep -oP 'M\d+(-BE\d+)?')"

  TITLE="$(head -1 "$mfile" | sed "s/^# PLAN-M[0-9]*\(-BE[0-9]*\)\?: //")"
  STATUS="$(grep -oP '(?<=\*\*Status:\*\* ).*' "$mfile" | head -1)" || STATUS="Unknown"
  DEPS="$(grep -oP '(?<=\*\*Dependencies:\*\* ).*' "$mfile" | head -1)" || DEPS="None"

  echo "| $NUM | $TITLE | $STATUS | $DEPS |"
done

echo ""
echo "## Tool-Milestone Matrix"
echo ""
echo "_(Regenerate with tool-config.json data when available)_"
```

- [ ] **Step 2: Make plan-overview-gen.sh executable**

Run: `chmod +x runtime/tools/plan-overview-gen.sh`

- [ ] **Step 3: Document tool-config.json and usage-log.json schemas**

Add a `_schemas` key to `runtime/tools/manifest.json` so the implementing agent knows the expected format for project-level config files. Edit `manifest.json` to add this at the top level alongside `version`, `description`, and `tools`:

```json
"_schemas": {
  "tool-config": {
    "description": "Schema for .scaffold/project/tool-config.json — created at init, never overwritten by sync",
      "example": {
        "project": "{project_name}",
        "initialized": "{YYYY-MM-DD}",
        "audit_interval_milestones": 3,
        "activated_tools": ["sync", "plan-overview-gen"],
        "activated_references": ["context7"],
        "deactivated": {
          "codex-review": "no Codex CLI available"
        }
      }
    },
  "usage-log": {
    "description": "Schema for .scaffold/project/usage-log.json — append-only, one entry per milestone",
    "example": [
      {
        "milestone": "M1",
        "date": "2026-03-22",
        "used": ["sync", "handoff"],
        "available": ["sync", "handoff", "codex-review", "plan-overview-gen"],
        "notes": "codex-review skipped — reviewer was unavailable"
      }
    ]
  }
}
```

The previous description of these schemas below is kept for reference but the canonical source is the manifest itself.

The `tool-config.json` schema (for `.scaffold/project/tool-config.json`):

```json
{
  "project": "{project_name}",
  "initialized": "{date}",
  "audit_interval_milestones": 3,
  "activated_tools": ["sync", "plan-overview-gen"],
  "activated_references": ["context7"],
  "deactivated": {
    "codex-review": "no Codex CLI available"
  }
}
```

The `usage-log.json` schema (for `.scaffold/project/usage-log.json`):

```json
[
  {
    "milestone": "M1",
    "date": "2026-03-22",
    "used": ["sync", "handoff"],
    "available": ["sync", "handoff", "codex-review", "plan-overview-gen"],
    "notes": "codex-review skipped — reviewer was unavailable"
  }
]
```

These schemas are documented in the manifest as example files, not enforced programmatically. The agent creates them during init.

- [ ] **Step 4: Commit**

```bash
git add runtime/tools/
git commit -m "feat(runtime): add plan-overview generator and tool audit schemas"
```

---

## Task 9: apply-scaffold.ps1 Integration (M9)

**Files:**
- Modify: `scripts/apply-scaffold.ps1`

This is the integration milestone — modifying the existing bootstrap script to inject the runtime layer into target projects.

- [ ] **Step 1: Read the current apply-scaffold.ps1**

Read: `scripts/apply-scaffold.ps1` in full to understand the existing structure and find the right insertion points.

- [ ] **Step 2: Add runtime injection function**

Add a function `Copy-RuntimeToTarget` that:
1. Copies `runtime/` contents to `{target}/.scaffold/`
2. Skips `.scaffold/project/` if it already exists (never overwrite)
3. Creates `.scaffold/project/` with empty `rules.md`, `tool-config.json`, and `usage-log.json` if they don't exist
4. Creates `.scaffold/upstream.json` with the scaffold repo URL, branch, and current commit hash

```powershell
function Copy-RuntimeToTarget {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [string]$RepoUrl,
        [string]$Branch = "main"
    )

    $runtimeSource = Join-Path $ScaffoldRoot "runtime"
    $scaffoldTarget = Join-Path $TargetPath ".scaffold"

    if (-not (Test-Path $runtimeSource)) {
        Write-Warning "Runtime directory not found at $runtimeSource — skipping runtime injection"
        return
    }

    # Copy upstream-owned directories
    $upstreamDirs = @("orchestration", "skills", "tools", "references", "rules", "docs-templates")
    foreach ($dir in $upstreamDirs) {
        $src = Join-Path $runtimeSource $dir
        $dst = Join-Path $scaffoldTarget $dir
        if (Test-Path $src) {
            if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
            Copy-Item -Recurse -Force $src $dst
        }
    }

    # Copy root-level runtime files
    $rootFiles = @("sync.sh")
    foreach ($file in $rootFiles) {
        $src = Join-Path $runtimeSource $file
        $dst = Join-Path $scaffoldTarget $file
        if (Test-Path $src) {
            Copy-Item -Force $src $dst
        }
    }

    # Create project-owned directory if it doesn't exist
    $projectDir = Join-Path $scaffoldTarget "project"
    if (-not (Test-Path $projectDir)) {
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        # Empty project rules
        Set-Content -Path (Join-Path $projectDir "rules.md") -Value "# Project-Specific Rules`n`nAdd project-specific agent rules here. This file is never overwritten by scaffold sync.`n"

        # Default tool-config
        $toolConfig = @{
            project = (Split-Path $TargetPath -Leaf)
            initialized = (Get-Date -Format "yyyy-MM-dd")
            audit_interval_milestones = 3
            activated_tools = @("sync", "plan-overview-gen")
            activated_references = @()
            deactivated = @{}
        }
        $toolConfig | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $projectDir "tool-config.json")

        # Empty usage log
        Set-Content -Path (Join-Path $projectDir "usage-log.json") -Value "[]"
    }

    # Create/update upstream.json
    $currentCommit = ""
    try {
        $currentCommit = git -C $ScaffoldRoot rev-parse HEAD 2>$null
    } catch { }

    $upstream = @{
        repo_url = $RepoUrl
        branch = $Branch
        last_synced_commit = $currentCommit
        last_synced_date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    $upstream | ConvertTo-Json | Set-Content -Path (Join-Path $scaffoldTarget "upstream.json")

    Write-Host "[scaffold] Runtime injected to $scaffoldTarget"
}
```

- [ ] **Step 3: Add documentation template injection**

Add a function `Copy-DocTemplates` that:
1. Copies doc templates from `runtime/docs-templates/` to `{target}/docs/`
2. Performs token substitution (`{project_name}`, `{date}`)
3. Only copies if the target file doesn't already exist (never overwrite project docs)

```powershell
function Copy-DocTemplates {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [string]$ProjectName
    )

    $templateDir = Join-Path $ScaffoldRoot "runtime" "docs-templates"
    $docsDir = Join-Path $TargetPath "docs"

    if (-not (Test-Path $templateDir)) { return }
    if (-not (Test-Path $docsDir)) {
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    }

    $templateMap = @{
        "project-brief-template.md" = "project-brief.md"
        "architecture-template.md"  = "architecture.md"
        "index-template.md"         = "INDEX.md"
        "adr-template.md"           = "decisions/ADR-TEMPLATE.md"
    }

    $today = Get-Date -Format "yyyy-MM-dd"

    foreach ($template in $templateMap.GetEnumerator()) {
        $src = Join-Path $templateDir $template.Key
        $dst = Join-Path $docsDir $template.Value

        if ((Test-Path $src) -and -not (Test-Path $dst)) {
            $dstDir = Split-Path $dst -Parent
            if (-not (Test-Path $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }

            $content = Get-Content -Raw $src
            $content = $content -replace '\{project_name\}', $ProjectName
            $content = $content -replace '\{date\}', $today
            $content = $content -replace '\{status\}', 'Draft'
            Set-Content -Path $dst -Value $content
        }
    }

    # Create plans and reviews directories
    @("plans", "reviews", "decisions") | ForEach-Object {
        $dir = Join-Path $docsDir $_
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -Path (Join-Path $dir ".gitkeep") -Value ""
        }
    }

    Write-Host "[scaffold] Documentation templates applied to $docsDir"
}
```

- [ ] **Step 4: Add tool discovery prompts**

Add a function `Invoke-ToolDiscovery` that reads the manifest and registry, compares against detected stack, and outputs which tools to activate vs. ask about:

```powershell
function Invoke-ToolDiscovery {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [hashtable]$DetectedSignals  # stack, has_api, has_frontend, etc.
    )

    $manifestPath = Join-Path $ScaffoldRoot "runtime" "tools" "manifest.json"
    $registryPath = Join-Path $ScaffoldRoot "runtime" "references" "registry.json"
    $toolConfigPath = Join-Path $TargetPath ".scaffold" "project" "tool-config.json"

    if (-not (Test-Path $manifestPath)) { return }

    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
    $registry = if (Test-Path $registryPath) { Get-Content -Raw $registryPath | ConvertFrom-Json } else { $null }

    $activated = @()
    $suggestions = @()

    # Auto-activate tools marked as auto_activate
    foreach ($tool in $manifest.tools) {
        if ($tool.auto_activate) {
            $activated += $tool.name
        }
    }

    # Check references against detected signals
    if ($registry) {
        foreach ($ref in $registry.references) {
            $shouldSuggest = $false
            foreach ($trigger in $ref.auto_suggest_when) {
                if ($trigger -eq "any") { $shouldSuggest = $true; break }
                if ($trigger -eq "api" -and $DetectedSignals.has_api) { $shouldSuggest = $true; break }
                if ($trigger -eq "frontend" -and $DetectedSignals.has_frontend) { $shouldSuggest = $true; break }
                if ($trigger -eq "web" -and $DetectedSignals.has_frontend) { $shouldSuggest = $true; break }
                if ($trigger -eq "large_codebase" -and $DetectedSignals.large_codebase) { $shouldSuggest = $true; break }
            }

            if ($shouldSuggest) {
                $suggestions += @{
                    name = $ref.name
                    description = $ref.description
                    reason = "Detected: $($ref.auto_suggest_when -join ', ')"
                }
            }
        }
    }

    Write-Host "`n[scaffold] Tool Discovery:"
    Write-Host "  Auto-activated: $($activated -join ', ')"

    if ($suggestions.Count -gt 0) {
        Write-Host "  Suggested (confirm with agent on first session):"
        foreach ($s in $suggestions) {
            Write-Host "    - $($s.name): $($s.description) ($($s.reason))"
        }
    }

    # Update tool-config.json
    if (Test-Path $toolConfigPath) {
        $config = Get-Content -Raw $toolConfigPath | ConvertFrom-Json
        $config.activated_tools = $activated
        $config.activated_references = @()  # suggestions need user confirmation
        $config | ConvertTo-Json -Depth 3 | Set-Content -Path $toolConfigPath
    }
}
```

- [ ] **Step 5: Wire functions into main apply-scaffold flow**

Find the main execution block in `apply-scaffold.ps1` and add calls to the three new functions after the existing template copy and agent rule generation.

**Expected existing variables** (already defined in the script — do NOT redeclare these):
- `$ScaffoldRoot` — path to the scaffold repo root
- `$TargetPath` — path to the target project being scaffolded
- `$ProjectName` — detected or user-supplied project name
- `$detectedStack` — string like "dotnet", "python", "node" (from manifest detection)
- `$hasApiSurface` — boolean, true if API routes/endpoints detected

```powershell
# After existing scaffold application logic:

# --- Runtime Layer ---
if (Test-Path (Join-Path $ScaffoldRoot "runtime")) {
    $repoUrl = ""
    try {
        $repoUrl = git -C $ScaffoldRoot remote get-url origin 2>$null
    } catch { }

    if (-not $repoUrl) {
        Write-Warning "No git remote found for scaffold repo — upstream.json will have empty repo_url"
    }

    Copy-RuntimeToTarget -ScaffoldRoot $ScaffoldRoot -TargetPath $TargetPath -RepoUrl $repoUrl
    Copy-DocTemplates -ScaffoldRoot $ScaffoldRoot -TargetPath $TargetPath -ProjectName $ProjectName

    $signals = @{
        stack = $detectedStack
        has_api = $hasApiSurface
        has_frontend = $false  # detect from manifest signals
        large_codebase = ((Get-ChildItem -Recurse -File $TargetPath -ErrorAction SilentlyContinue | Measure-Object).Count -gt 100)
    }
    Invoke-ToolDiscovery -ScaffoldRoot $ScaffoldRoot -TargetPath $TargetPath -DetectedSignals $signals
}
```

- [ ] **Step 6: Add .scaffold/ to the target project's .gitignore entries**

Ensure that `apply-scaffold.ps1` adds `.scaffold/project/handoff.md` and `.scaffold/project/handoff-history/` to the target project's `.gitignore` (the rest of `.scaffold/` should be committed so other developers/agents get the orchestration files).

- [ ] **Step 7: Test the integration end-to-end**

Create a temp directory, run apply-scaffold against it, verify:

```bash
mkdir -p /tmp/test-scaffold-runtime
cd /tmp/test-scaffold-runtime && git init
pwsh -File C:/Users/Matt/Desktop/MyDocs/scaffold/scripts/apply-scaffold.ps1 -TargetPath /tmp/test-scaffold-runtime -ProjectName test-project
```

Verify:
- `.scaffold/upstream.json` exists and has correct structure
- `.scaffold/orchestration/` contains all template and orchestration files
- `.scaffold/skills/` contains handoff, self-update, quota-guard
- `.scaffold/tools/` contains manifest.json, codex-review.sh, plan-overview-gen.sh
- `.scaffold/rules/` contains always.md and stack-specific rules
- `.scaffold/project/` contains rules.md, tool-config.json, usage-log.json
- `docs/project-brief.md` exists with token substitution applied
- `docs/INDEX.md` exists
- `docs/decisions/` directory exists

```bash
ls -la /tmp/test-scaffold-runtime/.scaffold/
ls -la /tmp/test-scaffold-runtime/.scaffold/orchestration/
ls -la /tmp/test-scaffold-runtime/.scaffold/project/
ls -la /tmp/test-scaffold-runtime/docs/
cat /tmp/test-scaffold-runtime/.scaffold/upstream.json
rm -rf /tmp/test-scaffold-runtime
```

- [ ] **Step 8: Commit**

```bash
git add scripts/apply-scaffold.ps1
git commit -m "feat(scaffold): integrate runtime layer injection into apply-scaffold"
```

---

## Post-Implementation

After all 9 tasks are complete:

1. Push the scaffold repo to a private GitHub repo
2. Test the full cycle: apply scaffold to a real project, verify self-update works, run plan-init
3. Verify `.scaffold/` syncs correctly when upstream changes are pushed
