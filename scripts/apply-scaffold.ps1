[CmdletBinding()]
param(
    [string]$TargetPath = ".",
    [string]$ProjectName,
    [switch]$Force,
    [switch]$UseRemoteGitHubContext
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

    $files = Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force

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

    return @(Get-FileList -BasePath $BasePath -Patterns $patterns)
}

function Get-AgentRuleFiles {
    param([string]$BasePath)

    $candidatePatterns = @("AGENTS.md", "*.md")
    $files = Get-FileList -BasePath $BasePath -Patterns $candidatePatterns
    return @($files | Where-Object {
        $_.FullName -match "\\\.agent(s)?\\" -or
        $_.Name -ieq "AGENTS.md"
    })
}

function Get-ContextMarkdownFiles {
    param([string]$BasePath)

    $files = @(Get-ChildItem -LiteralPath $BasePath -Recurse -File -Filter *.md -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch "\\\.agent(s)?\\" -and
        $_.FullName -notmatch "\\.git\\" -and
        $_.Name -ne ".gitkeep"
    })

    $ranked = $files | Sort-Object @{ Expression = {
            if ($_.Name -ieq "README.md") { return 0 }
            if ($_.Name -match "(?i)plan") { return 1 }
            if ($_.Name -match "(?i)architecture|design|spec") { return 2 }
            return 3
        }
    }, FullName

    return @($ranked | Select-Object -First 10)
}

function Get-MeaningfulParagraph {
    param([string]$Content)

    $lines = $Content -split "`r?`n"
    $buffer = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if (-not $trimmed) {
            if ($buffer.Count -gt 0) {
                break
            }

            continue
        }

        if ($trimmed.StartsWith('#') -or $trimmed.StartsWith('```') -or $trimmed.StartsWith('-') -or $trimmed -match '^\d+\.') {
            if ($buffer.Count -gt 0) {
                break
            }

            continue
        }

        $buffer.Add($trimmed)
    }

    return ($buffer -join " ").Trim()
}

function Get-CommandHintsFromContent {
    param([string]$Content)

    $commands = New-Object System.Collections.Generic.List[string]
    $matches = [regex]::Matches($Content, '`([^`\r\n]{3,160})`')

    foreach ($match in $matches) {
        $candidate = $match.Groups[1].Value.Trim()
        if ($candidate -match '^(python|dotnet|npm|pnpm|yarn|git|cargo|go|pwsh|powershell|uv|poetry|pip|node)(\s|$)' -or
            $candidate -match '^\.\\.+\.ps1(\s|$)' -or
            $candidate -match '^python\s+.+\.py(\s|$)') {
            $commands.Add($candidate)
        }
    }

    return @($commands | Sort-Object -Unique)
}

function Get-SystemHintsFromContent {
    param([string]$Content)

    $lower = $Content.ToLowerInvariant()
    $systems = New-Object System.Collections.Generic.List[string]

    if ($lower -match 'power automate') { $systems.Add('Power Automate flow packaging/import') }
    if ($lower -match 'office 365|outlook') { $systems.Add('Microsoft 365 / Outlook integration') }
    if ($lower -match 'gateway|on-premises data gateway') { $systems.Add('On-premises data gateway dependency') }
    if ($lower -match 'api|endpoint|route|controller') { $systems.Add('API or routed interface surface') }
    if ($lower -match 'winforms|desktop') { $systems.Add('.NET desktop application workflow') }
    if ($lower -match 'zip|import package') { $systems.Add('Packaged artifact generation/import workflow') }
    if ($lower -match 'task scheduler|scheduled task') { $systems.Add('Windows Task Scheduler integration') }
    if ($lower -match 'unc|file share|network share') { $systems.Add('UNC path / file share dependency') }

    return @($systems | Sort-Object -Unique)
}

function Get-WorkflowHintsFromContent {
    param([string]$Content)

    $hints = New-Object System.Collections.Generic.List[string]
    $lines = $Content -split "`r?`n"

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\d+\.' -or $trimmed.StartsWith('- ')) {
            $clean = $trimmed -replace '^\d+\.\s*', ''
            $clean = $clean -replace '^\-\s*', ''
            if ($clean.Length -ge 12 -and $clean.Length -le 160) {
                $hints.Add($clean)
            }
        }
    }

    return @($hints | Select-Object -First 8)
}

function Get-DocumentationContext {
    param(
        [string]$BasePath,
        [System.IO.FileInfo[]]$MarkdownFiles
    )

    $sourceFiles = New-Object System.Collections.Generic.List[string]
    $paragraphs = New-Object System.Collections.Generic.List[string]
    $commands = New-Object System.Collections.Generic.List[string]
    $systems = New-Object System.Collections.Generic.List[string]
    $workflowHints = New-Object System.Collections.Generic.List[string]

    foreach ($file in $MarkdownFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $sourceFiles.Add((Get-RelativePath -BasePath $BasePath -FullPath $file.FullName))

        $paragraph = Get-MeaningfulParagraph -Content $content
        if ($paragraph) {
            $paragraphs.Add($paragraph)
        }

        foreach ($command in (Get-CommandHintsFromContent -Content $content)) {
            $commands.Add($command)
        }

        foreach ($system in (Get-SystemHintsFromContent -Content $content)) {
            $systems.Add($system)
        }

        foreach ($hint in (Get-WorkflowHintsFromContent -Content $content)) {
            $workflowHints.Add($hint)
        }
    }

    return [pscustomobject]@{
        sourceFiles = @($sourceFiles)
        purpose = if ($paragraphs.Count -gt 0) { $paragraphs[0] } else { $null }
        commandHints = @($commands | Sort-Object -Unique)
        systemHints = @($systems | Sort-Object -Unique)
        workflowHints = @($workflowHints | Sort-Object -Unique | Select-Object -First 8)
    }
}

function Get-CodeInferenceFiles {
    param([string]$BasePath)

    $priorityNames = @(
        'Program.cs','main.py','app.py','server.py','index.ts','index.js','server.ts','server.js',
        'manage.py','cli.py','app.ps1','main.ps1'
    )

    $files = @(Get-ChildItem -LiteralPath $BasePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '\\(bin|obj|node_modules|dist|build|__pycache__|\.git|\.agents|\.agent)\\' -and
        $_.Extension -in @('.cs','.py','.ts','.tsx','.js','.jsx','.ps1','.psm1','.psd1','.json','.yaml','.yml')
    })

    $ranked = $files | Sort-Object @{ Expression = {
            if ($priorityNames -contains $_.Name) { return 0 }
            if ($_.DirectoryName -match '\\src($|\\)' -and $_.BaseName -match '(?i)program|main|app|server|cli') { return 1 }
            if ($_.Name -match '(?i)reminder|archive|scheduler|worker|service|api|controller|flow|job') { return 2 }
            return 3
        }
    }, FullName

    return @($ranked | Select-Object -First 12)
}

function Get-CodePurposeSnippet {
    param([string]$Path)

    $lines = Get-Content -LiteralPath $Path -TotalCount 80 -ErrorAction SilentlyContinue
    if (-not $lines) {
        return $null
    }

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(#|//)\s*(.+)$' -and $Matches[2].Length -ge 20) {
            return $Matches[2].Trim()
        }
    }

    return $null
}
function Get-CodeInferenceContext {
    param([string]$BasePath)

    $files = @(Get-CodeInferenceFiles -BasePath $BasePath)
    $sourceFiles = New-Object System.Collections.Generic.List[string]
    $purposeCandidates = New-Object System.Collections.Generic.List[string]
    $workflowHints = New-Object System.Collections.Generic.List[string]
    $systemHints = New-Object System.Collections.Generic.List[string]
    $commandHints = New-Object System.Collections.Generic.List[string]
    $keywords = New-Object System.Collections.Generic.List[string]

    foreach ($file in $files) {
        $relative = Get-RelativePath -BasePath $BasePath -FullPath $file.FullName
        $sourceFiles.Add($relative)
        $nameText = ($file.BaseName -replace '[_\-.]+', ' ')

        foreach ($word in ($nameText -split '\s+')) {
            if ($word.Length -ge 4) {
                $keywords.Add($word.ToLowerInvariant())
            }
        }

        $snippet = Get-CodePurposeSnippet -Path $file.FullName
        if ($snippet) {
            $purposeCandidates.Add($snippet)
        }

        if ($relative -match '(?i)task.?scheduler|scheduler|scheduled') { $systemHints.Add('Windows Task Scheduler integration') }
        if ($relative -match '(?i)api|controller|route|server') { $systemHints.Add('API or routed interface surface') }
        if ($relative -match '(?i)archive|archiv') { $workflowHints.Add('Archive-oriented processing or retention workflow') }
        if ($relative -match '(?i)reminder|notify|email|mail') { $workflowHints.Add('Reminder or notification workflow') }
        if ($relative -match '(?i)flow') { $workflowHints.Add('Flow or automation package generation') }
        if ($relative -match '(?i)zip|package') { $workflowHints.Add('Package or artifact generation') }
        if ($relative -match '(?i)job|worker|service') { $workflowHints.Add('Background job or service-style execution') }
        if ($relative -match '(?i)cli') { $workflowHints.Add('Command-line entry point or utility workflow') }
        if ($relative -match '(?i)form') { $systemHints.Add('.NET desktop application workflow') }

        if ($file.Extension -eq '.py') { $commandHints.Add("python $relative") }
        if ($file.Name -ieq 'Program.cs') { $commandHints.Add('dotnet build') }
        if ($file.Extension -eq '.ps1') { $commandHints.Add(".\\$relative") }
    }

    $keywordSummary = @($keywords | Group-Object | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name | Select-Object -First 6 | ForEach-Object { $_.Name })
    $purpose = if ($purposeCandidates.Count -gt 0) {
        $purposeCandidates[0]
    }
    elseif ($keywordSummary.Count -gt 0) {
        'Likely project focus inferred from code and filenames: ' + ($keywordSummary -join ', ') + '.'
    }
    else {
        $null
    }

    return [pscustomobject]@{
        sourceFiles = @($sourceFiles)
        purpose = $purpose
        workflowHints = @($workflowHints | Sort-Object -Unique | Select-Object -First 8)
        systemHints = @($systemHints | Sort-Object -Unique)
        commandHints = @($commandHints | Sort-Object -Unique)
        keywords = $keywordSummary
    }
}

function Get-GitContext {
    param([string]$BasePath)

    $gitDir = Join-Path $BasePath '.git'
    if (-not (Test-Path -LiteralPath $gitDir)) {
        return [pscustomobject]@{
            hasGit = $false
            remoteUrl = $null
            repoName = $null
            sourceHint = $null
        }
    }

    $remoteUrl = $null
    try {
        $remoteUrl = (& git -C $BasePath remote get-url origin 2>$null)
    }
    catch {
        $remoteUrl = $null
    }

    $repoName = $null
    if ($remoteUrl -match '/([^/]+?)(\.git)?$') {
        $repoName = $Matches[1]
    }

    return [pscustomobject]@{
        hasGit = $true
        remoteUrl = if ($remoteUrl) { [string]$remoteUrl } else { $null }
        repoName = $repoName
        sourceHint = if ($remoteUrl -match 'github\.com') { 'GitHub remote configured locally' } elseif ($remoteUrl) { 'Git remote configured locally' } else { 'Git repo without remote' }
    }
}

function ConvertFrom-Base64Utf8 {
    param([string]$Value)

    if (-not $Value) {
        return $null
    }

    $normalized = $Value -replace '\s+', ''
    $bytes = [System.Convert]::FromBase64String($normalized)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-GitHubRepoIdentity {
    param([string]$RemoteUrl)

    if (-not $RemoteUrl) {
        return $null
    }

    if ($RemoteUrl -match '^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$') {
        return [pscustomobject]@{ owner = $Matches.owner; repo = $Matches.repo }
    }

    if ($RemoteUrl -match '^git@github\.com:(?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ owner = $Matches.owner; repo = $Matches.repo }
    }

    return $null
}

function Get-RemoteGitHubContext {
    param(
        [object]$GitContext,
        [switch]$UseRemoteGitHubContext
    )

    if (-not $UseRemoteGitHubContext.IsPresent) {
        return [pscustomobject]@{
            enabled = $false
            attempted = $false
            success = $false
            source = $null
            purpose = $null
            workflowHints = @()
            systemHints = @()
            commandHints = @()
            note = 'Remote GitHub enrichment not requested.'
        }
    }

    if (-not $GitContext.hasGit -or -not $GitContext.remoteUrl) {
        return [pscustomobject]@{
            enabled = $true
            attempted = $false
            success = $false
            source = $null
            purpose = $null
            workflowHints = @()
            systemHints = @()
            commandHints = @()
            note = 'No Git remote available for remote enrichment.'
        }
    }

    $identity = Get-GitHubRepoIdentity -RemoteUrl $GitContext.remoteUrl
    if ($null -eq $identity) {
        return [pscustomobject]@{
            enabled = $true
            attempted = $false
            success = $false
            source = $null
            purpose = $null
            workflowHints = @()
            systemHints = @()
            commandHints = @()
            note = 'Remote enrichment currently supports GitHub remotes only.'
        }
    }

    $headers = @{
        'User-Agent' = 'scaffold-generator'
        'Accept' = 'application/vnd.github+json'
    }

    try {
        $repoUrl = "https://api.github.com/repos/$($identity.owner)/$($identity.repo)"
        $repoInfo = Invoke-RestMethod -Uri $repoUrl -Headers $headers -TimeoutSec 8 -ErrorAction Stop

        $readmeText = $null
        try {
            $readmeInfo = Invoke-RestMethod -Uri ($repoUrl + '/readme') -Headers $headers -TimeoutSec 8 -ErrorAction Stop
            $readmeText = ConvertFrom-Base64Utf8 -Value $readmeInfo.content
        }
        catch {
            $readmeText = $null
        }

        $purpose = if ($repoInfo.description) {
            [string]$repoInfo.description
        }
        elseif ($readmeText) {
            Get-MeaningfulParagraph -Content $readmeText
        }
        else {
            $null
        }

        $workflowHints = @()
        $systemHints = @()
        $commandHints = @()

        if ($readmeText) {
            $workflowHints = @(Get-WorkflowHintsFromContent -Content $readmeText)
            $systemHints = @(Get-SystemHintsFromContent -Content $readmeText)
            $commandHints = @(Get-CommandHintsFromContent -Content $readmeText)
        }

        if ($repoInfo.homepage) {
            $systemHints += 'Homepage/docs configured in repository metadata'
        }

        return [pscustomobject]@{
            enabled = $true
            attempted = $true
            success = $true
            source = "github.com/$($identity.owner)/$($identity.repo)"
            purpose = $purpose
            workflowHints = @($workflowHints | Sort-Object -Unique | Select-Object -First 8)
            systemHints = @($systemHints | Sort-Object -Unique)
            commandHints = @($commandHints | Sort-Object -Unique)
            note = 'Remote GitHub enrichment succeeded.'
        }
    }
    catch {
        return [pscustomobject]@{
            enabled = $true
            attempted = $true
            success = $false
            source = "github.com/$($identity.owner)/$($identity.repo)"
            purpose = $null
            workflowHints = @()
            systemHints = @()
            commandHints = @()
            note = 'Remote GitHub enrichment failed and was skipped.'
        }
    }
}

function Test-IsBlankProject {
    param([string]$BasePath)

    $files = @(Get-ChildItem -LiteralPath $BasePath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '\\.git\\' -and
        $_.FullName -notmatch '\\\.agent(s)?\\'
    })

    $nonBaseline = @($files | Where-Object {
        $relative = Get-RelativePath -BasePath $BasePath -FullPath $_.FullName
        $relative -notin @(
            '.editorconfig',
            '.gitignore',
            'README.md',
            'scaffold.config.json',
            'docs\architecture.md',
            'docs\decisions\.gitkeep',
            'src\.gitkeep',
            'tests\.gitkeep'
        )
    })

    return @($nonBaseline).Count -eq 0
}
function Get-ExistingAgentRuleState {
    param(
        [string]$BasePath,
        [System.IO.FileInfo[]]$RuleFiles
    )

    if (@($RuleFiles).Count -eq 0) {
        return [pscustomobject]@{
            kind = 'none'
            outputRoot = (Join-Path $BasePath '.agents')
        }
    }

    $managedPaths = @(
        '.agents\rules.md',
        '.agents\always-approve-whitelisted-commands.md',
        '.agents\quota-drain-prevention.md',
        '.agents\restart-api-host-as-needed.md',
        '.agents\generate-copilot-instructions.md',
        '.agents\scaffold-generated\rules.md',
        '.agents\scaffold-generated\always-approve-whitelisted-commands.md',
        '.agents\scaffold-generated\quota-drain-prevention.md',
        '.agents\scaffold-generated\restart-api-host-as-needed.md',
        '.agents\scaffold-generated\generate-copilot-instructions.md'
    )

    $relativePaths = @($RuleFiles | ForEach-Object { Get-RelativePath -BasePath $BasePath -FullPath $_.FullName })
    $allManaged = @($relativePaths | Where-Object { $_ -notin $managedPaths }).Count -eq 0

    if ($allManaged) {
        $hasSidecar = @($relativePaths | Where-Object { $_ -like '.agents\scaffold-generated\*' }).Count -gt 0
        return [pscustomobject]@{
            kind = if ($hasSidecar) { 'scaffold-sidecar' } else { 'scaffold-direct' }
            outputRoot = if ($hasSidecar) { (Join-Path $BasePath '.agents\scaffold-generated') } else { (Join-Path $BasePath '.agents') }
        }
    }

    return [pscustomobject]@{
        kind = 'project-owned'
        outputRoot = (Join-Path $BasePath '.agents\scaffold-generated')
    }
}

function Get-ProjectSignals {
    param(
        [string]$BasePath,
        [switch]$UseRemoteGitHubContext
    )

    $manifestFiles = @(Get-ManifestFiles -BasePath $BasePath)
    $markdownFiles = @(Get-ContextMarkdownFiles -BasePath $BasePath)
    $documentation = Get-DocumentationContext -BasePath $BasePath -MarkdownFiles $markdownFiles
    $codeInference = Get-CodeInferenceContext -BasePath $BasePath
    $gitContext = Get-GitContext -BasePath $BasePath
    $remoteGitHub = Get-RemoteGitHubContext -GitContext $gitContext -UseRemoteGitHubContext:$UseRemoteGitHubContext.IsPresent
    $stackHints = New-Object System.Collections.Generic.List[string]

    foreach ($file in $manifestFiles) {
        switch -Wildcard ($file.Name) {
            'pyproject.toml' { $stackHints.Add('python') }
            'requirements.txt' { $stackHints.Add('python') }
            'package.json' { $stackHints.Add('node') }
            '*.csproj' { $stackHints.Add('dotnet') }
            '*.sln' { $stackHints.Add('dotnet') }
            'Cargo.toml' { $stackHints.Add('rust') }
            'go.mod' { $stackHints.Add('go') }
            'Brewfile' { $stackHints.Add('macos') }
            '*.sh' { $stackHints.Add('bash') }
            '.bashrc' { $stackHints.Add('bash') }
            '.zshrc' { $stackHints.Add('bash') }
            'Makefile' { $stackHints.Add('shell') }
            'Dockerfile' { $stackHints.Add('shell') }
            'docker-compose.yml' { $stackHints.Add('shell') }
            'docker-compose.yaml' { $stackHints.Add('shell') }
        }
    }

    foreach ($command in @($documentation.commandHints) + @($codeInference.commandHints) + @($remoteGitHub.commandHints)) {
        if ($command -match '^python(\s|$)' -or $command -match '\.py(\s|$)') { $stackHints.Add('python') }
        if ($command -match '^dotnet(\s|$)') { $stackHints.Add('dotnet') }
        if ($command -match '^(npm|pnpm|yarn|node)(\s|$)') { $stackHints.Add('node') }
        if ($command -match '^cargo(\s|$)') { $stackHints.Add('rust') }
        if ($command -match '^go(\s|$)') { $stackHints.Add('go') }
        if ($command -match '\.ps1(\s|$)') { $stackHints.Add('powershell') }
        if ($command -match '^(bash|sh|zsh)(\s|$)' -or $command -match '\.sh(\s|$)') { $stackHints.Add('bash') }
        if ($command -match '^brew(\s|$)') { $stackHints.Add('macos') }
        if ($command -match '^(apt-get|apt|yum|dnf|pacman)(\s|$)') { $stackHints.Add('linux') }
        if ($command -match '^(launchctl|launchd|systemctl|service)(\s|$)') { $stackHints.Add('shell') }
        if ($command -match '^(docker|docker-compose|kubectl)(\s|$)') { $stackHints.Add('shell') }
        if ($command -match '^(curl|wget)(\s|$)') { $stackHints.Add('shell') }
    }

    $stackHints = @($stackHints | Sort-Object -Unique)
    $combinedSystemHints = @($documentation.systemHints) + @($codeInference.systemHints) + @($remoteGitHub.systemHints)
    $combinedWorkflowHints = @($documentation.workflowHints) + @($codeInference.workflowHints) + @($remoteGitHub.workflowHints)
    $hasApiSurface =
        (Test-Path -LiteralPath (Join-Path $BasePath 'api')) -or
        (Test-Path -LiteralPath (Join-Path $BasePath 'controllers')) -or
        (Test-Path -LiteralPath (Join-Path $BasePath 'src\API')) -or
        (Test-Path -LiteralPath (Join-Path $BasePath 'wwwroot')) -or
        (@($combinedSystemHints | Where-Object { $_ -match 'API|interface surface' }).Count -gt 0)

    $projectType = if (($stackHints -contains 'dotnet') -and ($stackHints -contains 'node')) {
        'Hybrid .NET + Node project'
    }
    elseif (($stackHints -contains 'dotnet') -and $hasApiSurface) {
        '.NET application with API/web surface'
    }
    elseif (@($combinedSystemHints | Where-Object { $_ -eq 'Power Automate flow packaging/import' }).Count -gt 0) {
        'Power Automate packaging project'
    }
    elseif (@($combinedSystemHints | Where-Object { $_ -eq 'Windows Task Scheduler integration' }).Count -gt 0) {
        'Scheduled automation project'
    }
    elseif ($stackHints -contains 'dotnet') {
        '.NET application'
    }
    elseif ($stackHints -contains 'python') {
        'Python project'
    }
    elseif ($stackHints -contains 'node') {
        'Node project'
    }
    elseif ($stackHints -contains 'powershell') {
        'PowerShell automation project'
    }
    elseif ($stackHints -contains 'rust') {
        'Rust project'
    }
    elseif ($stackHints -contains 'go') {
        'Go project'
    }
    elseif ($stackHints -contains 'macos') {
        'macOS shell / automation project'
    }
    elseif ($stackHints -contains 'linux') {
        'Linux shell / automation project'
    }
    elseif ($stackHints -contains 'bash') {
        'Shell scripting project'
    }
    elseif ($stackHints -contains 'shell') {
        'Shell / DevOps automation project'
    }
    else {
        'General project'
    }

    $primaryLanguage = if ($stackHints -contains 'dotnet') {
        'C# / .NET'
    }
    elseif ($stackHints -contains 'python') {
        'Python'
    }
    elseif ($stackHints -contains 'node') {
        'TypeScript / JavaScript'
    }
    elseif ($stackHints -contains 'powershell') {
        'PowerShell'
    }
    elseif ($stackHints -contains 'rust') {
        'Rust'
    }
    elseif ($stackHints -contains 'go') {
        'Go'
    }
    elseif ($stackHints -contains 'macos') {
        'Bash / Zsh (macOS)'
    }
    elseif ($stackHints -contains 'linux') {
        'Bash / Shell (Linux)'
    }
    elseif ($stackHints -contains 'bash') {
        'Bash / Shell'
    }
    elseif ($stackHints -contains 'shell') {
        'Shell / DevOps scripting'
    }
    else {
        'Undetermined'
    }

    $isBlankProject = Test-IsBlankProject -BasePath $BasePath
    $purpose = if ($documentation.purpose) {
        $documentation.purpose
    }
    elseif ($remoteGitHub.purpose) {
        $remoteGitHub.purpose
    }
    elseif ($codeInference.purpose) {
        $codeInference.purpose
    }
    elseif ($gitContext.repoName) {
        'Likely project focus inferred from local Git metadata and repository naming: ' + $gitContext.repoName + '.'
    }
    else {
        $null
    }

    $derivationMode = if ($isBlankProject) {
        'blank-default'
    }
    elseif (@($documentation.sourceFiles).Count -gt 0) {
        'project-docs'
    }
    elseif ($remoteGitHub.success) {
        'remote-github'
    }
    elseif (@($codeInference.sourceFiles).Count -gt 0 -or $gitContext.hasGit) {
        'code-and-git'
    }
    else {
        'manifest-and-structure'
    }

    return [pscustomobject]@{
        manifestFiles = $manifestFiles
        markdownFiles = $markdownFiles
        documentation = $documentation
        codeInference = $codeInference
        gitContext = $gitContext
        remoteGitHub = $remoteGitHub
        stackHints = $stackHints
        hasApiSurface = $hasApiSurface
        projectType = $projectType
        primaryLanguage = $primaryLanguage
        isBlankProject = $isBlankProject
        derivationMode = $derivationMode
        purpose = $purpose
        systemHints = @($combinedSystemHints | Sort-Object -Unique)
        workflowHints = @($combinedWorkflowHints | Sort-Object -Unique | Select-Object -First 10)
        commandHints = @((@($documentation.commandHints) + @($codeInference.commandHints) + @($remoteGitHub.commandHints)) | Sort-Object -Unique)
    }
}

function Get-WhitelistCommands {
    param([object]$Signals)

    $commands = New-Object System.Collections.Generic.List[string]

    if ($Signals.stackHints -contains 'dotnet') {
        $commands.Add('dotnet build')
        $commands.Add('dotnet restore')
        $commands.Add('dotnet test')
        $commands.Add('dotnet format --verify-no-changes')
        $commands.Add('dotnet list package')
        $commands.Add('dotnet tool list')
    }

    if ($Signals.stackHints -contains 'python') {
        $commands.Add('python -m pytest')
        $commands.Add('python -m pip list')
    }

    if ($Signals.stackHints -contains 'node') {
        $commands.Add('npm test')
        $commands.Add('npm run build')
        $commands.Add('npm run lint')
        $commands.Add('npm list --depth=0')
    }

    if ($Signals.stackHints -contains 'powershell') {
        $commands.Add('Get-ScheduledTask')
    }

    if ($Signals.stackHints -contains 'rust') {
        $commands.Add('cargo test')
        $commands.Add('cargo check')
    }

    if ($Signals.stackHints -contains 'go') {
        $commands.Add('go test ./...')
        $commands.Add('go list ./...')
    }

    if ($Signals.stackHints -contains 'linux' -or $Signals.stackHints -contains 'macos' -or $Signals.stackHints -contains 'bash' -or $Signals.stackHints -contains 'shell') {
        $commands.Add('bash')
        $commands.Add('sh')
        $commands.Add('zsh')
        $commands.Add('brew install')
        $commands.Add('brew update')
        $commands.Add('brew upgrade')
        $commands.Add('brew list')
        $commands.Add('brew info')
        $commands.Add('brew services list')
        $commands.Add('apt-get install')
        $commands.Add('apt list --installed')
        $commands.Add('systemctl status')
        $commands.Add('systemctl list-units')
        $commands.Add('launchctl list')
        $commands.Add('curl')
        $commands.Add('wget')
        $commands.Add('chmod')
        $commands.Add('chown')
        $commands.Add('ln -s')
        $commands.Add('which')
        $commands.Add('env')
        $commands.Add('echo')
        $commands.Add('cat')
        $commands.Add('ls -la')
        $commands.Add('ps aux')
        $commands.Add('df -h')
        $commands.Add('du -sh')
        $commands.Add('top -l 1')
        $commands.Add('uname -a')
        $commands.Add('whoami')
    }

    foreach ($command in $Signals.commandHints) {
        $commands.Add($command)
    }

    $commands.Add('git status')
    $commands.Add('git diff')
    $commands.Add('git log --oneline')
    $commands.Add('bash')
    $commands.Add('sh')
    $commands.Add('cat')
    $commands.Add('ls')
    $commands.Add('ls -la')
    $commands.Add('echo')
    $commands.Add('which')
    $commands.Add('env')
    $commands.Add('brew list')
    $commands.Add('brew info')
    $commands.Add('curl')
    $commands.Add('Get-ChildItem')
    $commands.Add('Get-Content')
    $commands.Add('Select-String')
    $commands.Add('git add')
    $commands.Add('git branch')
    $commands.Add('git clone')
    $commands.Add('git commit')
    $commands.Add('git config')
    $commands.Add('git fetch')
    $commands.Add('git init')
    $commands.Add('git ls-tree')
    $commands.Add('git merge')
    $commands.Add('git pull')
    $commands.Add('git push')
    $commands.Add('git rebase --continue')
    $commands.Add('git remote')
    $commands.Add('git restore --staged')
    $commands.Add('git submodule')
    $commands.Add('git switch')
    $commands.Add('git worktree')
    $commands.Add('gh auth')
    $commands.Add('gh issue')
    $commands.Add('gh pr')
    $commands.Add('gh repo')
    $commands.Add('pwsh -File scripts/apply-scaffold.ps1')
    $commands.Add('pwsh -File scripts/generate-architecture-context.ps1')
    $commands.Add('pwsh -File scripts/generate-migration-map.ps1')

    return @($commands | Sort-Object -Unique)
}

function Format-BulletLines {
    param(
        [string[]]$Items,
        [string]$DefaultLine = '- None detected'
    )

    if (@($Items).Count -eq 0) {
        return $DefaultLine
    }

    return (@($Items) | ForEach-Object { "- $_" }) -join "`r`n"
}
function New-AgentsRulesContent {
    param(
        [string]$ProjectName,
        [string]$RootPath,
        [object]$Signals,
        [string[]]$WhitelistCommands
    )

    $stackLine = Format-BulletLines -Items $Signals.stackHints -DefaultLine '- general'
    $manifestLine = Format-BulletLines -Items @($Signals.manifestFiles | ForEach-Object { $_.Name })
    $sourceDocLines = Format-BulletLines -Items $Signals.documentation.sourceFiles
    $codeSourceLines = Format-BulletLines -Items $Signals.codeInference.sourceFiles
    $commandLines = Format-BulletLines -Items $WhitelistCommands
    $systemLines = Format-BulletLines -Items $Signals.systemHints
    $workflowLines = Format-BulletLines -Items $Signals.workflowHints
    $purposeLine = if ($Signals.purpose) { $Signals.purpose } else { 'No project-specific purpose was detected yet.' }
    $gitLines = @()
    if ($Signals.gitContext.sourceHint) { $gitLines += $Signals.gitContext.sourceHint }
    if ($Signals.gitContext.repoName) { $gitLines += ('Repository name: ' + $Signals.gitContext.repoName) }
    if ($Signals.gitContext.remoteUrl) { $gitLines += ('Remote: ' + $Signals.gitContext.remoteUrl) }
    $gitSectionLines = Format-BulletLines -Items $gitLines
    $remoteLines = @()
    if ($Signals.remoteGitHub.enabled) { $remoteLines += $Signals.remoteGitHub.note }
    if ($Signals.remoteGitHub.source) { $remoteLines += ('Source: ' + $Signals.remoteGitHub.source) }
    $remoteSectionLines = Format-BulletLines -Items $remoteLines
    $apiHostSection = if ($Signals.hasApiSurface) {
@"
## API Host Rule

Remember to restart the API host or local dev server if route, handler, or API-facing changes need to be reflected live.
"@
    }
    else {
        ''
    }

    $derivationNote = switch ($Signals.derivationMode) {
        'blank-default' { 'This rule set uses the scaffold baseline because the target looked effectively blank before scaffold files were applied.' }
        'project-docs' { 'This rule set was derived from existing project markdown plus detected manifests and structure.' }
        'remote-github' { 'This rule set was enriched from the configured GitHub remote and continued gracefully if any remote step failed.' }
        'code-and-git' { 'This rule set was derived from entry points, filenames, lightweight code comments, and local Git metadata because substantial project docs were not available.' }
        default { 'This rule set was derived from detected manifests and project structure because no substantial project docs were found.' }
    }

    return @"
---
trigger: always_on
---

# $ProjectName Agent Rules

## Project Context

- **Type**: $($Signals.projectType)
- **Root**: ``$RootPath``
- **Primary language**: $($Signals.primaryLanguage)
- **Derivation mode**: $($Signals.derivationMode)

## Purpose

$purposeLine

## Rule Source

$derivationNote

## Source Docs

$sourceDocLines

## Code Inference Sources

$codeSourceLines

## Local Git Signals

$gitSectionLines

## Remote GitHub Signals

$remoteSectionLines

## Detected Stack Hints

$stackLine

## Detected Manifests

$manifestLine

## Workflow Hints

$workflowLines

## External Systems / Runtime Notes

$systemLines

## Safe Auto-Run Whitelist

Set safe autorun for the following commands when they match the current workspace and request:

$commandLines

Non-destructive project-scoped execution may autorun when it matches the allowlist above. Destructive commands remain excluded even when related command families are otherwise allowed.

## Operating Defaults

- Prefer small, reviewable changes.
- Preserve project-owned rules and conventions before applying scaffold defaults.
- Match existing path and runtime conventions instead of forcing a new layout mid-change.
- Treat project docs such as `README.md`, plan files, and architecture notes as authoritative inputs for future updates to `.agents`.
- If docs are missing, use entry points, filenames, comments, and local Git metadata as fallback signals before defaulting to generic rules.
- Remote GitHub enrichment is best-effort only and must never block scaffold application.

## Quota / Compute Rules

### Default: LOW COMPUTE

- Only analyze the minimum necessary code.
- Avoid workspace-wide scans unless the user explicitly asks for deeper analysis.
- Reuse existing reports and context before re-reading large files.

### HIGH COMPUTE triggers (ask first)

Respond with: `"Estimated quota impact: HIGH. Proceed? (yes/no)"` before:
- Reading many files
- Generating multi-phase plans
- Deep debugging across multiple modules
- Running workspace-wide searches

### ULTRA COMPUTE triggers (ask first)

Respond with: `"Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)"` before:
- Full codebase analysis
- Large refactors across multiple files
- Architectural redesign

$apiHostSection
"@
}

function New-WhitelistContent {
    param([string[]]$WhitelistCommands)

    $commandLines = Format-BulletLines -Items $WhitelistCommands

    return @"
# Always Auto-Run Whitelisted Commands

When the workspace agent supports command safety flags, mark these commands safe to autorun without additional confirmation.
This list is derived from project manifests, command examples in markdown docs, lightweight entry-point inference, and optional remote GitHub enrichment.

$commandLines

## Explicitly Excluded From Autorun

- ``git reset --hard``
- ``git checkout --``
- ``git branch -D``
- ``git branch --delete``
- ``git push --force``
- ``git clean -fd``
- ``git clean -xfd``
- ``rm -rf``
- ``Remove-Item -Recurse``
"@
}

function New-QuotaContent {
    return @"
---
trigger: always_on
---

# Quota Protection Rules

## Default Operating Mode: LOW COMPUTE

- Analyze only the minimum code needed for the task.
- Prefer incremental implementation over broad planning.
- Do not repeat large scans or re-read unchanged files without a reason.
- Reuse project docs and generated context before widening scope.

## HIGH COMPUTE MODE

Ask first with: `"Estimated quota impact: HIGH. Proceed? (yes/no)"`

Use this before:
- Reading many files
- Running broad searches
- Producing multi-step architecture plans
- Deep debugging across several modules

## ULTRA COMPUTE MODE

Ask first with: `"Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)"`

Use this before:
- Full repo analysis
- Large refactors
- Architectural redesign
"@
}

function New-RestartApiContent {
    return @"
---
trigger: always_on
---

Restart the API host or local dev server when API-facing changes need to be reflected in the running app.
"@
}

function New-CopilotInstructionsContent {
    return @"
---
trigger: always_on
---

# GitHub Copilot Instructions Generation

When applying scaffold to a project, generate `.github/copilot-instructions.md` if it does not already exist.

## What to Include

Synthesize content from `AGENTS.md` and `CLAUDE.md` (or equivalent project context files) into a single file in Copilot's native format:

- **Project table** — active directories and what they contain
- **Skip lists** — directories and file types to ignore
- **Operating rules** — always-ask-before guardrails and safe auto-run defaults
- **Per-project quick-reference** — install, run, and architecture summary

## Rules

- Create `.github/` if it does not exist.
- Never overwrite an existing `.github/copilot-instructions.md` without user confirmation.
- Keep the file concise — Copilot reads it on every request; avoid redundant or verbose sections.
- Mirror the same guardrails from `.agents/always-approve-whitelisted-commands.md` and `quota-drain-prevention.md` so all agents share consistent operating boundaries.
"@
}

function ConvertTo-ClaudePermissions {
    param([string[]]$WhitelistCommands)

    # Commands that are PowerShell-native and have no Bash equivalent
    $psOnlyPrefixes = @('Get-', 'Select-', 'Set-', 'New-', 'Remove-', 'Invoke-', 'Write-', 'Read-', 'Format-', 'Out-')

    # Bare shell interpreters — too broad to whitelist safely in Claude
    $skipExact = @('bash', 'sh', 'zsh', 'pwsh', 'powershell')

    $permissions = New-Object System.Collections.Generic.List[string]

    foreach ($cmd in $WhitelistCommands) {
        $trimmed = $cmd.Trim()
        if (-not $trimmed) { continue }

        # Skip PowerShell cmdlets
        $isPs = $false
        foreach ($prefix in $psOnlyPrefixes) {
            if ($trimmed.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $isPs = $true
                break
            }
        }
        if ($isPs) { continue }

        # Skip bare interpreters
        if ($skipExact -contains $trimmed.ToLowerInvariant()) { continue }

        # Build a meaningful prefix: take up to 3 tokens, dropping flag tokens (starting with -)
        $tokens = $trimmed -split '\s+' | Where-Object { $_ -and -not $_.StartsWith('-') }
        $prefix = ($tokens | Select-Object -First 3) -join ' '

        if ($prefix) {
            $permissions.Add("Bash($prefix`:*)")
        }
    }

    return @($permissions | Sort-Object -Unique)
}

function New-ClaudeMdContent {
    param(
        [string]$ProjectName,
        [string]$RootPath,
        [object]$Signals
    )

    $stackLine = if ($Signals.stackHints.Count -gt 0) { $Signals.stackHints -join ', ' } else { 'general' }
    $purposeLine = if ($Signals.purpose) { $Signals.purpose } else { 'No project-specific purpose detected yet.' }

    $commandLines = Format-BulletLines -Items $Signals.commandHints -DefaultLine '- None detected'
    $workflowLines = Format-BulletLines -Items $Signals.workflowHints -DefaultLine '- None detected'

    return @"
# $ProjectName

## Project

- **Type**: $($Signals.projectType)
- **Stack**: $stackLine
- **Root**: ``$RootPath``

## Purpose

$purposeLine

## Key Commands

$commandLines

## Workflow Notes

$workflowLines

## Operating Rules

- Use the Read tool to read files — do not use ``cat`` or ``head`` via Bash.
- Search with Grep and Glob tools, not ``grep`` or ``find`` via Bash.
- Use the Edit tool for targeted changes; Write only for new files or full rewrites.
- Read and understand existing code before suggesting modifications.
- Prefer small, reviewable changes over large rewrites.
- Match existing path, naming, and runtime conventions.
- Treat README.md, plan files, and architecture docs as authoritative project context.
- Do not add features, comments, or error handling beyond what was asked.

## Compute Budget

### Default: LOW

- Read only the files necessary for the task.
- Reuse loaded context before fetching more.
- Do not scan the whole workspace unless explicitly asked.

### HIGH — confirm first

Say: ``Estimated quota impact: HIGH. Proceed? (yes/no)`` before:

- Reading many files across the project
- Running broad workspace searches
- Generating multi-step plans

### ULTRA — confirm first

Say: ``Estimated quota impact: EXTREMELY HIGH. Ultra compute mode. Proceed? (yes/no)`` before:

- Full codebase analysis
- Large refactors spanning many files
- Architectural redesign

## Permissions

Safe auto-run commands are configured in ``.claude/settings.json``. Normal project-scoped execution may autorun for listed non-destructive commands, including trusted Git, GitHub CLI, and repo script operations. Destructive commands remain explicitly denied.
"@
}

function New-CodexConfigContent {
    return @"
approval_policy = "never"
sandbox_mode = "danger-full-access"
"@
}

function Register-CodexGlobalTrust {
    param([string]$TargetPath)

    $globalCodexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'

    if (-not (Test-Path -LiteralPath $globalCodexConfig)) {
        Write-Status "Global Codex config not found at $globalCodexConfig — skipping trust registration"
        return
    }

    # Normalize to forward slashes for TOML key comparison (Codex uses Windows paths with single quotes)
    $escapedPath = $TargetPath.Replace("'", "''")
    $sectionHeader = "[projects.'$escapedPath']"
    $trustLine = 'trust_level = "trusted"'

    $content = Get-Content -LiteralPath $globalCodexConfig -Raw

    if ($content -match [regex]::Escape($sectionHeader)) {
        Write-Status "Global Codex trust entry already present for $TargetPath"
        return
    }

    # Append the new project trust block
    $block = "`n$sectionHeader`n$trustLine`n"
    Add-Content -LiteralPath $globalCodexConfig -Value $block
    Write-Status "Registered Codex global trust for $TargetPath"
}

function Get-ClaudeDenyPermissions {
    return @(
        'Bash(git reset --hard:*)',
        'Bash(git checkout --:*)',
        'Bash(git branch -D:*)',
        'Bash(git branch --delete:*)',
        'Bash(git push --force:*)',
        'Bash(git clean -fd:*)',
        'Bash(git clean -xfd:*)',
        'Bash(rm -rf:*)',
        'Bash(Remove-Item -Recurse:*)'
    )
}

function New-ClaudeSettingsContent {
    param(
        [string[]]$ClaudePermissions,
        [string[]]$ClaudeDenyPermissions
    )

    $allowArray = ($ClaudePermissions | ForEach-Object { "    `"$_`"" }) -join ",`n"
    $denyArray = ($ClaudeDenyPermissions | ForEach-Object { "    `"$_`"" }) -join ",`n"

    return @"
{
  "permissions": {
    "allow": [
$allowArray
    ],
    "deny": [
$denyArray
    ]
  }
}
"@
}

function Invoke-GitSetup {
    param(
        [string]$BasePath,
        [string]$ProjectName
    )

    $result = [pscustomobject]@{ didInit = $false; didAddRemote = $false }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Status "git not found in PATH — skipping git setup"
        return $result
    }

    $ctx = Get-GitContext -BasePath $BasePath
    $needsInit = -not $ctx.hasGit
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    $needsRemote = $ctx.hasGit -and -not $ctx.remoteUrl

    # Determine what we'd do and show a single confirmation
    if ($needsInit -or $needsRemote) {
        $plan = @()
        if ($needsInit) { $plan += "init git repo" }
        if ($needsInit -and $ghAvailable) { $plan += "create private GitHub repo '$ProjectName'" }
        elseif ($needsRemote -and $ghAvailable) { $plan += "create private GitHub repo '$ProjectName' and link as origin" }
        elseif ($needsInit -and -not $ghAvailable) { $plan += "note: install gh CLI to also create GitHub repo" }

        $planStr = $plan -join ", "
        $answer = Read-Host "[scaffold] $planStr — proceed? [Y/n]"
        if ($answer -match '^[Nn]') {
            return $result
        }
    }
    else {
        return $result
    }

    if ($needsInit) {
        & git -C $BasePath init | Out-Null
        Write-Status "Initialized git repository"
        $result.didInit = $true
        $ctx = Get-GitContext -BasePath $BasePath
    }

    if ($ctx.hasGit -and -not $ctx.remoteUrl -and $ghAvailable) {
        Write-Status "Creating private GitHub repository '$ProjectName'..."
        & gh repo create $ProjectName --private --source=$BasePath --remote=origin | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "GitHub repository created and linked as origin"
            $result.didAddRemote = $true
        }
        else {
            Write-Status "GitHub repository creation failed — continuing without remote"
        }
    }

    return $result
}

function Invoke-InitialCommit {
    param(
        [string]$BasePath,
        [bool]$DidInit
    )

    if (-not $DidInit) { return }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }

    $hasCommits = & git -C $BasePath log --oneline -1 2>$null
    if ($hasCommits) { return }

    $answer = Read-Host "[scaffold] Make an initial commit with scaffold files? [y/N]"
    if ($answer -notmatch '^[Yy]') { return }

    & git -C $BasePath add -A
    & git -C $BasePath commit -m "chore: initial scaffold"
    Write-Status "Initial commit created"

    $ctx = Get-GitContext -BasePath $BasePath
    if ($ctx.remoteUrl) {
        $pushAnswer = Read-Host "[scaffold] Push to origin? [y/N]"
        if ($pushAnswer -match '^[Yy]') {
            & git -C $BasePath push -u origin HEAD
            Write-Status "Pushed to origin"
        }
    }
}

function Write-AgentFiles {
    param(
        [string]$TargetPath,
        [string]$ProjectName,
        [switch]$Force,
        [switch]$UseRemoteGitHubContext
    )

    $existingRuleFiles = @(Get-AgentRuleFiles -BasePath $TargetPath)
    $existingRuleState = Get-ExistingAgentRuleState -BasePath $TargetPath -RuleFiles $existingRuleFiles
    $signals = Get-ProjectSignals -BasePath $TargetPath -UseRemoteGitHubContext:$UseRemoteGitHubContext.IsPresent
    $whitelistCommands = Get-WhitelistCommands -Signals $signals
    $outputRoot = switch ($existingRuleState.kind) {
        'none' { Join-Path $TargetPath '.agents' }
        'scaffold-direct' { Join-Path $TargetPath '.agents' }
        'scaffold-sidecar' { Join-Path $TargetPath '.agents\scaffold-generated' }
        'project-owned' {
            if ($Force.IsPresent) {
                Join-Path $TargetPath '.agents'
            }
            else {
                Join-Path $TargetPath '.agents\scaffold-generated'
            }
        }
    }

    if (-not (Test-Path -LiteralPath $outputRoot)) {
        New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
    }

    $files = @(
        [pscustomobject]@{
            path = Join-Path $outputRoot 'rules.md'
            relative = Get-RelativePath -BasePath $TargetPath -FullPath (Join-Path $outputRoot 'rules.md')
            content = New-AgentsRulesContent -ProjectName $ProjectName -RootPath $TargetPath -Signals $signals -WhitelistCommands $whitelistCommands
        },
        [pscustomobject]@{
            path = Join-Path $outputRoot 'always-approve-whitelisted-commands.md'
            relative = Get-RelativePath -BasePath $TargetPath -FullPath (Join-Path $outputRoot 'always-approve-whitelisted-commands.md')
            content = New-WhitelistContent -WhitelistCommands $whitelistCommands
        },
        [pscustomobject]@{
            path = Join-Path $outputRoot 'quota-drain-prevention.md'
            relative = Get-RelativePath -BasePath $TargetPath -FullPath (Join-Path $outputRoot 'quota-drain-prevention.md')
            content = New-QuotaContent
        },
        [pscustomobject]@{
            path = Join-Path $outputRoot 'generate-copilot-instructions.md'
            relative = Get-RelativePath -BasePath $TargetPath -FullPath (Join-Path $outputRoot 'generate-copilot-instructions.md')
            content = New-CopilotInstructionsContent
        }
    )

    if ($signals.hasApiSurface) {
        $files += [pscustomobject]@{
            path = Join-Path $outputRoot 'restart-api-host-as-needed.md'
            relative = Get-RelativePath -BasePath $TargetPath -FullPath (Join-Path $outputRoot 'restart-api-host-as-needed.md')
            content = New-RestartApiContent
        }
    }

    foreach ($file in $files) {
        if (-not (Should-CopyFile -DestinationPath $file.path -Overwrite ($Force.IsPresent -or $existingRuleState.kind -like 'scaffold-*'))) {
            Write-Status "Skipping existing file $($file.relative)"
            continue
        }

        Set-Content -LiteralPath $file.path -Value $file.content
        Write-Status "Wrote $($file.relative)"
    }

    # Claude Code parallel output: CLAUDE.md + .claude/settings.json
    $claudePermissions = @(ConvertTo-ClaudePermissions -WhitelistCommands $whitelistCommands)
    $claudeDenyPermissions = @(Get-ClaudeDenyPermissions)

    $claudeMdPath = Join-Path $TargetPath 'CLAUDE.md'
    $claudeMdRelative = Get-RelativePath -BasePath $TargetPath -FullPath $claudeMdPath
    if (Should-CopyFile -DestinationPath $claudeMdPath -Overwrite ($Force.IsPresent -or $existingRuleState.kind -like 'scaffold-*')) {
        Set-Content -LiteralPath $claudeMdPath -Value (New-ClaudeMdContent -ProjectName $ProjectName -RootPath $TargetPath -Signals $signals)
        Write-Status "Wrote $claudeMdRelative"
    }
    else {
        Write-Status "Skipping existing file $claudeMdRelative"
    }

    $claudeDir = Join-Path $TargetPath '.claude'
    if (-not (Test-Path -LiteralPath $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    $claudeSettingsPath = Join-Path $claudeDir 'settings.json'
    $claudeSettingsRelative = Get-RelativePath -BasePath $TargetPath -FullPath $claudeSettingsPath
    if (Should-CopyFile -DestinationPath $claudeSettingsPath -Overwrite ($Force.IsPresent -or $existingRuleState.kind -like 'scaffold-*')) {
        Set-Content -LiteralPath $claudeSettingsPath -Value (New-ClaudeSettingsContent -ClaudePermissions $claudePermissions -ClaudeDenyPermissions $claudeDenyPermissions)
        Write-Status "Wrote $claudeSettingsRelative"
    }
    else {
        Write-Status "Skipping existing file $claudeSettingsRelative"
    }

    $codexDir = Join-Path $TargetPath '.codex'
    if (-not (Test-Path -LiteralPath $codexDir)) {
        New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
    }
    $codexConfigPath = Join-Path $codexDir 'config.toml'
    $codexConfigRelative = Get-RelativePath -BasePath $TargetPath -FullPath $codexConfigPath
    if (Should-CopyFile -DestinationPath $codexConfigPath -Overwrite ($Force.IsPresent -or $existingRuleState.kind -like 'scaffold-*')) {
        Set-Content -LiteralPath $codexConfigPath -Value (New-CodexConfigContent)
        Write-Status "Wrote $codexConfigRelative"
    }
    else {
        Write-Status "Skipping existing file $codexConfigRelative"
    }

    return [pscustomobject]@{
        outputRoot = $outputRoot
        mode = if ($existingRuleState.kind -eq 'project-owned' -and -not $Force.IsPresent) { 'sidecar' } else { 'direct' }
        stackHints = @($signals.stackHints)
        hasApiSurface = $signals.hasApiSurface
        derivationMode = $signals.derivationMode
        sourceDocs = @($signals.documentation.sourceFiles)
        projectType = $signals.projectType
        remoteGitHubEnabled = $signals.remoteGitHub.enabled
        remoteGitHubSuccess = $signals.remoteGitHub.success
    }
}

function Copy-RuntimeToTarget {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [string]$RepoUrl,
        [string]$Branch = "main"
    )

    $runtimeSource = Join-Path $ScaffoldRoot "runtime"
    $scaffoldTarget = Join-Path $TargetPath ".scaffold"

    if (-not (Test-Path -LiteralPath $runtimeSource)) {
        Write-Warning "Runtime directory not found at $runtimeSource — skipping runtime injection"
        return
    }

    # Copy upstream-owned directories
    $upstreamDirs = @("orchestration", "skills", "tools", "references", "rules", "docs-templates")
    foreach ($dir in $upstreamDirs) {
        $src = Join-Path $runtimeSource $dir
        $dst = Join-Path $scaffoldTarget $dir
        if (Test-Path -LiteralPath $src) {
            if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
            Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        }
    }

    # Copy root-level runtime files
    $rootFiles = @("sync.sh")
    foreach ($file in $rootFiles) {
        $src = Join-Path $runtimeSource $file
        $dst = Join-Path $scaffoldTarget $file
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $dst -Force
        }
    }

    # Create project-owned directory if it doesn't exist
    $projectDir = Join-Path $scaffoldTarget "project"
    if (-not (Test-Path -LiteralPath $projectDir)) {
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

        # Empty project rules
        Set-Content -LiteralPath (Join-Path $projectDir "rules.md") -Value "# Project-Specific Rules`n`nAdd project-specific agent rules here. This file is never overwritten by scaffold sync.`n"

        # Default tool-config
        $toolConfig = @{
            project = (Split-Path $TargetPath -Leaf)
            initialized = (Get-Date -Format "yyyy-MM-dd")
            audit_interval_milestones = 3
            activated_tools = @("sync", "plan-overview-gen")
            activated_references = @()
            deactivated = @{}
        }
        $toolConfig | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $projectDir "tool-config.json")

        # Empty usage log
        Set-Content -LiteralPath (Join-Path $projectDir "usage-log.json") -Value "[]"
    }

    # Create/update upstream.json
    $currentCommit = $null
    try {
        $currentCommit = git -C $ScaffoldRoot rev-parse HEAD 2>$null
    } catch { }

    $upstreamPath = Join-Path $scaffoldTarget "upstream.json"
    $lastSyncedDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    if (Test-Path -LiteralPath $upstreamPath) {
        try {
            $existingUpstream = Get-Content -LiteralPath $upstreamPath -Raw | ConvertFrom-Json
            if (
                $existingUpstream.repo_url -eq $RepoUrl -and
                $existingUpstream.branch -eq $Branch -and
                $existingUpstream.last_synced_commit -eq $currentCommit -and
                $existingUpstream.last_synced_date
            ) {
                Write-Status "Runtime injected to $scaffoldTarget"
                return
            }
        } catch { }
    }

    $upstream = @{
        repo_url = $RepoUrl
        branch = $Branch
        last_synced_commit = $currentCommit
        last_synced_date = $lastSyncedDate
    }
    $upstream | ConvertTo-Json | Set-Content -LiteralPath $upstreamPath

    Write-Status "Runtime injected to $scaffoldTarget"
}

function Copy-DocTemplates {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [string]$ProjectName
    )

    $templateDir = Join-Path $ScaffoldRoot "runtime" "docs-templates"
    $docsDir = Join-Path $TargetPath "docs"

    if (-not (Test-Path -LiteralPath $templateDir)) { return }
    if (-not (Test-Path -LiteralPath $docsDir)) {
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    }

    $templateMap = @{
        "project-brief-template.md" = "project-brief.md"
        "architecture-template.md"  = "architecture.md"
        "index-template.md"         = "INDEX.md"
        "adr-template.md"           = "decisions/ADR-TEMPLATE.md"
    }

    $today = Get-Date -Format "yyyy-MM-dd"

    foreach ($template in $templateMap.GetEnumerator()) {
        $src = Join-Path $templateDir $template.Key
        $dst = Join-Path $docsDir $template.Value

        if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) {
            $dstDir = Split-Path $dst -Parent
            if (-not (Test-Path -LiteralPath $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }

            $content = Get-Content -LiteralPath $src -Raw
            $content = $content -replace '\{project_name\}', $ProjectName
            $content = $content -replace '\{date\}', $today
            $content = $content -replace '\{status\}', 'Draft'
            Set-Content -LiteralPath $dst -Value $content
        }
    }

    # Create plans and reviews directories
    @("plans", "reviews", "decisions") | ForEach-Object {
        $dir = Join-Path $docsDir $_
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $dir ".gitkeep") -Value ""
        }
    }

    Write-Status "Documentation templates applied to $docsDir"
}

function Invoke-ToolDiscovery {
    param(
        [string]$ScaffoldRoot,
        [string]$TargetPath,
        [hashtable]$DetectedSignals
    )

    $manifestPath = Join-Path $ScaffoldRoot "runtime" "tools" "manifest.json"
    $registryPath = Join-Path $ScaffoldRoot "runtime" "references" "registry.json"
    $toolConfigPath = Join-Path $TargetPath ".scaffold" "project" "tool-config.json"

    if (-not (Test-Path -LiteralPath $manifestPath)) { return }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $registry = if (Test-Path -LiteralPath $registryPath) { Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json } else { $null }

    $activated = @()
    $suggestions = @()

    # Auto-activate tools marked as auto_activate
    if ($manifest.tools) {
        foreach ($tool in $manifest.tools) {
            if ($tool.auto_activate) {
                $activated += $tool.name
            }
        }
    }

    # Check references against detected signals
    if ($registry -and $registry.references) {
        foreach ($ref in $registry.references) {
            $shouldSuggest = $false
            foreach ($trigger in $ref.auto_suggest_when) {
                if ($trigger -eq "any") { $shouldSuggest = $true; break }
                if ($trigger -eq "api" -and $DetectedSignals.has_api) { $shouldSuggest = $true; break }
                if ($trigger -eq "frontend" -and $DetectedSignals.has_frontend) { $shouldSuggest = $true; break }
                if ($trigger -eq "web" -and $DetectedSignals.has_frontend) { $shouldSuggest = $true; break }
                if ($trigger -eq "large_codebase" -and $DetectedSignals.large_codebase) { $shouldSuggest = $true; break }
            }

            if ($shouldSuggest) {
                $suggestions += @{
                    name = $ref.name
                    description = $ref.description
                    reason = "Detected: $($ref.auto_suggest_when -join ', ')"
                }
            }
        }
    }

    Write-Status ""
    Write-Status "Tool Discovery:"
    Write-Status "  Auto-activated: $($activated -join ', ')"

    if ($suggestions.Count -gt 0) {
        Write-Status "  Suggested (confirm with agent on first session):"
        foreach ($s in $suggestions) {
            Write-Status "    - $($s.name): $($s.description) ($($s.reason))"
        }
    }

    # Update tool-config.json
    if (Test-Path -LiteralPath $toolConfigPath) {
        $config = Get-Content -LiteralPath $toolConfigPath -Raw | ConvertFrom-Json
        $config.activated_tools = $activated
        $config.activated_references = @()
        $config | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $toolConfigPath
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$templateRoot = Join-Path $repoRoot 'scaffold\templates\common'

$resolvedTargetPath = (Resolve-Path -LiteralPath $TargetPath).Path
$resolvedProjectName = Resolve-ProjectName -ResolvedTargetPath $resolvedTargetPath -ExplicitProjectName $ProjectName
$targetConfigPath = Join-Path $resolvedTargetPath 'scaffold.config.json'

if (-not (Test-Path -LiteralPath $templateRoot)) {
    throw "Template root not found: $templateRoot"
}

$tokens = @{
    PROJECT_NAME = $resolvedProjectName
}

$gitSetup = Invoke-GitSetup -BasePath $resolvedTargetPath -ProjectName $resolvedProjectName
$agentWriteResult = Write-AgentFiles -TargetPath $resolvedTargetPath -ProjectName $resolvedProjectName -Force:$Force.IsPresent -UseRemoteGitHubContext:$UseRemoteGitHubContext.IsPresent
Register-CodexGlobalTrust -TargetPath $resolvedTargetPath
Copy-TemplateTree -SourceRoot $templateRoot -DestinationRoot $resolvedTargetPath -Tokens $tokens -Overwrite $Force.IsPresent

# --- Runtime Layer ---
if (Test-Path -LiteralPath (Join-Path $repoRoot "runtime")) {
    $scaffoldRepoUrl = ""
    try {
        $scaffoldRepoUrl = git -C $repoRoot remote get-url origin 2>$null
    } catch { }

    if (-not $scaffoldRepoUrl) {
        Write-Warning "No git remote found for scaffold repo — upstream.json will have empty repo_url"
    }

    Copy-RuntimeToTarget -ScaffoldRoot $repoRoot -TargetPath $resolvedTargetPath -RepoUrl $scaffoldRepoUrl
    Copy-DocTemplates -ScaffoldRoot $repoRoot -TargetPath $resolvedTargetPath -ProjectName $resolvedProjectName

    $discoverySignals = @{
        stack = $agentWriteResult.stackHints
        has_api = $agentWriteResult.hasApiSurface
        has_frontend = $false
        large_codebase = ((Get-ChildItem -LiteralPath $resolvedTargetPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 100)
    }
    Invoke-ToolDiscovery -ScaffoldRoot $repoRoot -TargetPath $resolvedTargetPath -DetectedSignals $discoverySignals
}

# Add scaffold handoff entries to .gitignore
$gitignorePath = Join-Path $resolvedTargetPath ".gitignore"
if (Test-Path -LiteralPath $gitignorePath) {
    $gitignoreContent = Get-Content -LiteralPath $gitignorePath -Raw
    $entriesToAdd = @(".scaffold/project/handoff.md", ".scaffold/project/handoff-history/")
    $added = $false
    foreach ($entry in $entriesToAdd) {
        if ($gitignoreContent -notmatch [regex]::Escape($entry)) {
            Add-Content -LiteralPath $gitignorePath -Value $entry
            $added = $true
        }
    }
    if ($added) {
        Write-Status "Added scaffold handoff entries to .gitignore"
    }
}

if (-not (Test-Path -LiteralPath $targetConfigPath) -or $Force.IsPresent) {
    $config = [ordered]@{
        projectName = $resolvedProjectName
        scaffold = [ordered]@{
            template = 'common'
            appliedOn = (Get-Date).ToString('yyyy-MM-dd')
            agentRules = [ordered]@{
                mode = $agentWriteResult.mode
                outputPath = Get-RelativePath -BasePath $resolvedTargetPath -FullPath $agentWriteResult.outputRoot
                stackHints = @($agentWriteResult.stackHints)
                hasApiSurface = $agentWriteResult.hasApiSurface
                derivationMode = $agentWriteResult.derivationMode
                projectType = $agentWriteResult.projectType
                sourceDocs = @($agentWriteResult.sourceDocs)
                remoteGitHubEnabled = $agentWriteResult.remoteGitHubEnabled
                remoteGitHubSuccess = $agentWriteResult.remoteGitHubSuccess
            }
        }
    } | ConvertTo-Json -Depth 6

    Set-Content -LiteralPath $targetConfigPath -Value $config
    Write-Status 'Wrote scaffold.config.json'
}
else {
    Write-Status 'Skipping existing file scaffold.config.json'
}

Write-Status "Scaffold application complete for $resolvedProjectName"
Invoke-InitialCommit -BasePath $resolvedTargetPath -DidInit $gitSetup.didInit
