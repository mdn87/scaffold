# Serena MCP Server Setup — Claude Code Prompt

**Target:** Claude Code
**Source:** https://github.com/oraios/serena

---

## Starting State
Windows 11, bash shell. Claude Code is installed and active. `uv` may or may not be installed. No Serena MCP server configured yet.

## Target State
Serena MCP server registered in Claude Code (user scope) and verified working. A `.serena/project.yml` initialized in the current project directory.

## Steps — execute in order

**Step 1 — Verify uv is installed**
Run: `where uvx`
- If found: note the full path, continue to Step 2
- If not found: run `winget install astral-sh.uv`, then restart the shell and verify again

✅ Output: "uvx found at [path]" or "uv installed successfully"

**Step 2 — Register Serena as a user-scope MCP server**
Run:
```
claude mcp add --scope user serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context=claude-code --project-from-cwd
```
If `uvx` is not on PATH in the Claude Code process, replace `uvx` with the full path found in Step 1 (forward slashes).

✅ Output: "Serena MCP server registered"

**Step 3 — Initialize project**
From the current project directory, run:
```
uvx --from git+https://github.com/oraios/serena serena project create
```
This creates `.serena/project.yml`. Do not edit any existing project source files.

✅ Output: ".serena/project.yml created"

**Step 4 — Index the project**
Run:
```
uvx --from git+https://github.com/oraios/serena serena project index
```

✅ Output: "Project indexed"

**Step 5 — Verify MCP registration**
Run: `claude mcp list`
Confirm `serena` appears in the output.

✅ Output: "serena confirmed in MCP server list"

## Constraints
- Only modify `.serena/` within the current project directory
- Do NOT touch any project source files
- Do NOT install any global packages other than `uv` via winget
- Do NOT overwrite an existing `serena` MCP entry — stop and report if one already exists

## Stop and ask before
- Modifying `~/.claude/settings.json` directly
- Removing or replacing any existing MCP server entry
- Running any command that writes outside the current project directory

## On completion
Report the full path to `.serena/project.yml` and confirm Serena appears in `claude mcp list`.
