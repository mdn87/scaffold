# Migration Map: pavilion

- Target: C:\Users\Matt\Desktop\MyDocs\pavilion
- Generated: 2026-03-18 22:55:00
- Recommendation: adopt
- Based on: pavilion.inventory.json

## Decision Summary

- Rules: preserve
- Structure: adopt
- Interfaces: adopt
- Dependencies: adopt

## Baseline Adopt

- dir:docs
- dir:src
- dir:tests
- file:.gitignore
- file:README.md

## Baseline Map

- None

## Baseline Keep

- None

## Rule Files

- `.agents\always-approve-whitelisted-commands.md` -> preserve
- `.agents\quota-drain-prevention.md` -> preserve
- `.agents\rules.md` -> preserve

## Manifests

- None

## Interfaces

- None

## Safe First Slice

- None

## Next Steps

- Review scaffold-managed files before applying structural changes.
- Confirm preserve/merge decisions for any agent rules.
- Translate detected interfaces into explicit architecture context.
