---
trigger: always_on
---

# scaffold Agent Rules

## Project Context

- **Type**: .NET application with API/web surface
- **Root**: `/Users/matthewnewman/Documents/MyCode/scaffold`
- **Primary language**: C# / .NET
- **Derivation mode**: project-docs

## Purpose

This repository is a reusable scaffold for bootstrapping and standardizing projects.

## Rule Source

This rule set was derived from existing project markdown plus detected manifests and structure.

## Source Docs

- /README.md
- /scaffold/templates/common/README.md
- /initial-plan.md
- /docs/architecture.md
- /reports/codelink.architecture-context.md
- /reports/ollama.architecture-context.md
- /reports/pavilion.architecture-context.md
- /reports/SpecRebuilder_v0.2.architecture-context.md
- /reports/SpecRebuilder_v0.2.interface-map.md
- /reports/SpecRebuilder_v0.2.inventory.md

## Code Inference Sources

- /reports/cli.inventory.json
- /reports/cli.migration-map.json
- /reports/codelink.architecture-context.json
- /reports/codelink.inventory.json
- /reports/codelink.migration-map.json
- /reports/codelink.risk-ledger.json
- /reports/ollama.architecture-context.json
- /reports/ollama.inventory.json
- /reports/ollama.migration-map.json
- /reports/ollama.risk-ledger.json
- /reports/pavilion.architecture-context.json
- /reports/pavilion.inventory.json

## Local Git Signals

- GitHub remote configured locally
- Repository name: scaffold
- Remote: https://github.com/mdn87/scaffold.git

## Remote GitHub Signals

- None detected

## Detected Stack Hints

- dotnet

## Detected Manifests

- None detected

## Workflow Hints

- `.agent\rules\always-approve-whitelisted-commands.md`
- `.agent\rules\quota-drain-prevention.md`
- `.agent\rules\restart-api-host-as-needed.md`
- `.agents\always-approve-whitelisted-commands.md`
- `docs/` for architecture notes and decisions
- `scripts/apply-scaffold.ps1` for safe baseline application
- `scripts/generate-architecture-context.ps1` for project-level subsystem and rule context
- `scripts/generate-migration-map.ps1` for migration decisions plus a safe first implementation slice when richer reports exist
- Command-line entry point or utility workflow

## External Systems / Runtime Notes

- .NET desktop application workflow
- API or routed interface surface
- Packaged artifact generation/import workflow

## Safe Auto-Run Whitelist

Set safe autorun for the following commands when they match the current workspace and request:

- bash
- brew info
- brew list
- cat
- curl
- dotnet build
- dotnet format --verify-no-changes
- dotnet list package
- dotnet restore
- dotnet run --api
- dotnet test
- dotnet tool list
- echo
- env
- Get-ChildItem
- Get-Content
- gh auth
- gh issue
- gh pr
- gh repo
- git add
- git branch
- git clone
- git commit
- git config
- git diff
- git fetch
- git init
- git log --oneline
- git ls-tree
- git merge
- git pull
- git push
- git rebase --continue
- git remote
- git restore --staged
- git status
- git submodule
- git switch
- git worktree
- ls
- ls -la
- pwsh -File scripts/apply-scaffold.ps1
- pwsh -File scripts/generate-architecture-context.ps1
- pwsh -File scripts/generate-migration-map.ps1
- Select-String
- sh
- which

Non-destructive project-scoped execution may autorun when it matches the allowlist above. Destructive commands remain excluded even when related command families are otherwise allowed.

## Operating Defaults

- Prefer small, reviewable changes.
- Preserve project-owned rules and conventions before applying scaffold defaults.
- Match existing path and runtime conventions instead of forcing a new layout mid-change.
- Treat project docs such as README.md, plan files, and architecture notes as authoritative inputs for future updates to .agents.
- If docs are missing, use entry points, filenames, comments, and local Git metadata as fallback signals before defaulting to generic rules.
- Remote GitHub enrichment is best-effort only and must never block scaffold application.

## Quota / Compute Rules

### Default: LOW COMPUTE

- Only analyze the minimum necessary code.
- Avoid workspace-wide scans unless the user explicitly asks for deeper analysis.
- Reuse existing reports and context before re-reading large files.

### HIGH COMPUTE triggers (ask first)

Respond with: "Estimated quota impact: HIGH. Proceed? (yes/no)" before:
- Reading many files
- Generating multi-phase plans
- Deep debugging across multiple modules
- Running workspace-wide searches

### ULTRA COMPUTE triggers (ask first)

Respond with: "Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)" before:
- Full codebase analysis
- Large refactors across multiple files
- Architectural redesign

## API Host Rule

Remember to restart the API host or local dev server if route, handler, or API-facing changes need to be reflected live.

