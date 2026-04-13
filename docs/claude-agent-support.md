# Claude Code Agent Support

## Overview

Scaffold generates two parallel sets of agent context files:

| Output | Used by |
|---|---|
| `.agents/rules.md`, `.agents/always-approve-whitelisted-commands.md`, etc. | Generic AGENTS.md-compatible agents (Windsurf, Cursor, etc.) |
| `CLAUDE.md`, `.claude/settings.json` | Claude Code (Anthropic CLI) |

Both are generated from the same project signals on every `apply-scaffold.ps1` run. Neither takes precedence — they coexist so the project works correctly regardless of which AI tool opens it.

---

## Key Differences

### 1. File location and loading

**AGENTS.md convention** — agents look for `.agents/rules.md` or `AGENTS.md` at a configured path. The `trigger: always_on` frontmatter tells the agent runtime to load the file unconditionally.

**Claude Code** — reads `CLAUDE.md` from the project root (and any parent directories up to `~`). No frontmatter is needed or parsed; the file is always loaded when present.

### 2. Permissions / command whitelist

**AGENTS.md convention** — `.agents/always-approve-whitelisted-commands.md` is a markdown hint read by the agent as instructions. The agent interprets and follows the list, but there is no machine-enforced allow-list.

**Claude Code** — `.claude/settings.json` is a machine-readable configuration file. The `permissions.allow` array enforces which Bash commands Claude will run without asking for confirmation. Entries use the format `Bash(prefix:*)`, where everything after the prefix is a wildcard.

Example entry:
```json
"Bash(git status:*)"
```
This allows `git status`, `git status --short`, etc., but not `git reset`.

### 3. Tool names

The `.agents/` files use generic language ("the agent", "the assistant"). `CLAUDE.md` uses Claude Code's specific tool names:

| Action | Claude tool |
|---|---|
| Read a file | `Read` |
| Search file content | `Grep` |
| Find files by pattern | `Glob` |
| Run a shell command | `Bash` |
| Edit a file | `Edit` |
| Create/overwrite a file | `Write` |

`CLAUDE.md` instructs Claude to prefer these dedicated tools over Bash equivalents (e.g., use `Read` not `cat`, use `Grep` not `grep`).

### 4. Filtered commands

PowerShell cmdlets (`Get-ChildItem`, `Get-Content`, `Select-String`, etc.) appear in `.agents/always-approve-whitelisted-commands.md` because some agents run in PowerShell environments.

They are **excluded** from `.claude/settings.json` because Claude Code's `Bash` tool runs in the user's shell (zsh/bash on macOS/Linux, cmd/PowerShell on Windows) and the permission format is shell-command-based. PowerShell cmdlets would never appear as `Bash(...)` entries.

Bare shell interpreters (`bash`, `sh`, `zsh`) are also excluded from `.claude/settings.json` — they are too broad and would effectively grant unrestricted execution.

---

## Generated Files

### `CLAUDE.md`

Written to the project root. Contains:

- Project type, stack, root path
- Purpose (derived from project docs or code inference)
- Key commands detected from docs and manifests
- Claude-specific operating rules
- Compute budget / quota escalation prompts
- Reference to `.claude/settings.json` for permissions

### `.claude/settings.json`

Written to `.claude/settings.json` at the project root. Contains a `permissions.allow` array of `Bash(prefix:*)` entries derived from the same whitelist used to generate `.agents/always-approve-whitelisted-commands.md`, after filtering out PS-only and overly broad commands.

---

## Overwrite Behavior

Both Claude files follow the same overwrite logic as `.agents/` files:

- **First run**: always written
- **Subsequent runs**: skipped unless `-Force` is passed or the existing rule state is scaffold-managed (`scaffold-direct` or `scaffold-sidecar`)
- **Project-owned rules present**: written to `.agents/scaffold-generated/` sidecar path; `CLAUDE.md` and `.claude/settings.json` are still written to the project root but skipped if they exist and `-Force` is not set

---

## Regenerating

To regenerate all agent files (including Claude output) from current project signals:

```powershell
pwsh scripts/apply-scaffold.ps1 -TargetPath /path/to/project -Force
```

The `-Force` flag overwrites all scaffold-managed files. Project-owned `.agents/` files are preserved.
