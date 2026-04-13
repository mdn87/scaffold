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

function Get-OptionalContent {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw
    }

    return $null
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$resolvedOutputDirectory = Join-Path $repoRoot ($OutputDirectory.TrimStart(".\\"))
$safeProjectName = (Split-Path -Leaf $resolvedTargetPath) -replace "[^A-Za-z0-9._-]", "_"
$inventoryPath = Join-Path $resolvedOutputDirectory "$safeProjectName.inventory.json"
$mapPath = Join-Path $resolvedOutputDirectory "$safeProjectName.migration-map.json"

if (-not (Test-Path -LiteralPath $inventoryPath)) {
    throw "Inventory report not found: $inventoryPath"
}

if (-not (Test-Path -LiteralPath $mapPath)) {
    throw "Migration map not found: $mapPath"
}

$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
$map = Get-Content -LiteralPath $mapPath -Raw | ConvertFrom-Json
$readme = Get-OptionalContent -Path (Join-Path $resolvedTargetPath "README.md")
$rulesDoc = Get-OptionalContent -Path (Join-Path $resolvedTargetPath ".agents\rules.md")

$projectKind = if ($inventory.projectTypeHints -contains "dotnet" -and $inventory.projectTypeHints -contains "static-web-assets") {
    "Hybrid desktop + API + static web assets"
}
elseif ($inventory.projectTypeHints -contains "dotnet") {
    "Dotnet application"
}
else {
    "General project"
}

$purpose = "First-pass architecture context generated from scaffold inventory and migration map."
if ($readme -match "C# WinForms application for (?<desc>.+?)\.") {
    $purpose = $Matches.desc.Trim()
}

$subsystems = @()
if ($readme -match "COM-based Analysis") { $subsystems += "COM document analysis against Microsoft Word" }
if ($readme -match "Rule-based Detection") { $subsystems += "Rule-based structure detection" }
if ($readme -match "Human-in-the-Loop") { $subsystems += "Human review and correction workflow" }
if ($readme -match "Progressive Learning") { $subsystems += "Learning and correction logging" }
if ($inventory.projectTypeHints -contains "static-web-assets") { $subsystems += "Static web visualizer/assets served from wwwroot" }
if (@($inventory.likelyInterfaces).Count -gt 0) { $subsystems += "HTTP API surface under src/API" }

$ruleHighlights = @()
if ($rulesDoc -match "Known Pre-existing Build Errors") { $ruleHighlights += "Preserve known pre-existing build errors as verification exclusions." }
if ($rulesDoc -match "Default: LOW COMPUTE") { $ruleHighlights += "Honor low-compute defaults unless the user explicitly asks for deeper analysis." }
if ($rulesDoc -match "dotnet run --api") { $ruleHighlights += "API host commands are whitelisted for safe autorun within the project rule system." }
if ($rulesDoc -match "Remember to restart the API host") { $ruleHighlights += "Restart the API host when changes need to be reflected in the visualizer/API layer." }

$interfaceGroups = [ordered]@{}
foreach ($item in $inventory.likelyInterfaces) {
    $key = if ($item.text -match 'api/style') {
        'style-template-api'
    }
    elseif ($item.text -match 'stylegroups|styles') {
        'style-group-api'
    }
    elseif ($item.text -match 'analyze|chunks|exports|jobs|export-report|/api/export') {
        'analysis-export-api'
    }
    elseif ($item.text -match '/api/config') {
        'config-api'
    }
    elseif ($item.text -match 'visualizer') {
        'visualizer-api'
    }
    else {
        'other-api'
    }

    if (-not $interfaceGroups.Contains($key)) {
        $interfaceGroups[$key] = New-Object System.Collections.ArrayList
    }

    [void]$interfaceGroups[$key].Add([pscustomobject]@{
        path = $item.path
        line = $item.line
        text = $item.text
    })
}

$groupSummaries = @()
foreach ($key in $interfaceGroups.Keys) {
    $examples = @($interfaceGroups[$key] | Select-Object -First 3)
    $count = @($interfaceGroups[$key]).Count
    $groupSummaries += [pscustomobject]@{
        name = [string]$key
        count = $count
        examples = $examples
    }
}

$architecture = [pscustomobject]@{
    targetPath = $inventory.targetPath
    projectName = $inventory.projectName
    generatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    basedOn = [pscustomobject]@{
        inventory = "$safeProjectName.inventory.json"
        migrationMap = "$safeProjectName.migration-map.json"
    }
    summary = [pscustomobject]@{
        projectKind = $projectKind
        purpose = $purpose
        recommendation = $map.recommendation
    }
    scaffoldStance = [pscustomobject]@{
        rules = $map.decisions.rules
        structure = $map.decisions.structure
        interfaces = $map.decisions.interfaces
        dependencies = $map.decisions.dependencies
    }
    subsystems = $subsystems
    authoritativeRules = $map.ruleFiles
    ruleHighlights = $ruleHighlights
    manifests = $inventory.manifests
    baseline = $map.baseline
    interfaceGroups = $groupSummaries
    nextArtifacts = @(
        "Rule classification report consolidating .agent and .agents guidance.",
        "Explicit interface map with grouped endpoints and owning modules.",
        "Project-specific implementation plan that preserves the existing architecture."
    )
}

$jsonPath = Join-Path $resolvedOutputDirectory "$safeProjectName.architecture-context.json"
$mdPath = Join-Path $resolvedOutputDirectory "$safeProjectName.architecture-context.md"

$architecture | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath

$subsystemLines = @($architecture.subsystems | ForEach-Object { "- $_" })
$ruleFileLines = @($architecture.authoritativeRules | ForEach-Object { "- ``$($_.path)`` -> $($_.action)" })
$ruleHighlightLines = @($architecture.ruleHighlights | ForEach-Object { "- $_" })
$manifestLines = @($architecture.manifests | ForEach-Object { "- ``$($_.path)``" })
$baselineMapLines = @($architecture.baseline.map | ForEach-Object { "- $_" })
$baselineKeepLines = @($architecture.baseline.keep | ForEach-Object { "- $_" })
$interfaceGroupLines = @($architecture.interfaceGroups | ForEach-Object {
    $examples = @($_.examples | ForEach-Object { "``$($_.path):$($_.line)``" }) -join ", "
    "- $($_.name) ($($_.count)) : $examples"
})
$nextArtifactLines = @($architecture.nextArtifacts | ForEach-Object { "- $_" })

$md = @"
# Architecture Context: $($architecture.projectName)

- Target: $($architecture.targetPath)
- Generated: $($architecture.generatedOn)
- Based on: $($architecture.basedOn.inventory), $($architecture.basedOn.migrationMap)
- Project kind: $($architecture.summary.projectKind)
- Purpose: $($architecture.summary.purpose)
- Scaffold recommendation: $($architecture.summary.recommendation)

## Scaffold Stance

- Rules: $($architecture.scaffoldStance.rules)
- Structure: $($architecture.scaffoldStance.structure)
- Interfaces: $($architecture.scaffoldStance.interfaces)
- Dependencies: $($architecture.scaffoldStance.dependencies)

## Core Subsystems

$(Join-Lines -Items $subsystemLines)

## Authoritative Rule Files

$(Join-Lines -Items $ruleFileLines)

## Rule Highlights

$(Join-Lines -Items $ruleHighlightLines)

## Manifests

$(Join-Lines -Items $manifestLines)

## Baseline Mapping

Map into scaffold concepts:
$(Join-Lines -Items $baselineMapLines)

Keep as project-owned:
$(Join-Lines -Items $baselineKeepLines)

## Interface Groups

$(Join-Lines -Items $interfaceGroupLines)

## Next Artifacts

$(Join-Lines -Items $nextArtifactLines)
"@

Set-Content -LiteralPath $mdPath -Value $md

Write-Host "[architecture-context] Wrote $jsonPath"
Write-Host "[architecture-context] Wrote $mdPath"
