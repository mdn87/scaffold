# Future: Documentation Format Optimization

## Table of Contents
- [Problem](#problem)
- [When to Revisit](#when-to-revisit)
- [Areas to Explore](#areas-to-explore)

## Metadata
- **Project:** scaffold
- **Date:** 2026-03-22
- **Status:** Future exploration

## Problem

Plain Markdown is human-readable but token-expensive for AI agents. When agents read project documentation for context, they consume tokens on prose, formatting, and sections that aren't relevant to their current task. At scale (many docs, many milestones, many projects), this becomes a meaningful cost and context-window pressure.

## When to Revisit

After measuring actual token usage across several projects using the current Markdown-based approach. Key signals:
- Agents frequently hitting context limits during milestone work
- Significant token spend on doc reading vs. actual implementation
- Projects accumulating enough documentation that full reads become impractical

## Areas to Explore

### Index files with summaries
Machine-readable index files that let agents decide which docs (or sections) to read without loading everything. A structured summary per doc that answers: what is this, when was it last updated, what topics does it cover.

### Structured formats for machine consumption
JSON or YAML for docs whose primary audience is AI agents (plans, milestone files, tool manifests). Keep Markdown for docs humans will read (architecture decisions, review outputs).

### Hierarchical loading
Agent reads the index first, identifies relevant sections, then reads only those sections. Requires docs to be structured with clear section boundaries and stable heading anchors.

### Compression strategies
Abbreviated reference formats for context injection vs. full prose for authoring. Example: a milestone file could have a "compressed context" section at the top with key facts in terse format, and full detail below.

### Section-level versioning
Track which sections of a doc changed since the agent last read it. On subsequent reads, the agent can skip unchanged sections. Requires a lightweight diffing mechanism — possibly a hash per section stored in the index.
