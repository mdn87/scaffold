[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,
    [string]$OutputDirectory = ".\reports"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath)
    $full = [System.IO.Path]::GetFullPath($FullPath)

    if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($base.Length).TrimStart("\")
    }

    return $full
}

function Get-FileList {
    param(
        [string]$BasePath,
        [string[]]$Patterns
    )

    $results = @()
    foreach ($pattern in $Patterns) {
        $results += Get-ChildItem -LiteralPath $BasePath -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
    }

    return $results | Sort-Object FullName -Unique
}

function Get-RuleFiles {
    param([string]$BasePath)

    $candidatePatterns = @("AGENTS.md", "*.md")
    $files = Get-FileList -BasePath $BasePath -Patterns $candidatePatterns
    return $files | Where-Object {
        $_.FullName -match "\\\.agent(s)?\\" -or
        $_.Name -ieq "AGENTS.md" -or
        $_.Name -match "rules"
    }
}

function Get-ManifestFiles {
    param([string]$BasePath)

    $patterns = @(
        "package.json",
        "pyproject.toml",
        "requirements.txt",
        "*.csproj",
        "*.sln",
        "Cargo.toml",
        "go.mod"
    )

    return Get-FileList -BasePath $BasePath -Patterns $patterns
}

function Get-LikelyEndpointLines {
    param([string]$BasePath)

    $patterns = @(
        "MapGet",
        "MapPost",
        "MapPut",
        "MapDelete",
        "[Route(",
        "[HttpGet",
        "[HttpPost",
        "app.get(",
        "app.post(",
        "router.",
        "fetch(",
        "axios"
    )

    $scanRoots = @(
        (Join-Path $BasePath "src"),
        (Join-Path $BasePath "app"),
        (Join-Path $BasePath "api"),
        (Join-Path $BasePath "controllers"),
        (Join-Path $BasePath "wwwroot")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    $codeFiles = @()
    foreach ($scanRoot in $scanRoots) {
        $codeFiles += Get-ChildItem -LiteralPath $scanRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -in @(".cs", ".ts", ".tsx", ".js", ".jsx") -and
                $_.FullName -notmatch "\\(bin|obj|node_modules|dist|build|__pycache__)\\"
            }
    }

    $programFile = Join-Path $BasePath "Program.cs"
    if (Test-Path -LiteralPath $programFile) {
        $codeFiles += Get-Item -LiteralPath $programFile
    }

    $codeFiles = $codeFiles | Sort-Object FullName -Unique
    if (@($codeFiles).Count -eq 0) {
        return @()
    }

    $matches = @()
    foreach ($pattern in $patterns) {
        $matches += Select-String -Path $codeFiles.FullName -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
    }

    return $matches | Sort-Object Path, LineNumber -Unique | Select-Object -First 80
}

function Get-StructureAssessment {
    param([string]$BasePath)

    $expectedDirs = @("docs", "src", "tests")
    $expectedFiles = @(".gitignore", "README.md")

    $presentDirs = @()
    foreach ($dir in $expectedDirs) {
        $presentDirs += [pscustomobject]@{
            name = $dir
            exists = Test-Path -LiteralPath (Join-Path $BasePath $dir)
        }
    }

    $presentFiles = @()
    foreach ($file in $expectedFiles) {
        $presentFiles += [pscustomobject]@{
            name = $file
            exists = Test-Path -LiteralPath (Join-Path $BasePath $file)
        }
    }

    return [pscustomobject]@{
        baselineDirectories = $presentDirs
        baselineFiles = $presentFiles
    }
}

function Get-ProjectTypeHints {
    param([System.IO.FileInfo[]]$ManifestFiles, [string]$BasePath)

    $hints = New-Object System.Collections.Generic.List[string]

    foreach ($file in $ManifestFiles) {
        switch -Wildcard ($file.Name) {
            "pyproject.toml" { $hints.Add("python") }
            "package.json" { $hints.Add("node") }
            "*.csproj" { $hints.Add("dotnet") }
            "*.sln" { $hints.Add("solution") }
        }
    }

    if (Test-Path -LiteralPath (Join-Path $BasePath "wwwroot")) {
        $hints.Add("static-web-assets")
    }

    if ((Test-Path -LiteralPath (Join-Path $BasePath ".agent")) -or (Test-Path -LiteralPath (Join-Path $BasePath ".agents"))) {
        $hints.Add("agent-rules")
    }

    return $hints | Sort-Object -Unique
}

function Get-Recommendation {
    param(
        [object]$Structure,
        [string[]]$ProjectTypeHints,
        [System.IO.FileInfo[]]$RuleFiles,
        [object[]]$EndpointLines
    )

    $hasBaseline = ($Structure.baselineDirectories | Where-Object { $_.exists }).Count -ge 2
    $hasComplexSurface = @($EndpointLines).Count -gt 5 -or $ProjectTypeHints -contains "static-web-assets"
    $hasRules = @($RuleFiles).Count -gt 0

    if ($hasComplexSurface -and $hasRules) {
        return "map"
    }

    if ($hasBaseline -and -not $hasComplexSurface) {
        return "adopt"
    }

    if ($hasRules) {
        return "keep"
    }

    return "adopt"
}

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$resolvedOutputDirectory = Join-Path $repoRoot ($OutputDirectory.TrimStart(".\"))

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory)) {
    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
}

$ruleFiles = @(Get-RuleFiles -BasePath $resolvedTargetPath)
$manifestFiles = @(Get-ManifestFiles -BasePath $resolvedTargetPath)
$endpointLines = @(Get-LikelyEndpointLines -BasePath $resolvedTargetPath)
$structure = Get-StructureAssessment -BasePath $resolvedTargetPath
$projectTypeHints = @(Get-ProjectTypeHints -ManifestFiles $manifestFiles -BasePath $resolvedTargetPath)
$recommendation = Get-Recommendation -Structure $structure -ProjectTypeHints $projectTypeHints -RuleFiles $ruleFiles -EndpointLines $endpointLines

$report = [pscustomobject]@{
    targetPath = $resolvedTargetPath
    projectName = Split-Path -Leaf $resolvedTargetPath
    generatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    projectTypeHints = $projectTypeHints
    recommendation = $recommendation
    structure = $structure
    ruleFiles = @($ruleFiles | ForEach-Object {
        [pscustomobject]@{
            path = Get-RelativePath -BasePath $resolvedTargetPath -FullPath $_.FullName
        }
    })
    manifests = @($manifestFiles | ForEach-Object {
        [pscustomobject]@{
            path = Get-RelativePath -BasePath $resolvedTargetPath -FullPath $_.FullName
        }
    })
    likelyInterfaces = @($endpointLines | ForEach-Object {
        [pscustomobject]@{
            path = Get-RelativePath -BasePath $resolvedTargetPath -FullPath $_.Path
            line = $_.LineNumber
            text = $_.Line.Trim()
        }
    })
}

$safeProjectName = (Split-Path -Leaf $resolvedTargetPath) -replace "[^A-Za-z0-9._-]", "_"
$jsonPath = Join-Path $resolvedOutputDirectory "$safeProjectName.inventory.json"
$mdPath = Join-Path $resolvedOutputDirectory "$safeProjectName.inventory.md"

$json = $report | ConvertTo-Json -Depth 6
Set-Content -LiteralPath $jsonPath -Value $json

$targetLine = "- Target: $resolvedTargetPath"
$generatedLine = "- Generated: $($report.generatedOn)"
$recommendationLine = "- Recommendation: $($report.recommendation)"
$typeHintsLine = "- Type hints: $([string]::Join(', ', $report.projectTypeHints))"

$rulesSection = if (@($report.ruleFiles).Count -eq 0) {
    "- None detected"
}
else {
    ($report.ruleFiles | ForEach-Object { "- ``$($_.path)``" }) -join "`r`n"
}

$manifestsSection = if (@($report.manifests).Count -eq 0) {
    "- None detected"
}
else {
    ($report.manifests | ForEach-Object { "- ``$($_.path)``" }) -join "`r`n"
}

$dirsSection = ($report.structure.baselineDirectories | ForEach-Object {
    "- dir ``$($_.name)``: $($_.exists)"
}) -join "`r`n"

$filesSection = ($report.structure.baselineFiles | ForEach-Object {
    "- file ``$($_.name)``: $($_.exists)"
}) -join "`r`n"

$interfacesSection = if (@($report.likelyInterfaces).Count -eq 0) {
    "- None detected"
}
else {
    ($report.likelyInterfaces | Select-Object -First 20 | ForEach-Object {
        "- ``$($_.path):$($_.line)`` - $($_.text)"
    }) -join "`r`n"
}

$md = @"
# Project Inventory: $($report.projectName)

$targetLine
$generatedLine
$recommendationLine
$typeHintsLine

## Rules

$rulesSection

## Manifests

$manifestsSection

## Baseline Alignment

$dirsSection
$filesSection

## Likely Interfaces

$interfacesSection
"@

Set-Content -LiteralPath $mdPath -Value $md

Write-Host "[inventory] Wrote $jsonPath"
Write-Host "[inventory] Wrote $mdPath"


