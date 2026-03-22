# Claude Code Platform Rules

## File Targets

- Agent rules → `CLAUDE.md` (project root)
- Command permissions → `.claude/settings.json`

## CLAUDE.md Structure

The generated CLAUDE.md should follow this structure:

- Project section: type, stack, root path
- Purpose: from project-brief.md
- Key Commands: from stack rules safe commands
- Workflow Notes: from scaffold orchestration
- Operating Rules: from rules/always.md, filtered for Claude Code
- Compute Budget: from rules/always.md compute budget section

## settings.json Structure

Permissions use the format: `"Bash({command}:*)"` for prefix-based wildcarding.

## Rendering Notes

- Exclude PowerShell cmdlets — Claude Code uses bash
- Use `Bash(prefix:*)` wildcard format for command permissions
- Include scaffold-specific workflow notes referencing `.scaffold/` paths
