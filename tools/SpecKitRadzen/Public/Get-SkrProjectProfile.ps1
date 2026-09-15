function Get-SkrProjectProfile {
    <#
    .SYNOPSIS
        Automatic project detection. Writes .speckit/radzen/profile.json and profile.md and returns the profile.
    .PARAMETER Solution
        Solution file (relative or absolute) to scope detection to. Stored in .speckit/radzen/config.json.
    .PARAMETER NoWrite
        Return the profile without writing files.
    #>
    [CmdletBinding()]
    param(
        [string] $Repository = (Get-Location).Path,
        [string] $Solution,
        [switch] $NoWrite
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $stateRoot = Get-SkrStateRoot $repo
    $config = Get-SkrConfig -Repository $repo
    $script:SkrContentCache = @{}

    # ---------- repository & solution ----------
    $solutions = @(Get-SkrRepositoryFile -Repository $repo -Include '*.sln', '*.slnx' | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName } | Sort-Object)
    $selection = 'none'
    $selected = $null
    if ($Solution) {
        $full = if ([System.IO.Path]::IsPathRooted($Solution)) { $Solution } else { Join-Path $repo $Solution }
        if (-not (Test-Path $full)) { throw "Solution '$Solution' not found." }
        $selected = Get-SkrRelativePath -Base $repo -Path (Resolve-Path $full).Path
        $selection = 'configured'
        if (-not $NoWrite) {
            $cfgPath = Join-Path $stateRoot 'config.json'
            $local = Read-SkrJson -Path $cfgPath -AsHashtable
            if (-not $local) { $local = @{} }
            $local.solution = $selected
            Write-SkrJson -Path $cfgPath -InputObject $local
        }
    }
    elseif ($config.solution) {
        if (-not (Test-Path (Join-Path $repo $config.solution))) { throw "Configured solution '$($config.solution)' (config.json) no longer exists. Run detect -Solution <path>." }
        $selected = $config.solution; $selection = 'configured'
    }
    elseif ($solutions.Count -eq 1) { $selected = $solutions[0]; $selection = 'single' }
    elseif ($solutions.Count -gt 1) { $selection = 'ambiguous' }

    $instructionNames = @('AGENTS.md', 'CLAUDE.md', 'CONTRIBUTING.md', '.github/copilot-instructions.md', 'docs/architecture.md', 'ARCHITECTURE.md', '.editorconfig')
    $instructions = @($instructionNames | Where-Object { Test-Path (Join-Path $repo $_) })
    $instructions += @(Get-ChildItem -Path (Join-Path $repo '.github' 'instructions') -Filter '*.instructions.md' -ErrorAction Ignore | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
    if (Test-Path (Join-Path $stateRoot 'local' 'constitution.local.md')) { $instructions += '.speckit/radzen/local/constitution.local.md' }
    $agentEnv = @()
    foreach ($pair in @(
            @('.claude', 'Claude Code (.claude/)'), @('CLAUDE.md', 'Claude Code (CLAUDE.md)'), @('.mcp.json', 'MCP config (.mcp.json)'),
            @('AGENTS.md', 'Codex / AGENTS.md'), @('.agents', 'Agent skills (.agents/)'), @('.codex', 'Codex (.codex/)'),
            @('.github/copilot-instructions.md', 'GitHub Copilot'), @('.github/instructions', 'GitHub Copilot (path instructions)'), @('.github/prompts', 'GitHub Copilot (prompt files)'),
            @('.vscode/mcp.json', 'VS Code MCP'), @('.cursor', 'Cursor'), @('.vs/mcp.json', 'Visual Studio MCP'))) {
        if (Test-Path (Join-Path $repo $pair[0])) { $agentEnv += $pair[1] }
    }

    # ---------- projects ----------
    $sharedProps = @{}
    $buildProps = Join-Path $repo 'Directory.Build.props'
    if (Test-Path $buildProps) { $sharedProps = Get-SkrMsBuildProperty -Xml (Get-SkrXml -Path $buildProps) }
    $central = @{}
    $cpmFiles = @(Get-SkrRepositoryFile -Repository $repo -Include 'Directory.Packages.props')
    foreach ($cpm in $cpmFiles) {
        $xml = Get-SkrXml -Path $cpm.FullName
        if (-not $xml) { continue }
        $cpmProps = Get-SkrMsBuildProperty -Xml $xml
        foreach ($k in $cpmProps.Keys) { if (-not $sharedProps.ContainsKey($k)) { $sharedProps[$k] = $cpmProps[$k] } }
        foreach ($n in $xml.SelectNodes('//*[local-name()="PackageVersion"]')) { $central[$n.GetAttribute('Include')] = Expand-SkrMsBuildValue $n.GetAttribute('Version') $cpmProps }
    }
    $csprojFiles = @(Get-SkrRepositoryFile -Repository $repo -Include '*.csproj')
    if ($selected) {
        $inSolution = @(Get-SkrSolutionProject -SolutionPath (Join-Path $repo $selected) -Repository $repo)
        if ($inSolution.Count) { $csprojFiles = @($csprojFiles | Where-Object { $inSolution -contains (Get-SkrRelativePath -Base $repo -Path $_.FullName) }) }
    }
    $projects = @($csprojFiles | Sort-Object FullName | ForEach-Object {
            $props = @{}
            foreach ($k in $sharedProps.Keys) { $props[$k] = $sharedProps[$k] }
            $nearest = Find-SkrUpward -StartDirectory $_.DirectoryName -FileName 'Directory.Build.props' -Repository $repo
            if ($nearest -and $nearest -ne $buildProps) { $p2 = Get-SkrMsBuildProperty -Xml (Get-SkrXml -Path $nearest); foreach ($k in $p2.Keys) { $props[$k] = $p2[$k] } }
            Read-SkrProject -File $_ -Repository $repo -CentralVersions $central -SharedProperties $props
        })
    $projectDirs = @($projects | ForEach-Object directory)

    # ---------- content cache (source files inside detected projects, or whole repo) ----------
    $scanExclude = @($config.scan.excludePaths)
    $sourceFiles = @(Get-SkrRepositoryFile -Repository $repo -Include '*.cs', '*.razor', '*.cshtml', '*.html' | Where-Object {
            $file = $_
            $rel = Get-SkrRelativePath -Base $repo -Path $file.FullName
            ($file.Length -lt 1MB) -and -not ($scanExclude | Where-Object { $rel -like ($_ -replace '\*\*/', '*') }) -and
            ((-not $projectDirs.Count) -or ($projectDirs | Where-Object { $file.FullName.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar) }))
        })
    foreach ($f in $sourceFiles) { $script:SkrContentCache[$f.FullName] = [System.IO.File]::ReadAllText($f.FullName) }
    $cs = @($sourceFiles | Where-Object Extension -eq '.cs')
    $razor = @($sourceFiles | Where-Object Extension -eq '.razor')
    $hostFiles = @($sourceFiles | Where-Object { $_.Name -in 'App.razor', '_Host.cshtml', '_Layout.cshtml', 'index.html', 'Routes.razor' })
    $programFiles = @($cs | Where-Object { $_.Name -in 'Program.cs', 'Startup.cs', 'MauiProgram.cs' -or $script:SkrContentCache[$_.FullName] -match 'WebApplication\.CreateBuilder|WebAssemblyHostBuilder|MauiApp\.CreateBuilder' })
    $layoutFiles = @($razor | Where-Object { $_.Name -like '*Layout.razor' })
    $importFiles = @($razor | Where-Object Name -eq '_Imports.razor')

    $sections = @{ runtime = [ordered]@{}; blazor = [ordered]@{}; radzen = [ordered]@{}; architecture = [ordered]@{}; security = [ordered]@{}; testing = [ordered]@{} }
    $health = [System.Collections.Generic.List[object]]::new()
    $addHealth = { param($id, $sev, $msg, $ev) $health.Add([ordered]@{ id = $id; severity = $sev; message = $msg; evidence = @($ev) }) }

    # ---------- runtime ----------
    $globalJson = Join-Path $repo 'global.json'
    if (Test-Path $globalJson) {
        $gj = Read-SkrJson -Path $globalJson
        $sdkVersion = if ($gj -and $gj.sdk) { $gj.sdk.version } else { $null }
        $sections.runtime.sdk = if ($sdkVersion) { New-SkrFact $sdkVersion 'proven' @('global.json') -Note "rollForward: $($gj.sdk.rollForward)" } else { New-SkrFact $null 'unknown' @('global.json') }
    }
    else { $sections.runtime.sdk = New-SkrFact $null 'unknown' @() -Note 'No global.json; the installed SDK is used.' }
    $allTfms = @($projects | ForEach-Object targetFrameworks | Select-Object -Unique | Sort-Object)
    $sections.runtime.targetFrameworks = if ($allTfms.Count) { New-SkrFact $allTfms 'proven' @($projects | Where-Object { $_.targetFrameworks.Count } | ForEach-Object path) } else { New-SkrFact @() 'unknown' @() }
    $cpmEnabled = ($sharedProps['ManagePackageVersionsCentrally'] -eq 'true')
    $sections.runtime.centralPackageManagement = New-SkrFact $cpmEnabled $(if ($cpmFiles.Count) { 'proven' } else { 'inferred' }) @($cpmFiles | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
    $nullable = @($projects | Where-Object nullable | ForEach-Object { $_.nullable } | Select-Object -Unique)
    if ($sharedProps['Nullable']) { $nullable += $sharedProps['Nullable'] }
    $sections.runtime.nullable = if ($nullable.Count) { New-SkrFact (@($nullable | Select-Object -Unique) -join ', ') 'proven' @() } else { New-SkrFact 'disabled (default)' 'inferred' @() }

    # ---------- blazor ----------
    $hosting = [System.Collections.Generic.List[string]]::new(); $hostingEv = [System.Collections.Generic.List[string]]::new()
    $ev = Find-SkrContentMatch -Files $programFiles -Pattern '\bMapRazorComponents\s*<' -Repository $repo
    if ($ev) { $hosting.Add('Blazor Web App'); $hostingEv.AddRange([string[]]$ev) }
    $ev = Find-SkrContentMatch -Files $programFiles -Pattern '\bMapBlazorHub\s*\(' -Repository $repo
    if ($ev -and -not $hosting.Contains('Blazor Web App')) { $hosting.Add('Blazor Server (legacy)'); $hostingEv.AddRange([string[]]$ev) }
    $wasmProjects = @($projects | Where-Object kind -eq 'blazor-wasm')
    if ($wasmProjects.Count) {
        $hostedBy = @($projects | Where-Object { $_.kind -eq 'web' -and @($_.projectReferences | Where-Object { $wasmProjects.path -contains $_ }).Count })
        if (-not $hosting.Contains('Blazor Web App')) {
            $hosting.Add($(if ($hostedBy.Count) { 'Blazor WebAssembly (ASP.NET Core hosted)' } else { 'Blazor WebAssembly (standalone)' }))
        }
        $hostingEv.AddRange([string[]]@($wasmProjects.path))
    }
    $ev = @(Find-SkrContentMatch -Files ($cs + $razor) -Pattern '\bAddMauiBlazorWebView\s*\(|<BlazorWebView\b|AddWpfBlazorWebView|AddWindowsFormsBlazorWebView' -Repository $repo)
    if ($ev.Count) { $hosting.Add('Blazor Hybrid'); $hostingEv.AddRange([string[]]$ev) }
    $sections.blazor.hostingModel = if ($hosting.Count) { New-SkrFact @($hosting) 'proven' @($hostingEv) } else { New-SkrFact @() 'unknown' @() -Note 'No Blazor host found.' }

    $interactive = [System.Collections.Generic.List[string]]::new(); $interEv = @()
    $e1 = @(Find-SkrContentMatch -Files $programFiles -Pattern 'AddInteractiveServerComponents\s*\(|AddInteractiveServerRenderMode\s*\(' -Repository $repo)
    $e2 = @(Find-SkrContentMatch -Files $programFiles -Pattern 'AddInteractiveWebAssemblyComponents\s*\(|AddInteractiveWebAssemblyRenderMode\s*\(' -Repository $repo)
    if ($e1.Count) { $interactive.Add('Server'); $interEv += $e1 }
    if ($e2.Count) { $interactive.Add('WebAssembly'); $interEv += $e2 }
    if ($hosting.Contains('Blazor Web App')) {
        $sections.blazor.interactivity = if ($interactive.Count) { New-SkrFact @($interactive) 'proven' $interEv } else { New-SkrFact @('None (static SSR only)') 'proven' @($hostingEv) }
    }
    elseif ($hosting.Count) { $sections.blazor.interactivity = New-SkrFact @('Always interactive (pre-.NET 8 model / WASM / Hybrid)') 'inferred' @($hostingEv) }
    else { $sections.blazor.interactivity = New-SkrFact @() 'unknown' @() }

    $globalRm = Get-SkrFirstCapture -Files $hostFiles -Pattern '<Routes[^>]*@rendermode\s*=\s*"?@?([A-Za-z.()]+)' -Repository $repo
    $pageRm = @(Find-SkrContentMatch -Files $razor -Pattern '^\s*@rendermode\s+\S+' -Repository $repo -Limit 20)
    $renderModes = @(foreach ($f in $razor) {
            $t = $script:SkrContentCache[$f.FullName]
            foreach ($m in [regex]::Matches($t, '(?m)^\s*@rendermode\s+[^\r\n]*?(Interactive(?:Server|WebAssembly|Auto))')) { $m.Groups[1].Value }
        }) | Select-Object -Unique
    if ($globalRm) {
        $sections.blazor.renderModeScope = New-SkrFact 'global' 'proven' @($globalRm.Evidence)
        $sections.blazor.globalRenderMode = New-SkrFact ($globalRm.Value -replace '^RenderMode\.', '') 'proven' @($globalRm.Evidence)
    }
    elseif ($pageRm.Count) {
        $sections.blazor.renderModeScope = New-SkrFact 'per-page/component' 'proven' $pageRm
        $sections.blazor.pageRenderModes = New-SkrFact @($renderModes) 'proven' $pageRm
    }
    elseif ($hosting.Contains('Blazor Web App')) { $sections.blazor.renderModeScope = New-SkrFact 'none (static SSR)' 'inferred' @($hostingEv) }
    else { $sections.blazor.renderModeScope = New-SkrFact 'n/a' 'inferred' @() }
    $noPrerender = @(Find-SkrContentMatch -Files ($razor + $cs) -Pattern 'prerender\s*:\s*false' -Repository $repo)
    $sections.blazor.prerendering = if ($noPrerender.Count) { New-SkrFact 'disabled in some places' 'proven' $noPrerender } elseif ($hosting.Contains('Blazor Web App')) { New-SkrFact 'enabled (default)' 'inferred' @() } else { New-SkrFact 'n/a' 'inferred' @() }
    $persist = @(Find-SkrContentMatch -Files ($razor + $cs) -Pattern 'PersistentComponentState|\[PersistentState\]' -Repository $repo)
    $sections.blazor.prerenderStatePersistence = New-SkrFact ([bool]$persist.Count) $(if ($persist.Count) { 'proven' } else { 'inferred' }) $persist

    # ---------- radzen ----------
    $radzenProjects = @($projects | Where-Object { $_.packages.Contains('Radzen.Blazor') })
    $radzenVersions = @($radzenProjects | ForEach-Object { $_.packages['Radzen.Blazor'] } | Select-Object -Unique)
    $radzenEv = @($radzenProjects | ForEach-Object { $_.packageEvidence['Radzen.Blazor'] })
    $radzenTags = @(Find-SkrContentMatch -Files $razor -Pattern '<Radzen[A-Z]\w*' -Repository $repo -Limit 3)
    $sections.radzen.installed = New-SkrFact ([bool]$radzenProjects.Count) 'proven' $radzenEv
    if ($radzenProjects.Count) {
        $sections.radzen.version = if ($radzenVersions.Count -eq 1 -and $radzenVersions[0]) { New-SkrFact $radzenVersions[0] 'proven' $radzenEv } else { New-SkrFact (@($radzenVersions | Where-Object { $_ }) -join ', ') $(if ($radzenVersions -contains $null) { 'unknown' } else { 'proven' }) $radzenEv }
        $sections.radzen.projects = New-SkrFact @($radzenProjects.path) 'proven' $radzenEv
        if (@($radzenVersions | Where-Object { $_ }).Count -gt 1) { & $addHealth 'RDZ-H05' 'major' "Multiple Radzen.Blazor versions referenced: $($radzenVersions -join ', ')." $radzenEv }

        $reg = @(Find-SkrContentMatch -Files $programFiles -Pattern '\bAddRadzenComponents\s*\(' -Repository $repo)
        $regIndividual = @(Find-SkrContentMatch -Files $programFiles -Pattern 'Add(Scoped|Singleton|Transient)\s*<\s*(Radzen\.)?(DialogService|NotificationService|TooltipService|ContextMenuService)\s*>' -Repository $repo)
        $sections.radzen.serviceRegistration = if ($reg.Count) { New-SkrFact 'AddRadzenComponents' 'proven' $reg } elseif ($regIndividual.Count) { New-SkrFact 'individual services' 'proven' $regIndividual } else { New-SkrFact 'missing' 'inferred' @() }
        $theme = Get-SkrFirstCapture -Files ($hostFiles + $layoutFiles) -Pattern '<RadzenTheme[^>]*Theme\s*=\s*"([^"]+)"' -Repository $repo
        $themeCss = Get-SkrFirstCapture -Files ($hostFiles + $layoutFiles) -Pattern '_content/Radzen\.Blazor/css/([\w-]+)\.css' -Repository $repo
        $sections.radzen.theme = if ($theme) { New-SkrFact $theme.Value 'proven' @($theme.Evidence) -Note 'RadzenTheme component' } elseif ($themeCss) { New-SkrFact $themeCss.Value 'proven' @($themeCss.Evidence) -Note 'CSS link' } else { New-SkrFact $null 'unknown' @() }
        $script = @(Find-SkrContentMatch -Files ($hostFiles + $layoutFiles) -Pattern '_content/Radzen\.Blazor/Radzen\.Blazor(\.min)?\.js' -Repository $repo)
        $sections.radzen.script = New-SkrFact ([bool]$script.Count) $(if ($script.Count) { 'proven' } else { 'inferred' }) $script
        $hostCmp = Get-SkrFirstCapture -Files ($layoutFiles + $hostFiles + $razor) -Pattern '<RadzenComponents\b([^>]*)/?>' -Repository $repo
        $legacyHost = @(Find-SkrContentMatch -Files ($layoutFiles + $razor) -Pattern '<Radzen(Dialog|Notification|ContextMenu|Tooltip)\s*/>' -Repository $repo)
        if ($hostCmp) {
            $rm = [regex]::Match($hostCmp.Value, '@rendermode\s*=\s*"?@?([A-Za-z.]+)').Groups[1].Value
            $sections.radzen.componentHost = New-SkrFact $(if ($rm) { "RadzenComponents (@rendermode $rm)" } else { 'RadzenComponents' }) 'proven' @($hostCmp.Evidence)
        }
        elseif ($legacyHost.Count) { $sections.radzen.componentHost = New-SkrFact 'individual hosts (RadzenDialog/RadzenNotification/...)' 'proven' $legacyHost }
        else { $sections.radzen.componentHost = New-SkrFact 'missing' 'inferred' @() }
        $imports = @(Find-SkrContentMatch -Files $importFiles -Pattern '@using\s+Radzen(\.Blazor)?\s*$' -Repository $repo)
        $sections.radzen.imports = New-SkrFact ([bool]$imports.Count) $(if ($imports.Count) { 'proven' } else { 'inferred' }) $imports

        # component usage
        $usage = @{}
        foreach ($f in $razor) {
            foreach ($m in [regex]::Matches($script:SkrContentCache[$f.FullName], '<(Radzen[A-Z]\w*)')) { $usage[$m.Groups[1].Value] = 1 + [int]$usage[$m.Groups[1].Value] }
        }
        $top = @($usage.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | ForEach-Object { "$($_.Key) ($($_.Value))" })
        $sections.radzen.componentUsage = New-SkrFact $top $(if ($top.Count) { 'proven' } else { 'inferred' }) $radzenTags
        # wrappers: non-Radzen components that render a Radzen component and expose parameters
        $wrappers = @($razor | Where-Object {
                $t = $script:SkrContentCache[$_.FullName]
                $_.BaseName -notmatch '^(App|Routes|_Imports|.*Layout|.*Page|Index|Home|Error|NotFound)$' -and
                $_.FullName -match '[\\/](Shared|Components|Controls|Common|UI)[\\/]' -and
                $t -match '<Radzen(DataGrid|DropDown|DropDownDataGrid|TemplateForm|Button|Dialog|TextBox|DatePicker|Numeric|AutoComplete)\b' -and
                $t -match '\[Parameter\]' -and $t -notmatch '@page\s'
            } | Select-Object -First 12 | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
        $sections.radzen.wrappers = New-SkrFact $wrappers $(if ($wrappers.Count) { 'inferred' } else { 'inferred' }) $wrappers -Note 'Heuristic: shared components that wrap Radzen components and expose parameters. Verify before reuse.'
        $services = @(Find-SkrContentMatch -Files ($razor + $cs) -Pattern '(@inject|\[Inject\][^\n]*)\s*(DialogService|NotificationService)\b' -Repository $repo -Limit 5)
        $sections.radzen.servicesUsed = New-SkrFact ([bool]$services.Count) $(if ($services.Count) { 'proven' } else { 'inferred' }) $services

        # health
        if ($sections.radzen.serviceRegistration.value -eq 'missing' -and $programFiles.Count) { & $addHealth 'RDZ-H01' 'blocker' 'Radzen.Blazor is referenced but no Radzen service registration (AddRadzenComponents) was found.' $radzenEv }
        if ($sections.radzen.componentHost.value -eq 'missing' -and $services.Count) { & $addHealth 'RDZ-H02' 'major' 'DialogService/NotificationService are used but no <RadzenComponents /> host was found; dialogs and notifications will not render.' $services }
        if (-not $theme -and -not $themeCss -and $hostFiles.Count) { & $addHealth 'RDZ-H03' 'major' 'No Radzen theme (<RadzenTheme> or theme CSS) found in the host page.' @($hostFiles | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName }) }
        if (-not $script.Count -and $hostFiles.Count) { & $addHealth 'RDZ-H04' 'major' 'Radzen.Blazor.js script reference not found in the host page.' @($hostFiles | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName }) }
        if (-not $imports.Count -and $importFiles.Count) { & $addHealth 'RDZ-H07' 'minor' '_Imports.razor does not import Radzen / Radzen.Blazor.' @($importFiles | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName }) }
        if ($hosting.Contains('Blazor Web App') -and -not $interactive.Count -and $radzenTags.Count) { & $addHealth 'RND-H01' 'major' 'Blazor Web App without interactive render modes, but Radzen components are used. Interactive components will not respond to events.' $radzenTags }
        if ($hostCmp -and $sections.blazor.renderModeScope.value -ne 'global' -and $hosting.Contains('Blazor Web App') -and $hostCmp.Value -notmatch '@rendermode') { & $addHealth 'RND-H02' 'major' '<RadzenComponents /> has no @rendermode while render modes are applied per page; the host may not be interactive.' @($hostCmp.Evidence) }
    }
    else {
        foreach ($k in 'version', 'serviceRegistration', 'theme', 'componentHost') { $sections.radzen[$k] = New-SkrFact $null 'unknown' @() -Note 'Radzen.Blazor is not referenced.' }
        & $addHealth 'RDZ-H06' 'info' 'Radzen.Blazor is not referenced by any project in scope. A Radzen feature needs an approved installation slice.' @()
    }

    # ---------- declarative rules ----------
    $ruleDocs = @(Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'discovery' 'detection-rules.json'))
    $localRules = Join-Path $stateRoot 'local' 'detection-rules.local.json'
    if (Test-Path $localRules) { $ruleDocs += Read-SkrJson -Path $localRules }
    $collected = @{}
    $nonTestProjects = @($projects | Where-Object { -not $_.isTest })
    foreach ($rule in @($ruleDocs | ForEach-Object rules)) {
        $hits = @()
        switch ($rule.kind) {
            'package' {
                foreach ($p in $projects) {
                    foreach ($id in $p.packages.Keys) { if ($id -match $rule.pattern) { $hits += $p.packageEvidence[$id] } }
                }
            }
            'file' {
                $hits = @(Get-SkrRepositoryFile -Repository $repo -Include '*' | Where-Object { $_.Name -match $rule.pattern } | Select-Object -First 5 | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
            }
            'content' {
                $globs = if ($rule.files) { @($rule.files) } else { @('*.cs', '*.razor') }
                $candidates = @($sourceFiles | Where-Object { $n = $_.Name; @($globs | Where-Object { $n -like $_ }).Count })
                # testing facts come from test projects; others from non-test code
                if ($rule.fact -notlike 'testing.*') {
                    $testDirs = @($projects | Where-Object isTest | ForEach-Object directory)
                    $candidates = @($candidates | Where-Object { $fp = $_.FullName; -not ($testDirs | Where-Object { $fp.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar) }) })
                }
                $hits = @(Find-SkrContentMatch -Files $candidates -Pattern $rule.pattern -Repository $repo -Limit 5)
            }
        }
        if (-not $hits.Count) { continue }
        if (-not $collected.ContainsKey($rule.fact)) { $collected[$rule.fact] = [ordered]@{} }
        $bucket = $collected[$rule.fact]
        if (-not $bucket.Contains($rule.value)) { $bucket[$rule.value] = @{ confidence = $rule.confidence; evidence = [System.Collections.Generic.List[string]]::new() } }
        elseif ($rule.confidence -eq 'proven') { $bucket[$rule.value].confidence = 'proven' }
        foreach ($h in $hits) { if ($bucket[$rule.value].evidence.Count -lt 6 -and -not $bucket[$rule.value].evidence.Contains($h)) { $bucket[$rule.value].evidence.Add($h) } }
    }
    foreach ($factName in $collected.Keys) {
        $section, $key = $factName -split '\.', 2
        $bucket = $collected[$factName]
        $conf = if (@($bucket.Values | Where-Object { $_.confidence -eq 'proven' }).Count) { 'proven' } else { 'inferred' }
        $sections[$section][$key] = New-SkrFact @($bucket.Keys) $conf @($bucket.Values | ForEach-Object { $_.evidence } | Select-Object -First 8)
    }
    foreach ($k in 'mediator', 'validation', 'persistence', 'apiStyle', 'httpClients', 'errorHandling', 'state', 'localization', 'logging') {
        if (-not $sections.architecture.Contains($k)) { $sections.architecture[$k] = New-SkrFact @() 'unknown' @() }
    }
    foreach ($k in 'authentication', 'authorization') { if (-not $sections.security.Contains($k)) { $sections.security[$k] = New-SkrFact @() 'unknown' @() } }
    foreach ($k in 'framework', 'component', 'e2e') { if (-not $sections.testing.Contains($k)) { $sections.testing[$k] = New-SkrFact @() 'unknown' @() } }

    # project graph / UI-to-backend summary
    $sections.architecture.projectGraph = New-SkrFact @($nonTestProjects | ForEach-Object {
            $refs = @($_.projectReferences | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) })
            if ($refs.Count) { "$($_.name) [$($_.kind)] -> $($refs -join ', ')" } else { "$($_.name) [$($_.kind)]" }
        }) 'proven' @($nonTestProjects | ForEach-Object path)
    $sections.testing.testProjects = New-SkrFact @($projects | Where-Object isTest | ForEach-Object path) 'proven' @()

    # ---------- solution health ----------
    if ($selection -eq 'ambiguous') { & $addHealth 'REPO-H01' 'blocker' "Multiple solutions found ($($solutions -join ', ')). Run 'speckit-radzen detect -Solution <path>'." $solutions }
    if (-not $projects.Count) { & $addHealth 'REPO-H02' 'major' 'No .csproj projects found in scope.' @() }

    $profileObject = [ordered]@{
        schemaVersion = 1
        generatedAt   = Get-SkrTimestamp
        kitVersion    = Get-SkrKitVersion
        fingerprint   = Get-SkrProfileFingerprint -Repository $repo
        repository    = [ordered]@{ solutions = @($solutions); solution = $selected; solutionSelection = $selection; instructions = @($instructions); agentEnvironment = @($agentEnv) }
        runtime       = $sections.runtime
        blazor        = $sections.blazor
        radzen        = $sections.radzen
        architecture  = $sections.architecture
        security      = $sections.security
        testing       = $sections.testing
        health        = $health.ToArray()
        projects      = @($projects | ForEach-Object {
                [ordered]@{ path = $_.path; name = $_.name; sdk = $_.sdk; targetFrameworks = @($_.targetFrameworks); kind = $_.kind; packages = $_.packages; projectReferences = @($_.projectReferences); isTest = $_.isTest }
            })
    }
    $script:SkrContentCache = @{}

    $json = $profileObject | ConvertTo-Json -Depth 20
    $errors = Test-SkrJsonSchema -Json $json -SchemaName 'profile'
    if ($errors.Count) { throw "Generated profile does not match the schema: $($errors -join '; ')" }
    if (-not $NoWrite) {
        Write-SkrText -Path (Join-Path $stateRoot 'profile.json') -Content $json
        Write-SkrText -Path (Join-Path $stateRoot 'profile.md') -Content (ConvertTo-SkrProfileMarkdown -Doc ($json | ConvertFrom-Json -Depth 20 -DateKind String))
    }
    return ($json | ConvertFrom-Json -Depth 20 -DateKind String)
}

function ConvertTo-SkrProfileMarkdown {
    param([Parameter(Mandatory)] $Doc)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('# Project Profile')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("Generated $($Doc.generatedAt) by ``speckit-radzen detect`` (kit $($Doc.kitVersion)). Fingerprint ``$($Doc.fingerprint.Substring(0, 12))``. Do not edit; re-run detection instead.")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('Confidence: **proven** = direct evidence · *inferred* = indirect signal · unknown = not detected. Verify inferred facts that matter for your feature.')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('## Health')
    $null = $sb.AppendLine()
    if (@($Doc.health).Count) { $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($Doc.health) -Columns 'id', 'severity', 'message', 'evidence')) }
    else { $null = $sb.AppendLine('No problems detected.') }
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('## Repository')
    $null = $sb.AppendLine()
    $r = $Doc.repository
    $null = $sb.AppendLine("- **Solutions:** $(if (@($r.solutions).Count) { @($r.solutions) -join ', ' } else { 'none' })")
    $null = $sb.AppendLine("- **Selected solution:** $(if ($r.solution) { $r.solution } else { '—' }) ($($r.solutionSelection))")
    $null = $sb.AppendLine("- **Repository instructions:** $(if (@($r.instructions).Count) { @($r.instructions) -join ', ' } else { 'none' })")
    $null = $sb.AppendLine("- **Agent environment:** $(if (@($r.agentEnvironment).Count) { @($r.agentEnvironment) -join ', ' } else { 'none' })")
    foreach ($section in 'runtime', 'blazor', 'radzen', 'architecture', 'security', 'testing') {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("## $((Get-Culture).TextInfo.ToTitleCase($section))")
        $null = $sb.AppendLine()
        $rows = foreach ($p in $Doc.$section.PSObject.Properties) {
            $v = $p.Value.value
            $display = if ($null -eq $v) { '—' } elseif ($v -is [array]) { if ($v.Count) { $v -join '; ' } else { '—' } } else { "$v" }
            $conf = switch ($p.Value.confidence) { 'proven' { '**proven**' } 'inferred' { '*inferred*' } default { 'unknown' } }
            $evidence = @($p.Value.evidence) | Select-Object -First 3
            $note = if ($p.Value.PSObject.Properties['note']) { " ($($p.Value.note))" } else { '' }
            [pscustomobject]@{ Fact = $p.Name; Value = "$display$note"; Confidence = $conf; Evidence = ($evidence -join ', ') }
        }
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($rows) -Columns 'Fact', 'Value', 'Confidence', 'Evidence'))
    }
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('## Projects')
    $null = $sb.AppendLine()
    $prow = foreach ($p in $Doc.projects) {
        $keyPkgs = @($p.packages.PSObject.Properties | Where-Object { $_.Name -match '^(Radzen|Microsoft\.AspNetCore\.Components|Microsoft\.EntityFrameworkCore$|MediatR|FluentValidation|bunit|xunit|NUnit|MSTest|Microsoft\.Identity\.Web$)' } | ForEach-Object { "$($_.Name) $($_.Value)" })
        [pscustomobject]@{ Project = $p.path; Kind = $p.kind; TFM = (@($p.targetFrameworks) -join ';'); 'Key packages' = ($keyPkgs -join ', '); References = (@($p.projectReferences | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }) -join ', ') }
    }
    if (@($prow).Count) { $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($prow) -Columns 'Project', 'Kind', 'TFM', 'Key packages', 'References')) } else { $null = $sb.AppendLine('No projects found.') }
    return $sb.ToString()
}
