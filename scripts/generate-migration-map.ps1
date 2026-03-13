[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,
    [string]$OutputDirectory = ".\reports"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ListOrDefault {
    param(
        [object[]]$Items,
        [string]$DefaultValue
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
$inventoryPath = Join-Path $resolvedOutputDirectory "$safeProjectName.inventory.json"

if (-not (Test-Path -LiteralPath $inventoryPath)) {
    throw "Inventory report not found: $inventoryPath"
}

$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json

$ruleAction = if (@($inventory.ruleFiles).Count -gt 0) { "preserve" } else { "derive" }
$structureAction = switch ($inventory.recommendation) {
    "adopt" { "adopt" }
    "map" { "map" }
    default { "keep" }
}
$interfaceAction = if (@($inventory.likelyInterfaces).Count -gt 0) { "split" } else { "adopt" }
$dependencyAction = if (@($inventory.manifests).Count -gt 1) { "map" } else { "adopt" }

$baselineAdopt = @()
$baselineMap = @()
$baselineKeep = @()

foreach ($dir in $inventory.structure.baselineDirectories) {
    if ($dir.exists) {
        if ($inventory.recommendation -eq "adopt") {
            $baselineAdopt += "dir:$($dir.name)"
        }
        else {
            $baselineMap += "dir:$($dir.name)"
        }
    }
}

foreach ($file in $inventory.structure.baselineFiles) {
    if ($file.exists) {
        if ($inventory.recommendation -eq "adopt") {
            $baselineAdopt += "file:$($file.name)"
        }
        else {
            $baselineKeep += "file:$($file.name)"
        }
    }
}

$ruleNotes = @()
foreach ($rule in $inventory.ruleFiles) {
    $ruleNotes += [pscustomobject]@{
        path = $rule.path
        action = "preserve"
    }
}

$interfaceNotes = @()
foreach ($item in ($inventory.likelyInterfaces | Select-Object -First 20)) {
    $interfaceNotes += [pscustomobject]@{
        path = $item.path
        line = $item.line
        action = if ($inventory.recommendation -eq "map") { "split" } else { "adopt" }
    }
}

$map = [pscustomobject]@{
    targetPath = $inventory.targetPath
    projectName = $inventory.projectName
    generatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    basedOnInventory = "$safeProjectName.inventory.json"
    recommendation = $inventory.recommendation
    decisions = [pscustomobject]@{
        rules = $ruleAction
        structure = $structureAction
        interfaces = $interfaceAction
        dependencies = $dependencyAction
    }
    baseline = [pscustomobject]@{
        adopt = $baselineAdopt
        map = $baselineMap
        keep = $baselineKeep
    }
    ruleFiles = $ruleNotes
    manifests = $inventory.manifests
    interfaces = $interfaceNotes
    nextSteps = @(
        "Review scaffold-managed files before applying structural changes.",
        "Confirm preserve/merge decisions for any agent rules.",
        "Translate detected interfaces into explicit architecture context."
    )
}

$jsonPath = Join-Path $resolvedOutputDirectory "$safeProjectName.migration-map.json"
$mdPath = Join-Path $resolvedOutputDirectory "$safeProjectName.migration-map.md"

$map | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath

$ruleLines = @($map.ruleFiles | ForEach-Object { "- ``$($_.path)`` -> $($_.action)" })
$manifestLines = @($map.manifests | ForEach-Object { "- ``$($_.path)``" })
$interfaceLines = @($map.interfaces | ForEach-Object { "- ``$($_.path):$($_.line)`` -> $($_.action)" })
$adoptLines = @($map.baseline.adopt | ForEach-Object { "- $_" })
$mapLines = @($map.baseline.map | ForEach-Object { "- $_" })
$keepLines = @($map.baseline.keep | ForEach-Object { "- $_" })
$nextStepLines = @($map.nextSteps | ForEach-Object { "- $_" })

$md = @"
# Migration Map: $($map.projectName)

- Target: $($map.targetPath)
- Generated: $($map.generatedOn)
- Recommendation: $($map.recommendation)
- Based on: $($map.basedOnInventory)

## Decision Summary

- Rules: $($map.decisions.rules)
- Structure: $($map.decisions.structure)
- Interfaces: $($map.decisions.interfaces)
- Dependencies: $($map.decisions.dependencies)

## Baseline Adopt

$(Get-ListOrDefault -Items $adoptLines -DefaultValue "- None")

## Baseline Map

$(Get-ListOrDefault -Items $mapLines -DefaultValue "- None")

## Baseline Keep

$(Get-ListOrDefault -Items $keepLines -DefaultValue "- None")

## Rule Files

$(Get-ListOrDefault -Items $ruleLines -DefaultValue "- None")

## Manifests

$(Get-ListOrDefault -Items $manifestLines -DefaultValue "- None")

## Interfaces

$(Get-ListOrDefault -Items $interfaceLines -DefaultValue "- None")

## Next Steps

$(Get-ListOrDefault -Items $nextStepLines -DefaultValue "- None")
"@

Set-Content -LiteralPath $mdPath -Value $md

Write-Host "[migration-map] Wrote $jsonPath"
Write-Host "[migration-map] Wrote $mdPath"
