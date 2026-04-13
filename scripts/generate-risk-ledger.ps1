[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,
    [string]$OutputDirectory = ".\reports"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Join-Lines {
    param(
        [object[]]$Items,
        [string]$DefaultValue = "- None"
    )

    if (@($Items).Count -eq 0) {
        return $DefaultValue
    }

    return ($Items -join "`r`n")
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$resolvedOutputDirectory = Join-Path $repoRoot ($OutputDirectory.TrimStart(".\\"))
$safeProjectName = (Split-Path -Leaf $resolvedTargetPath) -replace "[^A-Za-z0-9._-]", "_"
$contextPath = Join-Path $resolvedOutputDirectory "$safeProjectName.architecture-context.json"
$mapPath = Join-Path $resolvedOutputDirectory "$safeProjectName.migration-map.json"
$interfaceMapPath = Join-Path $resolvedOutputDirectory "$safeProjectName.interface-map.md"

if (-not (Test-Path -LiteralPath $contextPath)) {
    throw "Architecture context not found: $contextPath"
}

if (-not (Test-Path -LiteralPath $mapPath)) {
    throw "Migration map not found: $mapPath"
}

$context = Get-Content -LiteralPath $contextPath -Raw | ConvertFrom-Json
$map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
$interfaceMap = if (Test-Path -LiteralPath $interfaceMapPath) { Get-Content -LiteralPath $interfaceMapPath -Raw } else { "" }

$riskItems = @(
    [pscustomobject]@{
        area = "Word COM analysis and document mutation"
        level = "high"
        likelihood = "medium"
        impact = "high"
        reason = "Core functionality depends on Word COM behavior, visible numbering extraction, and document mutation that can fail in non-obvious ways."
        triggers = @(
            "Changes to COM interop calls or Word lifecycle management",
            "Changes to paragraph analysis or numbering rebuild logic",
            "Changes to file open/save/export flows"
        )
        safeguards = @(
            "Validate against real documents, not only synthetic samples",
            "Keep manual review path intact",
            "Treat COM cleanup and error handling as regression-sensitive"
        )
    },
    [pscustomobject]@{
        area = "API registration and request routing"
        level = "high"
        likelihood = "medium"
        impact = "high"
        reason = "The app uses both MVC controller routing and Minimal API registration, so moving or consolidating endpoints can easily break assumptions in hosting or route resolution."
        triggers = @(
            "Moving endpoints between StyleApiController and VisualizerApi",
            "Changing route prefixes or HTTP methods",
            "Refactoring CreateApiApp registration order"
        )
        safeguards = @(
            "Preserve current route surface until explicit tests exist",
            "Document endpoint ownership before refactors",
            "Verify static files and API routes together after changes"
        )
    },
    [pscustomobject]@{
        area = "File I/O and project-root-relative storage"
        level = "high"
        likelihood = "high"
        impact = "high"
        reason = "Templates, playgrounds, stylegroups, exports, and ready-folder data all rely on path logic and persistent files; path changes can break multiple workflows at once."
        triggers = @(
            "Changing folder names or root-relative path calculations",
            "Moving templates, exports, or stylegroup storage",
            "Changing bin-folder fallback behavior"
        )
        safeguards = @(
            "Make path changes behind a single abstraction",
            "Smoke test template, export, and stylegroup flows after edits",
            "Prefer additive config over implicit path rewrites"
        )
    },
    [pscustomobject]@{
        area = "Background analysis jobs and in-memory state"
        level = "medium"
        likelihood = "medium"
        impact = "high"
        reason = "The analysis pipeline uses in-memory job tracking, so concurrency or lifecycle changes can silently break polling, retries, or restart behavior."
        triggers = @(
            "Changing Task.Run job execution",
            "Replacing or mutating the ConcurrentDictionary job store",
            "Adding restart persistence without explicit design"
        )
        safeguards = @(
            "Keep job state transitions explicit",
            "Test analyze -> poll -> export sequence end to end",
            "Treat persistence changes as architecture work, not cleanup"
        )
    },
    [pscustomobject]@{
        area = "Agent rules and operational workflow"
        level = "medium"
        likelihood = "low"
        impact = "medium"
        reason = "Rule files do not change runtime behavior directly, but changing or merging them can degrade future maintenance quality and verification discipline."
        triggers = @(
            "Merging .agent and .agents content without classification",
            "Dropping known build-error exclusions",
            "Ignoring API host restart guidance"
        )
        safeguards = @(
            "Preserve current rules until a deliberate consolidation pass",
            "Keep pre-existing error exclusions explicit",
            "Treat rule changes as operational changes with review"
        )
    },
    [pscustomobject]@{
        area = "Scaffold-managed documentation and reports"
        level = "low"
        likelihood = "low"
        impact = "low"
        reason = "Generated reports and docs mostly affect understanding, not execution, unless they are later used to justify incorrect code changes."
        triggers = @(
            "Overwriting project-owned docs blindly",
            "Assuming generated reports are perfectly accurate",
            "Using reports as code-change authority without verification"
        )
        safeguards = @(
            "Keep generated artifacts separate from runtime code",
            "Verify claims against source before refactors",
            "Prefer additive docs over replacing repo docs"
        )
    }
)

$overallRisk = [pscustomobject]@{
    currentScaffoldPass = "low"
    futureStructuralRefactor = "high"
    futureEndpointRefactor = "high"
    futureRuleConsolidation = "medium"
}

$ledger = [pscustomobject]@{
    targetPath = $resolvedTargetPath
    projectName = $context.projectName
    generatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    basedOn = [pscustomobject]@{
        architectureContext = "$safeProjectName.architecture-context.json"
        migrationMap = "$safeProjectName.migration-map.json"
        interfaceMap = if ($interfaceMap) { "$safeProjectName.interface-map.md" } else { $null }
    }
    summary = [pscustomobject]@{
        currentPassBreakageRisk = "low"
        rationale = "The completed scaffold work generated analysis artifacts and skipped baseline application for the mapped project, so runtime code paths were not modified."
        nextChangeRisk = $overallRisk
    }
    riskItems = $riskItems
    recommendedSequencing = @(
        "Refine interface ownership and tests before endpoint refactors.",
        "Abstract file path handling before moving storage locations.",
        "Consolidate agent rules only after preserve/merge classification.",
        "Treat COM-analysis changes as highest-regression work."
    )
}

$jsonPath = Join-Path $resolvedOutputDirectory "$safeProjectName.risk-ledger.json"
$mdPath = Join-Path $resolvedOutputDirectory "$safeProjectName.risk-ledger.md"

$ledger | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath

$riskLines = @($ledger.riskItems | ForEach-Object {
    $triggerText = ($_.triggers | ForEach-Object { "- $_" }) -join "`r`n"
    $safeguardText = ($_.safeguards | ForEach-Object { "- $_" }) -join "`r`n"
    @"
### $($_.area)

- Level: $($_.level)
- Likelihood: $($_.likelihood)
- Impact: $($_.impact)
- Reason: $($_.reason)
- Common triggers:
$triggerText
- Safeguards:
$safeguardText
"@
})

$sequenceLines = @($ledger.recommendedSequencing | ForEach-Object { "- $_" })

$md = @"
# Risk Ledger: $($ledger.projectName)

- Target: $($ledger.targetPath)
- Generated: $($ledger.generatedOn)
- Based on: $($ledger.basedOn.architectureContext), $($ledger.basedOn.migrationMap), $($ledger.basedOn.interfaceMap)

## Current Pass Risk

- Current scaffold pass breakage risk: $($ledger.summary.currentPassBreakageRisk)
- Rationale: $($ledger.summary.rationale)

## Next Change Risk

- Future structural refactor: $($ledger.summary.nextChangeRisk.futureStructuralRefactor)
- Future endpoint refactor: $($ledger.summary.nextChangeRisk.futureEndpointRefactor)
- Future rule consolidation: $($ledger.summary.nextChangeRisk.futureRuleConsolidation)

## Risk Areas

$(Join-Lines -Items $riskLines)

## Recommended Sequencing

$(Join-Lines -Items $sequenceLines)
"@

Set-Content -LiteralPath $mdPath -Value $md

Write-Host "[risk-ledger] Wrote $jsonPath"
Write-Host "[risk-ledger] Wrote $mdPath"
