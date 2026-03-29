# scaffold

## Project

- **Type**: .NET application with API/web surface
- **Stack**: dotnet
- **Root**: `/Users/matthewnewman/Documents/MyCode/scaffold`

## Purpose

This repository is a reusable scaffold for bootstrapping and standardizing projects.

## Key Commands

- dotnet run --api

## Workflow Notes

- `.agent\rules\always-approve-whitelisted-commands.md`
- `.agent\rules\quota-drain-prevention.md`
- `.agent\rules\restart-api-host-as-needed.md`
- `.agents\always-approve-whitelisted-commands.md`
- `docs/` for architecture notes and decisions
- `scripts/apply-scaffold.ps1` for safe baseline application
- `scripts/generate-architecture-context.ps1` for project-level subsystem and rule context
- `scripts/generate-migration-map.ps1` for migration decisions plus a safe first implementation slice when richer reports exist
- Command-line entry point or utility workflow

## Operating Rules

- Use the Read tool to read files — do not use `cat` or `head` via Bash.
- Search with Grep and Glob tools, not `grep` or `find` via Bash.
- Use the Edit tool for targeted changes; Write only for new files or full rewrites.
- Read and understand existing code before suggesting modifications.
- Prefer small, reviewable changes over large rewrites.
- Match existing path, naming, and runtime conventions.
- Treat README.md, plan files, and architecture docs as authoritative project context.
- Do not add features, comments, or error handling beyond what was asked.

## Compute Budget

### Default: LOW

- Read only the files necessary for the task.
- Reuse loaded context before fetching more.
- Do not scan the whole workspace unless explicitly asked.

### HIGH — confirm first

Say: `Estimated quota impact: HIGH. Proceed? (yes/no)` before:

- Reading many files across the project
- Running broad workspace searches
- Generating multi-step plans

### ULTRA — confirm first

Say: `Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)` before:

- Full codebase analysis
- Large refactors spanning many files
- Architectural redesign

## Permissions

Safe auto-run commands are configured in `.claude/settings.json`. Normal project-scoped execution may autorun for listed non-destructive commands, including trusted Git, GitHub CLI, and repo script operations. Destructive commands remain explicitly denied.

