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

function Get-OptionalJson {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-TextValue {
    param([object]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return [string]$Value
}

function Get-EndpointRiskScore {
    param([object]$Group)

    $score = 0
    $text = @(
        (Get-TextValue -Value $Group.name),
        (Get-TextValue -Value $Group.description),
        (Get-TextValue -Value $Group.owner),
        (Get-TextValue -Value $Group.routePrefix),
        (Get-TextValue -Value $Group.backingService)
    ) -join " "

    $lower = $text.ToLowerInvariant()

    if ($lower -match "diagnostic|config|discrepanc") { $score -= 3 }
    if ($lower -match "stylegroup") { $score += 2 }
    if ($lower -match "style|template|document|css") { $score += 4 }
    if ($lower -match "analy|chunk|job|export") { $score += 5 }
    if ($lower -match "word|com|playground|upload|download|file|ready folder") { $score += 6 }

    $endpointCount = @($Group.endpoints).Count
    $score += [Math]::Max($endpointCount - 1, 0)

    return $score
}

function Get-SafeFirstSlice {
    param(
        [object]$InterfaceMap,
        [object]$RiskLedger
    )

    if ($null -eq $InterfaceMap -or @($InterfaceMap.groups).Count -eq 0) {
        return $null
    }

    $candidates = @()
    foreach ($group in $InterfaceMap.groups) {
        $riskScore = Get-EndpointRiskScore -Group $group
        $candidates += [pscustomobject]@{
            name = $group.name
            owner = $group.owner
            routePrefix = $group.routePrefix
            endpointCount = @($group.endpoints).Count
            riskScore = $riskScore
        }
    }

    $selected = $candidates |
        Sort-Object riskScore, endpointCount, name |
        Select-Object -First 1

    if ($null -eq $selected) {
        return $null
    }

    $deferredAreas = @()
    if ($RiskLedger) {
        $deferredAreas = @(
            $RiskLedger.riskItems |
                Where-Object { $_.level -eq "high" } |
                Select-Object -ExpandProperty area
        )
    }

    $rationale = @(
        "This slice has the lowest inferred runtime risk from the current interface map.",
        "It avoids the heaviest Word COM, export, and project-root file-path workflows during the first implementation pass.",
        "It creates room to add route-preservation checks before touching broader endpoint consolidation."
    )

    $guardrails = @(
        "Preserve the existing route prefix and HTTP methods.",
        "Keep changes additive until explicit endpoint tests exist.",
        "Avoid moving file-path or document-processing logic in the same pass."
    )

    return [pscustomobject]@{
        group = $selected.name
        owner = $selected.owner
        routePrefix = $selected.routePrefix
        endpointCount = $selected.endpointCount
        rationale = $rationale
        guardrails = $guardrails
        deferredRiskAreas = $deferredAreas
    }
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$resolvedOutputDirectory = Join-Path $repoRoot ($OutputDirectory.TrimStart(".\\"))
$safeProjectName = (Split-Path -Leaf $resolvedTargetPath) -replace "[^A-Za-z0-9._-]", "_"
$inventoryPath = Join-Path $resolvedOutputDirectory "$safeProjectName.inventory.json"
$riskLedgerPath = Join-Path $resolvedOutputDirectory "$safeProjectName.risk-ledger.json"
$interfaceMapPath = Join-Path $resolvedOutputDirectory "$safeProjectName.interface-map.json"

if (-not (Test-Path -LiteralPath $inventoryPath)) {
    throw "Inventory report not found: $inventoryPath"
}

$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
$riskLedger = Get-OptionalJson -Path $riskLedgerPath
$interfaceMap = Get-OptionalJson -Path $interfaceMapPath

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
    safeFirstSlice = Get-SafeFirstSlice -InterfaceMap $interfaceMap -RiskLedger $riskLedger
    nextSteps = @(
        "Review scaffold-managed files before applying structural changes.",
        "Confirm preserve/merge decisions for any agent rules.",
        "Translate detected interfaces into explicit architecture context."
    )
}

if ($map.safeFirstSlice) {
    $map.nextSteps += "Start with the '$($map.safeFirstSlice.group)' slice and keep route behavior unchanged while adding ownership/tests."
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
$safeSliceRationaleLines = @()
$safeSliceGuardrailLines = @()
$safeSliceDeferredLines = @()

if ($map.safeFirstSlice) {
    $safeSliceRationaleLines = @($map.safeFirstSlice.rationale | ForEach-Object { "- $_" })
    $safeSliceGuardrailLines = @($map.safeFirstSlice.guardrails | ForEach-Object { "- $_" })
    $safeSliceDeferredLines = @($map.safeFirstSlice.deferredRiskAreas | ForEach-Object { "- $_" })
}

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

## Safe First Slice

$(if ($map.safeFirstSlice) {
@"
- Group: $($map.safeFirstSlice.group)
- Owner: $($map.safeFirstSlice.owner)
- Route prefix: $($map.safeFirstSlice.routePrefix)
- Endpoint count: $($map.safeFirstSlice.endpointCount)

Rationale:
$(Get-ListOrDefault -Items $safeSliceRationaleLines)

Guardrails:
$(Get-ListOrDefault -Items $safeSliceGuardrailLines)

Deferred high-risk areas:
$(Get-ListOrDefault -Items $safeSliceDeferredLines)
"@
} else {
"- None"
})

## Next Steps

$(Get-ListOrDefault -Items $nextStepLines -DefaultValue "- None")
"@

Set-Content -LiteralPath $mdPath -Value $md

Write-Host "[migration-map] Wrote $jsonPath"
Write-Host "[migration-map] Wrote $mdPath"
