# Serena MCP Server - Future Reference

Status: Deferred for Lugos by default. Keep this as future reference only, not as part of the
default host or MCP baseline.

For Lugos-family repos, the umbrella policy keeps routine code intelligence editor-local, with repo
search and local LSP as the default lane. See:

- `../../../docs/code-intelligence-baseline.md`
- `../../../docs/decisions/2026-04-09-code-intelligence-baseline.md`
- `../lugos-umbrella-alignment.md`

Use this note only if a future project explicitly opts into Serena for semantic navigation and the
project can host the required `uv`/`uvx` process locally.

## If Serena Is Revisited

- Treat it as an opt-in project-specific tool, not scaffold default behavior.
- Prefer local editor tooling and repo search for ordinary navigation, symbol lookup, and
  diagnostics.
- Add any Serena setup steps to the project-specific adoption flow, not to the umbrella policy
  docs.
