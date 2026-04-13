# Architecture Context: Deployment

- Target: C:\Users\mnewman\Documents\Admin\IT\EngineerToolkit\Deployment
- Generated: 2026-03-17 15:30:02
- Based on: Deployment.inventory.json, Deployment.migration-map.json
- Project kind: General project
- Purpose: First-pass architecture context generated from scaffold inventory and migration map.
- Scaffold recommendation: adopt

## Scaffold Stance

- Rules: preserve
- Structure: adopt
- Interfaces: adopt
- Dependencies: adopt

## Core Subsystems

- None

## Authoritative Rule Files

- `.agents\always-approve-whitelisted-commands.md` -> preserve
- `.agents\quota-drain-prevention.md` -> preserve
- `.agents\restart-api-host-as-needed.md` -> preserve
- `.agents\rules.md` -> preserve

## Rule Highlights

- Honor low-compute defaults unless the user explicitly asks for deeper analysis.
- Restart the API host when changes need to be reflected in the visualizer/API layer.

## Manifests

- None

## Baseline Mapping

Map into scaffold concepts:
- None

Keep as project-owned:
- None

## Interface Groups

- None

## Next Artifacts

- Rule classification report consolidating .agent and .agents guidance.
- Explicit interface map with grouped endpoints and owning modules.
- Project-specific implementation plan that preserves the existing architecture.
