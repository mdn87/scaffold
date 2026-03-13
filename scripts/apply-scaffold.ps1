[CmdletBinding()]
param(
    [string]$TargetPath = ".",
    [string]$ProjectName,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host "[scaffold] $Message"
}

function Resolve-ProjectName {
    param(
        [string]$ResolvedTargetPath,
        [string]$ExplicitProjectName
    )

    if ($ExplicitProjectName) {
        return $ExplicitProjectName
    }

    return Split-Path -Leaf $ResolvedTargetPath
}

function Should-CopyFile {
    param(
        [string]$DestinationPath,
        [bool]$Overwrite
    )

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        return $true
    }

    return $Overwrite
}

function Copy-TemplateTree {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot,
        [hashtable]$Tokens,
        [bool]$Overwrite
    )

    $files = Get-ChildItem -LiteralPath $SourceRoot -Recurse -File

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourceRoot.Length).TrimStart("\")
        $destinationPath = Join-Path $DestinationRoot $relativePath
        $destinationDir = Split-Path -Parent $destinationPath

        if (-not (Test-Path -LiteralPath $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        if (-not (Should-CopyFile -DestinationPath $destinationPath -Overwrite $Overwrite)) {
            Write-Status "Skipping existing file $relativePath"
            continue
        }

        $content = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($key in $Tokens.Keys) {
            $content = $content.Replace("{{${key}}}", $Tokens[$key])
        }

        Set-Content -LiteralPath $destinationPath -Value $content -NoNewline
        Write-Status "Wrote $relativePath"
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$templateRoot = Join-Path $repoRoot "scaffold\templates\common"

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$resolvedProjectName = Resolve-ProjectName -ResolvedTargetPath $resolvedTargetPath -ExplicitProjectName $ProjectName
$targetConfigPath = Join-Path $resolvedTargetPath "scaffold.config.json"

if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template root not found: $templateRoot"
}

$tokens = @{
    PROJECT_NAME = $resolvedProjectName
}

Copy-TemplateTree -SourceRoot $templateRoot -DestinationRoot $resolvedTargetPath -Tokens $tokens -Overwrite $Force.IsPresent

if (-not (Test-Path -LiteralPath $targetConfigPath) -or $Force.IsPresent) {
    $config = [ordered]@{
        projectName = $resolvedProjectName
        scaffold = [ordered]@{
            template = "common"
            appliedOn = (Get-Date).ToString("yyyy-MM-dd")
        }
    } | ConvertTo-Json -Depth 4

    Set-Content -LiteralPath $targetConfigPath -Value $config
    Write-Status "Wrote scaffold.config.json"
}
else {
    Write-Status "Skipping existing file scaffold.config.json"
}

Write-Status "Scaffold application complete for $resolvedProjectName"
