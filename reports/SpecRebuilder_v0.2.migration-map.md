# Migration Map: SpecRebuilder_v0.2

- Target: ./SpecRebuilder_v0.2
- Generated: 2026-03-13 15:54:36
- Recommendation: map
- Based on: SpecRebuilder_v0.2.inventory.json

## Decision Summary

- Rules: preserve
- Structure: map
- Interfaces: split
- Dependencies: map

## Baseline Adopt

- None

## Baseline Map

- dir:docs
- dir:src

## Baseline Keep

- file:.gitignore
- file:README.md

## Rule Files

- `.agent\rules\always-approve-whitelisted-commands.md` -> preserve
- `.agent\rules\quota-drain-prevention.md` -> preserve
- `.agent\rules\restart-api-host-as-needed.md` -> preserve
- `.agents\always-approve-whitelisted-commands.md` -> preserve
- `.agents\quota-drain-prevention.md` -> preserve
- `.agents\restart-api-host-as-needed.md` -> preserve
- `.agents\rules.md` -> preserve

## Manifests

- `OOXML-Validator\OOXMLValidator.sln`
- `OOXML-Validator\OOXMLValidatorCLI\OOXMLValidatorCLI.csproj`
- `OOXML-Validator\OOXMLValidatorCLITests\OOXMLValidatorCLITests.csproj`
- `SpecRebuilder_v0.2.csproj`
- `SpecRebuilder_v0.2.sln`
- `src\Tools\BwaStyleCli\BwaStyleCli.csproj`

## Interfaces

- `src\API\StyleApiController.cs:12` -> split
- `src\API\StyleApiController.cs:25` -> split
- `src\API\StyleApiController.cs:42` -> split
- `src\API\StyleApiController.cs:63` -> split
- `src\API\StyleApiController.cs:89` -> split
- `src\API\StyleApiController.cs:111` -> split
- `src\API\StyleApiController.cs:181` -> split
- `src\API\StyleApiController.cs:209` -> split
- `src\API\StyleApiController.cs:246` -> split
- `src\API\StyleApiController.cs:273` -> split
- `src\API\StyleApiController.cs:299` -> split
- `src\API\StyleApiController.cs:353` -> split
- `src\API\StyleApiController.cs:402` -> split
- `src\API\VisualizerApi.cs:74` -> split
- `src\API\VisualizerApi.cs:96` -> split
- `src\API\VisualizerApi.cs:160` -> split
- `src\API\VisualizerApi.cs:170` -> split
- `src\API\VisualizerApi.cs:219` -> split
- `src\API\VisualizerApi.cs:453` -> split
- `src\API\VisualizerApi.cs:562` -> split

## Next Steps

- Review scaffold-managed files before applying structural changes.
- Confirm preserve/merge decisions for any agent rules.
- Translate detected interfaces into explicit architecture context.

