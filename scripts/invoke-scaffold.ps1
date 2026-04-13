[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,
    [ValidateSet("inventory", "apply", "activate")]
    [string]$Action = "activate",
    [string]$ProjectName,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host "[invoke-scaffold] $Message"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$inventoryScript = Join-Path $scriptRoot "inventory-project.ps1"
$mapScript = Join-Path $scriptRoot "generate-migration-map.ps1"
$architectureScript = Join-Path $scriptRoot "generate-architecture-context.ps1"
$riskLedgerScript = Join-Path $scriptRoot "generate-risk-ledger.ps1"
$applyScript = Join-Path $scriptRoot "apply-scaffold.ps1"
$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$safeProjectName = (Split-Path -Leaf $resolvedTargetPath) -replace "[^A-Za-z0-9._-]", "_"
$reportPath = Join-Path $repoRoot "reports\$safeProjectName.inventory.json"
$mapPath = Join-Path $repoRoot "reports\$safeProjectName.migration-map.md"
$riskLedgerPath = Join-Path $repoRoot "reports\$safeProjectName.risk-ledger.md"

if ($Action -eq "inventory") {
    & $inventoryScript -TargetPath $resolvedTargetPath
    return
}

if ($Action -eq "apply") {
    & $applyScript -TargetPath $resolvedTargetPath -ProjectName $ProjectName -Force:$Force.IsPresent
    return
}

& $inventoryScript -TargetPath $resolvedTargetPath

if (-not (Test-Path -LiteralPath $reportPath)) {
    throw "Inventory report not found: $reportPath"
}

& $mapScript -TargetPath $resolvedTargetPath
& $architectureScript -TargetPath $resolvedTargetPath
& $riskLedgerScript -TargetPath $resolvedTargetPath

$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
Write-Status "Recommendation for $($report.projectName): $($report.recommendation)"
Write-Status "Migration map ready at reports\$safeProjectName.migration-map.md"
Write-Status "Risk ledger ready at reports\$safeProjectName.risk-ledger.md"

if ($report.recommendation -eq "adopt") {
    Write-Status "Applying baseline scaffold because the target aligns with safe adoption."
    & $applyScript -TargetPath $resolvedTargetPath -ProjectName $ProjectName -Force:$Force.IsPresent
    return
}

Write-Status "Skipping baseline apply for recommendation '$($report.recommendation)'."
Write-Status "Review $mapPath and $riskLedgerPath before making structural changes."
