# Scaffold Runtime — Living Orchestration Framework

## Table of Contents
- [Overview](#overview)
- [Architecture: Two-Layer Model](#architecture-two-layer-model)
- [Repo Structure](#repo-structure)
- [Self-Update Mechanism](#self-update-mechanism)
- [Planning & Milestone Orchestration](#planning--milestone-orchestration)
- [Skill/Tool/Reference Library](#skilltoolreference-library)
- [Documentation Standards & Lifecycle](#documentation-standards--lifecycle)
- [Rule Segmentation](#rule-segmentation)
- [Tool Auditing & Smart Prompting](#tool-auditing--smart-prompting)
- [Future Features](#future-features)

## Metadata
- **Project:** scaffold
- **Date:** 2026-03-22
- **Status:** Approved design
- **Target platforms:** Claude Code (first), then Codex CLI, Cursor/Windsurf

---

## Overview

Evolve the scaffold project from a one-shot project bootstrapper into a living, self-updating orchestration framework. Projects reference a private GitHub repo as their upstream source of truth for agent rules, planning orchestration, skills, and tool references. The system enforces consistent project structure, enables cross-agent review workflows, and improves itself over time — changes pushed to the scaffold repo propagate to all projects automatically.

**Key principles:**
- Bootstrap runs once; runtime runs every session
- Plans are written for AI consumption, not human reading
- The human's job is architecture oversight and better-engineering decisions
- Documentation is a milestone completion requirement, not a post-hoc task
- Self-improvement is continuous — the repo checks itself for updates

---

## Architecture: Two-Layer Model

**Bootstrap layer** (existing `scaffold/` + `scripts/`): One-shot project setup. Copies templates, detects stack, generates initial agent configs. Runs via `apply-scaffold.ps1`.

**Runtime layer** (new `runtime/`): Injected into projects as `.scaffold/`. Contains orchestration instructions, skills, tool manifests, and self-update logic. Agents interact with this layer every session. Synced from the private GitHub repo.

The two layers share a repo but have different lifecycles. Bootstrap is invoked manually. Runtime is autonomous.

---

## Repo Structure

```
scaffold/                              # repo root
├── scaffold/                          # EXISTING — bootstrap layer
│   └── templates/common/              # one-shot project templates
├── scripts/                           # EXISTING — apply-scaffold.ps1, etc.
├── runtime/                           # NEW — injected into projects as .scaffold/
│   ├── sync.sh                        # self-update script
│   ├── orchestration/                 # planning & milestone system
│   │   ├── PLAN-TEMPLATE.md           # structured plan template
│   │   ├── MILESTONE-TEMPLATE.md      # per-milestone file template
│   │   ├── plan-init.md               # orchestration: how to build a plan
│   │   ├── milestone-run.md           # orchestration: how to implement
│   │   ├── milestone-review.md        # orchestration: cross-agent review
│   │   └── better-engineering.md      # orchestration: post-milestone review
│   ├── skills/                        # skill library
│   │   ├── handoff.md                 # session continuity
│   │   ├── self-update.md             # check scaffold repo on session start
│   │   └── quota-guard.md             # compute budget tiers
│   ├── tools/                         # tool references & configs
│   │   ├── manifest.json              # available tools with metadata
│   │   ├── codex-review.sh            # invoke Codex CLI for review
│   │   └── plan-overview-gen.sh       # regenerate PLAN-OVERVIEW.md
│   ├── references/                    # pointers to external repos/MCPs
│   │   └── registry.json              # name, repo URL, platform, description
│   └── rules/                         # cross-project agent rules
│       ├── always.md                  # universal rules for every project
│       ├── catalog.md                 # index of project-specific rules
│       ├── stacks/                    # stack-specific rules
│       │   ├── dotnet.md
│       │   ├── python.md
│       │   └── node.md
│       └── per-platform/              # platform-specific rendering
│           ├── claude.md
│           ├── codex.md
│           └── agents.md
├── docs/                              # EXISTING + new
│   └── future/                        # future feature explorations
│       ├── package-manager.md         # Approach C evolution
│       └── doc-format-optimization.md # token-efficient doc formats
├── reports/                           # EXISTING — generated project reports
└── scaffold.config.json               # EXISTING — project metadata
```

**In target projects after init:**

```
project-root/
├── .scaffold/
│   ├── upstream.json              # repo URL, branch, last-synced commit
│   ├── orchestration/             # copied from runtime/orchestration/
│   ├── skills/                    # copied from runtime/skills/
│   ├── tools/                     # copied from runtime/tools/
│   ├── references/                # copied from runtime/references/
│   ├── rules/                     # copied from runtime/rules/
│   └── project/                   # project-specific overrides (never synced)
│       ├── rules.md               # project-owned rules
│       ├── tool-config.json       # which tools are active for this project
│       └── usage-log.json         # tool usage tracking per milestone
├── docs/
│   ├── project-brief.md
│   ├── architecture.md
│   ├── INDEX.md                   # master directory of all docs
│   ├── decisions/
│   │   └── ADR-001-*.md
│   ├── plans/
│   │   ├── PLAN.md
│   │   ├── PLAN-OVERVIEW.md
│   │   └── PLAN-M{n}.md
│   └── reviews/
│       ├── M{n}-review.md
│       └── M{n}-better-eng.md
```

---

## Self-Update Mechanism

**Trigger:** Every agent session start, via the `self-update.md` skill.

**Sequence:**

1. Read `.scaffold/upstream.json` — get repo URL, branch, last-synced commit hash
2. Run `git ls-remote {url} {branch}` — get current HEAD
3. If HEAD == last-synced: log "scaffold up to date", continue
4. If HEAD != last-synced:
   a. Fetch upstream `runtime/` to a temp location
   b. Overwrite all upstream-owned directories in `.scaffold/` (orchestration, skills, tools, references, rules)
   c. Never touch `.scaffold/project/`
   d. Update `.scaffold/upstream.json` with new commit hash
   e. Log summary: "Scaffold updated: N files changed (list)"
5. If fetch fails (offline, auth error): warn and continue with local copy

**Intentional design:** Upstream-owned files are always overwritten, even if manually edited locally. Local customizations belong in `.scaffold/project/`, not in upstream-owned paths. No merge logic — this is deliberate to keep sync simple and predictable.

**Execution environment:** `sync.sh` runs under bash (Git Bash on Windows, native on macOS/Linux). This aligns with Claude Code's bash shell requirement.

**Update scope:**

| Path | Owner | Sync behavior |
|------|-------|---------------|
| `.scaffold/orchestration/` | Upstream | Always overwritten |
| `.scaffold/skills/` | Upstream | Always overwritten |
| `.scaffold/tools/` | Upstream | Always overwritten |
| `.scaffold/references/` | Upstream | Always overwritten |
| `.scaffold/rules/` | Upstream | Always overwritten |
| `.scaffold/project/` | Project | Never touched |
| `.scaffold/upstream.json` | System | Updated with new hash |

**Authentication:** Uses existing git credentials on the machine (SSH key, credential helper). No special mechanism.

---

## Planning & Milestone Orchestration

### Phase 1: Plan Initialization

Orchestrated by `plan-init.md`. Triggered when user says "init plan" or starts a new project.

1. Scan existing project files for context (READMEs, docs, code, config)
2. Generate `docs/plans/PLAN.md` using `PLAN-TEMPLATE.md`:
   - Project concept and goals
   - Constraints and assumptions
   - Architecture overview
   - Milestone breakdown with scope and acceptance criteria
3. Prompt the user for missing information — one question at a time
4. If the user skips questions, defer them — they'll be prompted when the relevant milestone is invoked
5. Break each milestone into `docs/plans/PLAN-M{n}.md` using `MILESTONE-TEMPLATE.md`
6. Generate `docs/plans/PLAN-OVERVIEW.md` — at-a-glance status of all milestones
7. Reflect architecture assumptions back into `docs/architecture.md`

### Phase 2: Milestone Implementation

Orchestrated by `milestone-run.md`. Triggered when a fresh agent is prompted: "Please read PLAN-M3.md. Implement this plan per the instructions in that file."

1. Read the milestone file, confirm scope and acceptance criteria
2. If plan-init questions were skipped for this milestone, prompt for them now
3. **Pre-implementation tool check:** Review `.scaffold/tools/manifest.json` — consider which tools are relevant to this milestone
4. Implement in the sequence defined in the milestone file
5. Run validation steps (tests, builds, type checks)
6. Trigger cross-agent review (Phase 3)
7. Update the milestone file with: validation steps performed, results, human-verifiable steps
8. Update `docs/plans/PLAN-OVERVIEW.md` status
9. Create/update documentation per the documentation lifecycle rules
10. Create ADRs for any architectural decisions made during implementation

### Phase 3: Cross-Agent Review

Orchestrated by `milestone-review.md`. Runs after implementation, before milestone is marked done.

Four review dimensions, each sent as a separate request to a second agent (Codex CLI preferred, structured prompt for manual paste as fallback):

1. **KISS** — Is this over-engineered? Simpler approaches available?
2. **Codebase Style** — Does this follow existing patterns and conventions?
3. **Correctness** — Bugs, edge cases, logic errors?
4. **Goal Fulfillment** — Does this achieve what the milestone defined?

**Review loop:**
- If the reviewer has objections, the implementing agent must address them
- Re-submit for review until approved or escalate to user
- Review results saved to `docs/reviews/M{n}-review.md`
- Review results also appended to the milestone file

**Codex CLI invocation:** `codex-review.sh` wraps the Codex CLI call with the structured prompt, passing the milestone file and relevant code as context.

### Phase 4: Better Engineering Review

Orchestrated by `better-engineering.md`. After milestone completion, the agent prompts: "Run better-engineering review?"

If accepted:

1. Both Claude and Codex independently assess better-engineering opportunities
2. A fresh instance of each cross-reviews the two assessments
3. Results presented to the user in `docs/reviews/M{n}-better-eng.md`
4. User decides which findings warrant sub-milestones
5. Sub-milestones created as `docs/plans/PLAN-M{n}-BE{k}.md`
6. `PLAN-OVERVIEW.md` updated with sub-milestone entries

---

## Skill/Tool/Reference Library

### Starter Skills

| Skill | File | Description | Platform |
|-------|------|-------------|----------|
| Session handoff | `handoff.md` | Write/read handoff state on session start/end | All |
| Self-update | `self-update.md` | Check scaffold repo for updates on session start | All |
| Plan init | `plan-init.md` | Initialize structured plan from project context | All |
| Milestone run | `milestone-run.md` | Implement a milestone per orchestration instructions | All |
| Milestone review | `milestone-review.md` | Four-dimension cross-agent review | All |
| Better engineering | `better-engineering.md` | Post-milestone architecture/quality review | All |
| Quota guard | `quota-guard.md` | Compute budget tiers with confirmation prompts | All |

### Starter Tools

| Tool | File | Description |
|------|------|-------------|
| Sync | `sync.sh` | Self-update script for fetching upstream changes |
| Codex review | `codex-review.sh` | Invoke Codex CLI with structured review prompt |
| Plan overview | `plan-overview-gen.sh` | Regenerate PLAN-OVERVIEW.md from milestone files |

### Starter References

| Reference | Description | Type |
|-----------|-------------|------|
| Context7 | Library documentation lookup | MCP |
| Claude Preview | Browser preview | MCP |
| Serena | Code intelligence | MCP |

### Discovery at Init

During project initialization, `apply-scaffold.ps1`:

1. Reads `runtime/tools/manifest.json` and `runtime/references/registry.json`
2. Makes assumptions based on detected stack (e.g., Python project gets pytest references)
3. Asks the user about uncertain tools ("API surface detected — include Serena?")
4. Writes active tool selection to `.scaffold/project/tool-config.json`

### Tool Activation Lifecycle

Tools move through three states: **available** (in manifest), **activated** (in tool-config.json), **in-use** (referenced in a milestone).

Activation happens at two points:

1. **Plan-init (coarse):** When the plan is built, the agent maps tools to milestones based on scope. Example: "M2 touches API endpoints — activating Serena for M2+." This mapping is written into `PLAN-OVERVIEW.md` as a tool-milestone matrix.
2. **Milestone start (refined):** Before implementation begins, the agent reviews the milestone scope against activated tools and confirms or adjusts. Tools can be activated or deactivated at this point based on how the project has evolved since plan-init.

### Tool Conflict Resolution

External tools (Serena, Context7, etc.) may have their own opinions about project structure or behavior that conflict with scaffold orchestration. Two flavors:

- **Structural conflicts:** Tool expects files in location X, scaffold puts them in location Y. Usually not a real conflict — different domains.
- **Behavioral conflicts:** Tool says "do X," scaffold orchestration says "do Y." Example: a tool suggests auto-refactoring, but milestone orchestration requires cross-agent review first.

Each tool entry in `manifest.json` includes a `conflicts` section:

```json
{
  "name": "serena",
  "conflicts": {
    "behavioral": [
      {
        "pattern": "auto-refactor",
        "resolution": "defer to milestone-review orchestration",
        "note": "Treat Serena refactor suggestions as recommendations, not actions, until reviewed"
      }
    ]
  },
  "scaffold_overrides": {
    "priority": "scaffold wins on orchestration, tool wins on code intelligence"
  }
}
```

When a tool is activated, the agent reads conflict declarations and applies resolution rules. The general principle: **scaffold wins on orchestration and process, tool wins on its domain expertise.**

For unpredictable conflicts (flip-flopping between tool recommendations and scaffold orchestration across milestones), the passive audit detects the pattern and flags it for the user to make a ruling, which becomes an ADR.

---

## Documentation Standards & Lifecycle

### Standard Document Structure

Every generated doc follows this format:

```markdown
# {Document Title}

## Table of Contents
- [Section 1](#section-1)
- [Section 2](#section-2)

## Metadata
- **Project:** {name}
- **Last Updated:** {date}
- **Status:** {status}

## {Content sections per template}
```

### Master Index

`docs/INDEX.md` serves as the master directory. Agents read this first before diving into individual files.

```markdown
# Documentation Index

| File | Purpose | Status | Last Updated |
|------|---------|--------|-------------|
| project-brief.md | Project concept and goals | Complete | 2026-03-22 |
| architecture.md | System boundaries and decisions | Active | 2026-03-22 |
| plans/PLAN.md | Master plan | Active | 2026-03-22 |
| ... | ... | ... | ... |
```

### Documentation Actions by Stage

| Stage | Required Documentation Action |
|-------|------------------------------|
| **Project init** | Generate `project-brief.md`, `architecture.md` skeleton, `INDEX.md`, create `decisions/` |
| **Plan init** | Populate `PLAN.md` and `PLAN-OVERVIEW.md`. Reflect architecture assumptions into `architecture.md`. Update `INDEX.md` |
| **Milestone start** | Read `architecture.md` and relevant ADRs. Note upfront if milestone will change architecture |
| **Milestone completion** | Update `PLAN-OVERVIEW.md`. Append validation results to milestone file. Create ADRs for decisions made. Update `INDEX.md` |
| **Cross-agent review** | Save output to `docs/reviews/M{n}-review.md`. Flag architectural concerns as ADR candidates. Update `INDEX.md` |
| **Better-engineering review** | Save to `docs/reviews/M{n}-better-eng.md`. Create sub-milestone files. Update `INDEX.md` |

### ADR Format

```markdown
# ADR-{NNN}: {Title}

**Status:** Proposed | Accepted | Superseded by ADR-{NNN}
**Date:** YYYY-MM-DD
**Context:** Why this decision was needed
**Decision:** What was decided
**Consequences:** What changes as a result
```

### Enforcement

Documentation is a milestone completion criterion. The orchestration instructions in each milestone file explicitly list which docs to create or update. A milestone is not done until its documentation actions are complete.

---

## Rule Segmentation

### Three Tiers

| Tier | Location in scaffold repo | Injected to | Sync behavior |
|------|--------------------------|-------------|---------------|
| **Universal** | `runtime/rules/always.md` | Every project | Always overwritten |
| **Stack-specific** | `runtime/rules/stacks/{stack}.md` | Matching projects | Always overwritten |
| **Project-owned** | N/A — lives in `.scaffold/project/` | Only that project | Never synced |

### Stack Rules

During init, `apply-scaffold` detects the project stack and copies relevant stack rule files. Stack rules cover: preferred test runners, build commands, linting conventions, common pitfalls. On sync, new upstream stack rules are pulled in automatically.

### Cross-Project Reference Catalog

`runtime/rules/catalog.md` — a flat index of project-specific rules that are interesting but not generalizable:

```markdown
| Rule | Project | Description |
|------|---------|-------------|
| api-restart | SpecRebuilder | Restart dev server after API endpoint changes |
| model-validation | pavilion | Validate 3D model integrity before processing |
```

**Promotion workflow:**
1. Discover useful rule in a project's `.scaffold/project/`
2. If generalizable → promote to `runtime/rules/stacks/{stack}.md` or `runtime/rules/always.md`
3. If interesting but specific → add reference to `catalog.md`
4. On next sync, all projects get the updated catalog

### Platform-Specific Rendering

Rules are written in platform-neutral format. During init/sync, rendered to:

- **Claude Code:** `CLAUDE.md` + `.claude/settings.json`
- **Codex:** `AGENTS.md`
- **Cursor/Windsurf:** `.agents/rules.md`

---

## Tool Auditing & Smart Prompting

### Passive Audit (Automatic)

After each milestone completes, before the better-engineering prompt:

1. Read `.scaffold/tools/manifest.json` and `.scaffold/references/registry.json`
2. Compare against tools actually used during the milestone
3. Self-check: were relevant tools overlooked?
4. Note recommendations in the milestone review file

This is not a user prompt — it's agent self-discipline embedded in `milestone-run.md`.

### Active Audit (On Command or Periodic)

Triggered by user request or every N milestones. The interval is configured in `.scaffold/project/tool-config.json` (default: 3 milestones). Produces a report:

```markdown
## Tool Audit — {project} — {date}

### Never Used
| Tool | Injected At | Recommendation |
|------|-------------|----------------|
| Serena | init | Remove — no code intelligence needed |

### Underutilized
| Tool | Last Used | Suggestion |
|------|-----------|------------|
| codex-review | M1 | Skipped in M2 and M3 |

### Heavily Used
| Tool | Frequency | Notes |
|------|-----------|-------|
| handoff | every session | Working as intended |

### Suggested Additions
| Tool | Why |
|------|-----|
| pytest-reference | 12 test files added since init |
```

### Usage Tracking

`.scaffold/project/usage-log.json` — append-only log updated at milestone boundaries:

```json
[
  {
    "milestone": "M1",
    "date": "2026-03-22",
    "used": ["handoff", "codex-review", "self-update"],
    "available": ["handoff", "codex-review", "self-update", "serena", "context7"]
  }
]
```

### Pre-Implementation Tool Check

Embedded in `milestone-run.md` as step 3: "Before starting work, review available tools in `.scaffold/tools/manifest.json`. Consider which are relevant to this milestone's scope."

---

## Future Features

### Approach C: Agent-Native Package Manager

Evolve the flat runtime directory into individually versioned packages. Projects declare dependencies in `scaffold.lock.json`. On session start, the agent resolves the lock file against the remote repo and pulls updates per-package. Maximum granularity — projects get exactly what they need.

**When to revisit:** When the number of skills/tools/references exceeds ~20, or when projects start needing significantly different subsets of the library.

### Documentation Format Optimization

Explore alternatives to plain Markdown for reducing context bloat and token usage:

- **Index files with summaries:** Machine-readable indexes that let agents skip reading full docs
- **Structured formats:** JSON/YAML for machine-consumed docs, Markdown for human-consumed
- **Hierarchical loading:** Agent reads index first, then only the sections it needs
- **Compression strategies:** Abbreviated reference formats vs. full prose
- **Section-level versioning:** Track which sections changed so agents only re-read updated parts

**When to revisit:** After measuring actual token usage across several projects with the current Markdown approach.
