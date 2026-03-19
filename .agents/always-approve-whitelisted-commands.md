# Always Auto-Run Whitelisted Commands

When the workspace agent supports command safety flags, mark these commands safe to autorun without additional confirmation.
This list is derived from project manifests, command examples in markdown docs, lightweight entry-point inference, and optional remote GitHub enrichment.

- bash
- brew info
- brew list
- cat
- curl
- dotnet build
- dotnet format --verify-no-changes
- dotnet list package
- dotnet restore
- dotnet run --api
- dotnet test
- dotnet tool list
- echo
- env
- Get-ChildItem
- Get-Content
- git diff
- git log --oneline
- git status
- ls
- ls -la
- Select-String
- sh
- which
