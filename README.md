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
- `scripts/generate-migration-map.ps1` for the next artifact after inventory
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

Evaluate an existing project before applying structure changes:

```powershell
.\scripts\inventory-project.ps1 -TargetPath C:\mn\cli
```

```powershell
.\scripts\generate-migration-map.ps1 -TargetPath C:\mn\cli
```

Run the repeatable command against any target:

```powershell
.\scripts\invoke-scaffold.ps1 -TargetPath C:\mn\cli -Action activate
```

Actions:

- `inventory` generates reports only
- `apply` applies the baseline directly
- `activate` generates inventory, builds the migration map, and then applies only when the recommendation is `adopt`

Artifacts generated in `reports/`:

- `*.inventory.json`
- `*.inventory.md`
- `*.migration-map.json`
- `*.migration-map.md`

## What Gets Added

- `.editorconfig`
- `.gitignore`
- `README.md` if missing
- `docs/architecture.md`
- `docs/decisions/`
- `src/`
- `tests/`
- `scaffold.config.json`

## Migration Strategy

For existing projects, the scaffold should not assume the target repo wants the same folder layout as a new project.

Instead, use this sequence:

1. Inventory the current project shape, rules, plans, dependencies, and interface surface.
2. Preserve project-specific rules as first-class inputs.
3. Compare the current structure against the baseline scaffold.
4. Generate recommendations for adopt, map, keep, or split decisions rather than forcing a rewrite.
5. Apply only the scaffold-managed parts that improve the repo without breaking its architecture.

See `docs/migration-evaluation.md` for the evaluation model.

## Next Steps

- Add additional template packs for specific stacks.
- Expand the manifest to support optional components and migration mappings.
- Add tests around scaffold application behavior.
