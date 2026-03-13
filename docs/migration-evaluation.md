# Migration Evaluation

## Why This Exists

A reusable scaffold cannot assume every existing project should be reshaped into the same directory tree.

Some repos already encode valuable architecture decisions:

- agent rules
- implementation plans
- backend endpoints
- frontend assets
- dependency manifests
- operational scripts

Those should be evaluated first and then mapped into the scaffold with intention.

## Core Principle

The scaffold should standardize the project context layer before it standardizes the code layout.

That means we prioritize:

1. Rules
2. Architecture
3. Interfaces
4. Dependencies
5. Folder alignment

## Evaluation Outputs

Each project evaluation should produce:

- A project inventory report
- A detected rules summary
- A structure comparison against the scaffold baseline
- A migration recommendation set
- A context pack for future agents and contributors

## Rule Handling

Existing rules should be classified as:

- `preserve`: project-specific operational rules that must remain authoritative
- `merge`: reusable guidance that belongs in the scaffold baseline
- `replace`: outdated or conflicting rules that should be superseded
- `derive`: rules that should be regenerated from the evaluated architecture

## Structure Handling

A structural mismatch is not automatically a problem.

Examples:

- A Python CLI may already fit the baseline closely.
- A WinForms plus API hybrid may need a custom map instead of a folder move.
- A project may keep root-level files for valid runtime or solution reasons.

## Interface Capture

For migration planning, "architecture" should include the runnable surface of the project:

- backend endpoints and controllers
- frontend assets and host files
- entry points
- background jobs
- exported artifacts
- config files and registries

## Migration Decisions

Each evaluated area should land in one of four buckets:

- `adopt`: use the scaffold baseline directly
- `map`: keep the project shape but map it to scaffold concepts
- `keep`: preserve as-is because it is project-correct
- `split`: extract a reusable pattern into the scaffold while leaving project-specific implementation in place

## Suggested Workflow

1. Run `scripts/inventory-project.ps1` against the target project.
2. Review rules, manifests, and detected interfaces.
3. Decide which scaffold pack fits best: common, python, dotnet-desktop, hybrid, or custom.
4. Write a migration map before changing files.
5. Apply only scaffold-managed files and agreed structure changes.
6. Record the result in `scaffold.config.json` or a project-specific migration file.

## Real Examples

### `C:\mn\cli`

- Likely `adopt` or light `map`
- Already has `docs/`, `src/`, `tests/`, `pyproject.toml`
- Main value is adding shared conventions and project rules

### `SpecRebuilder_v0.2`

- Likely `map`, `keep`, and `split`
- Contains desktop UI, API endpoints, static assets, plans, rules, and registries
- Main value is preserving architecture while generating better context and ownership boundaries
