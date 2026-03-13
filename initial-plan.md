# Initial Plan

## Goal

Build a reusable project scaffold that can be applied to both existing and new project folders, starting with this repository as the first consumer.

## Phase 1

- Establish a shared baseline folder structure.
- Create reusable template files with simple token replacement.
- Add an apply script that can target the current repo or another folder.
- Use the scaffold on this repo to prove the workflow.
- Add an evaluation-first workflow for existing projects with agent-rule capture and architecture inventory.

## Phase 2

- Add stack-specific template packs such as Node, Python, and docs-only.
- Support selective apply behavior for optional folders and files.
- Add migration mapping so an existing project can keep valid structure while adopting shared conventions.
- Introduce validation and smoke tests for generated output.

## Phase 3

- Add upgrade support for existing projects with change reporting.
- Define ownership rules for scaffold-managed files.
- Generate architecture context packs that summarize endpoints, entry points, modules, and dependencies.
- Publish the scaffold as a starter repo or internal tool.

## Current Decisions

- Start with a common, language-agnostic baseline.
- Prefer safe defaults and avoid overwriting existing files unless explicitly forced.
- Keep the first version transparent and file-based instead of adding heavy tooling.
- Treat existing agent rules, plans, and architecture as migration inputs, not files to overwrite.
- Separate evaluation from application so we can safely handle complex repos.
