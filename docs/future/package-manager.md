# Future: Agent-Native Package Manager (Approach C)

## Table of Contents
- [Concept](#concept)
- [When to Revisit](#when-to-revisit)
- [Sketch](#sketch)

## Metadata
- **Project:** scaffold
- **Date:** 2026-03-22
- **Status:** Future exploration

## Concept

Evolve the flat `runtime/` directory into individually versioned packages. Each skill, tool, and reference becomes a discrete package with its own version. Projects declare dependencies in a `scaffold.lock.json` file. On session start, the agent resolves the lock file against the remote repo and pulls updates per-package rather than syncing the entire runtime directory.

**Advantages over current approach:**
- Maximum granularity — projects get exactly what they need
- Clean dependency tracking between skills/tools
- Per-package changelogs
- Ability to pin versions per-project while other projects advance

**Disadvantages:**
- Significantly more complex to build and maintain
- Package resolution logic becomes its own maintenance burden
- Over-engineered at current scale (~6 active projects)

## When to Revisit

- Number of skills/tools/references exceeds ~20
- Projects start needing significantly different subsets of the library
- Version conflicts become a real problem (one project needs old behavior, another needs new)

## Sketch

```
runtime/
├── packages/
│   ├── handoff/
│   │   ├── package.json       # name, version, dependencies
│   │   └── handoff.md
│   ├── milestone-run/
│   │   ├── package.json
│   │   └── milestone-run.md
│   └── ...
└── resolver.sh                # resolves scaffold.lock.json against packages/

# In target project:
.scaffold/
├── scaffold.lock.json         # pinned versions per-package
└── packages/                  # resolved packages
```
