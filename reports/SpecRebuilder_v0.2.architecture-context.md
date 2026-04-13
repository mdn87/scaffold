# Architecture Context: SpecRebuilder_v0.2

- Target: ./SpecRebuilder_v0.2
- Generated: 2026-03-13 16:03:03
- Based on: SpecRebuilder_v0.2.inventory.json, SpecRebuilder_v0.2.migration-map.json
- Project kind: Hybrid desktop + API + static web assets
- Purpose: analyzing and rebuilding CSI specification documents using Word COM Interop
- Scaffold recommendation: map

## Scaffold Stance

- Rules: preserve
- Structure: map
- Interfaces: split
- Dependencies: map

## Core Subsystems

- COM document analysis against Microsoft Word
- Rule-based structure detection
- Human review and correction workflow
- Learning and correction logging
- Static web visualizer/assets served from wwwroot
- HTTP API surface under src/API

## Authoritative Rule Files

- `.agent\rules\always-approve-whitelisted-commands.md` -> preserve
- `.agent\rules\quota-drain-prevention.md` -> preserve
- `.agent\rules\restart-api-host-as-needed.md` -> preserve
- `.agents\always-approve-whitelisted-commands.md` -> preserve
- `.agents\quota-drain-prevention.md` -> preserve
- `.agents\restart-api-host-as-needed.md` -> preserve
- `.agents\rules.md` -> preserve

## Rule Highlights

- Preserve known pre-existing build errors as verification exclusions.
- Honor low-compute defaults unless the user explicitly asks for deeper analysis.
- API host commands are whitelisted for safe autorun within the project rule system.
- Restart the API host when changes need to be reflected in the visualizer/API layer.

## Manifests

- `OOXML-Validator\OOXMLValidator.sln`
- `OOXML-Validator\OOXMLValidatorCLI\OOXMLValidatorCLI.csproj`
- `OOXML-Validator\OOXMLValidatorCLITests\OOXMLValidatorCLITests.csproj`
- `SpecRebuilder_v0.2.csproj`
- `SpecRebuilder_v0.2.sln`
- `src\Tools\BwaStyleCli\BwaStyleCli.csproj`

## Baseline Mapping

Map into scaffold concepts:
- dir:docs
- dir:src

Keep as project-owned:
- file:.gitignore
- file:README.md

## Interface Groups

- style-template-api (9) : `src\API\StyleApiController.cs:12`, `src\API\VisualizerApi.cs:562`, `src\API\VisualizerApi.cs:617`
- other-api (12) : `src\API\StyleApiController.cs:25`, `src\API\StyleApiController.cs:42`, `src\API\StyleApiController.cs:63`
- config-api (1) : `src\API\VisualizerApi.cs:74`
- analysis-export-api (6) : `src\API\VisualizerApi.cs:96`, `src\API\VisualizerApi.cs:160`, `src\API\VisualizerApi.cs:170`
- visualizer-api (1) : `src\API\VisualizerApi.cs:871`

## Next Artifacts

- Rule classification report consolidating .agent and .agents guidance.
- Explicit interface map with grouped endpoints and owning modules.
- Project-specific implementation plan that preserves the existing architecture.

