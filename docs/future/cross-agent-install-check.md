# Future: Cross-Agent Installation Check at Initialization

## Table of Contents
- [Concept](#concept)
- [When to Revisit](#when-to-revisit)

## Metadata
- **Project:** scaffold
- **Date:** 2026-03-22
- **Status:** Future exploration

## Concept

During project initialization, scaffold should detect which agent platforms are installed on the machine (Claude Code, Codex CLI, Cursor, Windsurf, Gemini CLI, etc.) and verify their setup is correct. This includes:

- Checking if the CLI tools are available in PATH
- Verifying authentication/credentials are configured
- Confirming compatible versions are installed
- Detecting MCP server availability for tools referenced in the registry
- Generating platform-specific config files only for agents that are actually installed
- Warning if a tool in the manifest requires an agent that isn't present (e.g., codex-review.sh requires Codex CLI)

This would replace the current assumption that the user knows what's installed and let the scaffold make smarter decisions about which tools to activate and which platform renderings to generate.

## When to Revisit

After the initial runtime implementation is stable and being used across multiple projects. The need will become clearer once tool activation and platform rendering are in practice.
