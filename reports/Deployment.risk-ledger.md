# Risk Ledger: Deployment

- Target: C:\Users\mnewman\Documents\Admin\IT\EngineerToolkit\Deployment
- Generated: 2026-03-17 15:30:02
- Based on: Deployment.architecture-context.json, Deployment.migration-map.json, 

## Current Pass Risk

- Current scaffold pass breakage risk: low
- Rationale: The completed scaffold work generated analysis artifacts and skipped baseline application for the mapped project, so runtime code paths were not modified.

## Next Change Risk

- Future structural refactor: high
- Future endpoint refactor: high
- Future rule consolidation: medium

## Risk Areas

### Word COM analysis and document mutation

- Level: high
- Likelihood: medium
- Impact: high
- Reason: Core functionality depends on Word COM behavior, visible numbering extraction, and document mutation that can fail in non-obvious ways.
- Common triggers:
- Changes to COM interop calls or Word lifecycle management
- Changes to paragraph analysis or numbering rebuild logic
- Changes to file open/save/export flows
- Safeguards:
- Validate against real documents, not only synthetic samples
- Keep manual review path intact
- Treat COM cleanup and error handling as regression-sensitive
### API registration and request routing

- Level: high
- Likelihood: medium
- Impact: high
- Reason: The app uses both MVC controller routing and Minimal API registration, so moving or consolidating endpoints can easily break assumptions in hosting or route resolution.
- Common triggers:
- Moving endpoints between StyleApiController and VisualizerApi
- Changing route prefixes or HTTP methods
- Refactoring CreateApiApp registration order
- Safeguards:
- Preserve current route surface until explicit tests exist
- Document endpoint ownership before refactors
- Verify static files and API routes together after changes
### File I/O and project-root-relative storage

- Level: high
- Likelihood: high
- Impact: high
- Reason: Templates, playgrounds, stylegroups, exports, and ready-folder data all rely on path logic and persistent files; path changes can break multiple workflows at once.
- Common triggers:
- Changing folder names or root-relative path calculations
- Moving templates, exports, or stylegroup storage
- Changing bin-folder fallback behavior
- Safeguards:
- Make path changes behind a single abstraction
- Smoke test template, export, and stylegroup flows after edits
- Prefer additive config over implicit path rewrites
### Background analysis jobs and in-memory state

- Level: medium
- Likelihood: medium
- Impact: high
- Reason: The analysis pipeline uses in-memory job tracking, so concurrency or lifecycle changes can silently break polling, retries, or restart behavior.
- Common triggers:
- Changing Task.Run job execution
- Replacing or mutating the ConcurrentDictionary job store
- Adding restart persistence without explicit design
- Safeguards:
- Keep job state transitions explicit
- Test analyze -> poll -> export sequence end to end
- Treat persistence changes as architecture work, not cleanup
### Agent rules and operational workflow

- Level: medium
- Likelihood: low
- Impact: medium
- Reason: Rule files do not change runtime behavior directly, but changing or merging them can degrade future maintenance quality and verification discipline.
- Common triggers:
- Merging .agent and .agents content without classification
- Dropping known build-error exclusions
- Ignoring API host restart guidance
- Safeguards:
- Preserve current rules until a deliberate consolidation pass
- Keep pre-existing error exclusions explicit
- Treat rule changes as operational changes with review
### Scaffold-managed documentation and reports

- Level: low
- Likelihood: low
- Impact: low
- Reason: Generated reports and docs mostly affect understanding, not execution, unless they are later used to justify incorrect code changes.
- Common triggers:
- Overwriting project-owned docs blindly
- Assuming generated reports are perfectly accurate
- Using reports as code-change authority without verification
- Safeguards:
- Keep generated artifacts separate from runtime code
- Verify claims against source before refactors
- Prefer additive docs over replacing repo docs

## Recommended Sequencing

- Refine interface ownership and tests before endpoint refactors.
- Abstract file path handling before moving storage locations.
- Consolidate agent rules only after preserve/merge classification.
- Treat COM-analysis changes as highest-regression work.
