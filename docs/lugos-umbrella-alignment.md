# Lugos Umbrella Alignment

## Purpose

This note defines how `scaffold` should align Lugos-family repositories without becoming a second
source of architecture policy.

## Canonical Policy

For Lugos, umbrella-level architecture and code-intelligence boundaries belong in the superproject
docs, not in `scaffold`.

Use the Lugos root as the source of truth:

- `docs/architecture.md`
- `docs/code-intelligence-baseline.md`
- `docs/decisions/2026-04-09-code-intelligence-baseline.md`

If `scaffold` guidance conflicts with those files, the Lugos root docs win.

## What Scaffold Should Do

- Help new submodules align to the umbrella policy after bootstrap or during migration.
- Point generated docs, prompts, and operator instructions back to the canonical Lugos root docs.
- Preserve module-local structure and conventions while keeping them compatible with umbrella
  boundaries.
- Restate policy only when a generated artifact needs a short local reminder, and keep that
  reminder explicitly subordinate to the umbrella docs.

## What Scaffold Should Not Do

- It should not define a separate Lugos architecture policy.
- It should not imply that `lugos-mcp` is the default lane for routine code navigation or symbol
  lookup.
- It should not assume a Serena-backed or `code.*` MCP surface is part of the default Lugos
  baseline.

## Lugos Boundary Reminder

The current Lugos default is editor-local LSP, repo search, linting, and type checking for routine
code intelligence. `lugos-mcp` remains for services, workflows, media, and lightweight memory, not
as the default code-browsing surface.

## Follow-Up Audit Targets

When updating `scaffold`, review templates, prompts, and docs that may still imply older
assumptions about Serena or MCP-based code navigation. Prefer changing those materials to reference
the umbrella policy instead of re-explaining it in full.
