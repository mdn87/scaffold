# Session Handoff Skill

## Purpose

Maintain session continuity across agent sessions. Write a structured handoff file at session end, read it at session start.

## When to Run

- **Session start:** Check for existing handoff file and summarize where things left off
- **Session end:** Write handoff state when user signals completion

## Session Start Instructions

1. Check if `.scaffold/project/handoff.md` exists in the project root
2. If it exists and `last_updated` is within 7 days: greet with a one-line summary of where things left off, then proceed
3. If older than 7 days: mention it's stale and ask what to focus on
4. If no file: proceed normally

## Session End Instructions

When the user says "done", "wrap up", "end session", "that's it", or a major milestone completes:

1. If `.scaffold/project/handoff.md` exists, copy it to `.scaffold/project/handoff-history/handoff-{YYYYMMDD-HHmmss}.md` (create dir if needed)
2. Write a new `.scaffold/project/handoff.md` (keep under 40 lines):

```markdown
last_updated: YYYY-MM-DD HH:MM
session_summary: {one sentence}

## What Was Done
- {bullets}

## Current State
{brief description}

## Next Up
- {next steps from PLAN-OVERVIEW.md if available}

## Gotchas
- {watch out for these}
```

3. If a git repo, ensure `.scaffold/project/handoff.md` and `.scaffold/project/handoff-history/` are in `.gitignore`

## Important

- Do NOT read or write the handoff file mid-session — only at start and end
- Reference PLAN-OVERVIEW.md for "Next Up" if a plan exists
- Keep the handoff concise — it's for the next agent session, not a full report
