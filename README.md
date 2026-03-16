# Project Scaffold

This repository is a reusable scaffold for bootstrapping and standardizing projects.

It supports three use cases:

1. Applying a consistent baseline to an existing project folder.
2. Starting a new project from a known structure.
3. Evaluating an existing project before deciding what the scaffold should change.

The scaffold source lives in `scaffold/templates/common`.

The current entry points are:

- `scripts/apply-scaffold.ps1` for safe baseline application
- `scripts/inventory-project.ps1` for evaluation-first migration analysis
- `scripts/generate-migration-map.ps1` for migration decisions plus a safe first implementation slice when richer reports exist
- `scripts/generate-architecture-context.ps1` for project-level subsystem and rule context
- `scripts/generate-risk-ledger.ps1` for change-risk hotspots and sequencing guidance
- `scripts/invoke-scaffold.ps1` for the repeatable end-to-end command

## Quick Start

Apply the scaffold to the current folder:

```powershell
.\scripts\apply-scaffold.ps1
```

Apply the scaffold to another folder:

```powershell
.\scripts\apply-scaffold.ps1 -TargetPath C:\path\to\project -ProjectName MyProject
```

Use `-Force` to overwrite scaffold-managed files.
Use `-UseRemoteGitHubContext` to attempt optional GitHub enrichment from the configured `origin` remote. If the remote is missing or unreachable, the scaffold continues with local-only inference.

Evaluate an existing project before applying structure changes:

```powershell
.\scripts\inventory-project.ps1 -TargetPath C:\mn\cli
```

```powershell
.\scripts\generate-migration-map.ps1 -TargetPath C:\mn\cli
```

```powershell
.\scripts\generate-architecture-context.ps1 -TargetPath C:\mn\cli
```

```powershell
.\scripts\generate-risk-ledger.ps1 -TargetPath C:\mn\cli
```

Run the repeatable command against any target:

```powershell
.\scripts\invoke-scaffold.ps1 -TargetPath C:\mn\cli -Action activate
```

Actions:

- `inventory` generates reports only
- `apply` applies the baseline directly
- `activate` generates inventory, migration map, architecture context, and risk ledger, then applies only when the recommendation is `adopt`

Artifacts generated in `reports/`:

- `*.inventory.json`
- `*.inventory.md`
- `*.migration-map.json`
- `*.migration-map.md`
- `*.architecture-context.json`
- `*.architecture-context.md`
- `*.risk-ledger.json`
- `*.risk-ledger.md`

## What Gets Added

- `.editorconfig`
- `.gitignore`
- `README.md` if missing
- `docs/architecture.md`
- `docs/decisions/`
- `src/`
- `tests/`
- smart `.agents/` guidance derived from project docs, manifests, structure, and optional remote GitHub metadata
- `scaffold.config.json`

For existing repos without agent rules, scaffold now derives `.agents/` from markdown files like `README.md`, `plan*.md`, and architecture docs when they exist. If those docs are missing, it falls back to lightweight entry-point, filename, comment, and local Git remote inference before using the generic baseline for effectively blank projects.

With `-UseRemoteGitHubContext`, scaffold will also attempt to read lightweight GitHub repo metadata and README context from the configured `origin` remote. This path is best-effort and must fail gracefully.

For repos that already own `.agent` or `.agents` rules, scaffold-generated guidance is written to `.agents/scaffold-generated/` unless `-Force` is used.

## Migration Strategy

For existing projects, the scaffold should not assume the target repo wants the same folder layout as a new project.

Instead, use this sequence:

1. Inventory the current project shape, rules, plans, dependencies, and interface surface.
2. Preserve project-specific rules as first-class inputs.
3. Compare the current structure against the baseline scaffold.
4. Generate recommendations for adopt, map, keep, or split decisions rather than forcing a rewrite.
5. Use the migration map, architecture context, and risk ledger together to identify the safest first implementation slice.
6. Apply only the scaffold-managed parts that improve the repo without breaking its architecture.

See `docs/migration-evaluation.md` for the evaluation model.

## Next Steps

- Add additional template packs for specific stacks.
- Expand the manifest to support optional components and migration mappings.
- Add tests around scaffold application behavior.
