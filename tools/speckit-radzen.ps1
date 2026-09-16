#Requires -Version 7.4
<#
.SYNOPSIS
    Spec Kit Radzen command-line entry point for people and AI agents.
.DESCRIPTION
    Usage: pwsh .speckit/radzen/tools/speckit-radzen.ps1 <command> [options]
    Run 'help' for the command list. Add -Json to any command for machine-readable output.
#>
param(
    [Parameter(Position = 0)][string] $Command = 'help',
    [Parameter(Position = 1, ValueFromRemainingArguments)][object[]] $Arguments
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SpecKitRadzen' 'SpecKitRadzen.psd1') -Force

# ---- argument parsing: -Name value, -Switch, positional ----
$named = @{}
$positional = [System.Collections.Generic.List[string]]::new()
$switchNames = @('Json', 'All', 'Strict', 'Probe', 'ListManual', 'Force', 'NoWrite', 'SkipTests', 'CompileVerified', 'FallbackApproved', 'Yes', 'WhatIf', 'SkipUserLevel', 'KeepLocal', 'EnableHooks')
for ($i = 0; $i -lt @($Arguments).Count; $i++) {
    $a = "$($Arguments[$i])"
    if ($a -match '^--?([A-Za-z][\w-]*)(?:[:=](.*))?$') {
        $name = ($Matches[1] -replace '-(\w)', { $_.Groups[1].Value.ToUpperInvariant() })
        $name = $name.Substring(0, 1).ToUpperInvariant() + $name.Substring(1)
        if ($null -ne $Matches[2]) { $named[$name] = $Matches[2] }
        elseif ($switchNames -contains $name) { $named[$name] = $true }
        elseif ($i + 1 -lt @($Arguments).Count) { $named[$name] = "$($Arguments[$i + 1])"; $i++ }
        else { $named[$name] = $true }
    }
    else { $positional.Add($a) }
}
$json = [bool]$named['Json']; $named.Remove('Json')
function Get-Arg([string] $Name, $Default = $null) { if ($named.ContainsKey($Name)) { $named[$Name] } else { $Default } }
function Get-List([string] $Name) { $v = Get-Arg $Name; if ($null -eq $v) { @() } else { @("$v" -split '\s*,\s*' | Where-Object { $_ }) } }
function Out-Result($Object, [scriptblock] $Human) {
    if ($json) { $Object | ConvertTo-Json -Depth 20 }
    else { & $Human $Object }
}
$repo = Get-Arg 'Repository' (Get-Location).Path
$exit = 0

switch ($Command.ToLowerInvariant()) {
    'help' {
        @'
Spec Kit Radzen — commands (add -Json for machine-readable output)

  status                          Kit version, profile, MCP check and all features
  detect [-Solution path]         Automatic project detection -> .speckit/radzen/profile.{json,md}
  verify-install                  Check managed files against the install manifest
  mcp-check [-Probe]              Radzen MCP configuration (and optional endpoint probe)
  baseline [-SkipTests]           Record build warnings / failing tests before changes
  new-feature "<name>"            Create specs/NNN-name with templates and state
  state [-Feature NNN] [-All]     Feature state and next step
        [-McpAvailability available|unavailable|quota-exhausted] [-Note text]
  phase <phase> [-Feature NNN] [-Force -Note why]
                                  Move to a phase (entry gates enforced)
  phase implement -CompleteSlice S-01 [-Feature NNN]
  lint [-Feature NNN] [-Artifact spec,plan,...] [-Strict]
  analyze [-Feature NNN]          Cross-artifact consistency -> analysis.md
  evidence add -Component X -Members a,b -Question q -Source mcp|compiler|project|docs|model
               -Summary s [-Query q] [-ProjectEvidence file:line] [-Supersedes MCP-001]
               [-FallbackApproved -FallbackReason r] [-Status conflict] [-Feature NNN]
  evidence list [-Feature NNN]
  scan [-Feature NNN] [-All] [-Path p1,p2] [-Base ref] [-ListManual]
  gate G0..G8 [-Feature NNN] [-Slice S-01]
  install|update|uninstall        Lifecycle (see docs/user-guide.md)
  version                         Kit version

Exit codes: 0 ok/pass · 1 fail · 2 pass with waivers · 3 cannot evaluate
'@ | Write-Output
    }
    'version' { Out-Result ([pscustomobject]@{ version = (Get-Module SpecKitRadzen).Version.ToString() }) { param($o) $o.version } }
    'detect' {
        $p = Get-SkrProjectProfile -Repository $repo -Solution (Get-Arg 'Solution')
        Out-Result $p {
            param($o)
            "Profile written: .speckit/radzen/profile.md"
            "  Solution : $($o.repository.solution) ($($o.repository.solutionSelection))"
            "  Hosting  : $(@($o.blazor.hostingModel.value) -join ', ')  Render: $($o.blazor.renderModeScope.value) $($o.blazor.globalRenderMode.value)"
            "  Radzen   : $($o.radzen.version.value)  registration=$($o.radzen.serviceRegistration.value) host=$($o.radzen.componentHost.value) theme=$($o.radzen.theme.value)"
            foreach ($h in @($o.health)) { "  [$($h.severity)] $($h.id): $($h.message)" }
        }
        if (@($p.health | Where-Object severity -eq 'blocker').Count) { $exit = 1 }
    }
    'verify-install' {
        $r = Test-SpecKitRadzenInstall -Repository $repo
        Out-Result $r { param($o) if ($o.Healthy) { "Install OK (kit $($o.KitVersion), agents: $($o.Agents -join ', '))" } else { 'Install problems:'; $o.Problems | ForEach-Object { "  - $_" } } }
        if (-not $r.Healthy) { $exit = 1 }
    }
    'mcp-check' {
        $r = Test-SkrMcpConfiguration -Repository $repo -Probe:([bool](Get-Arg 'Probe' $false)) -SkipUserLevel:([bool](Get-Arg 'SkipUserLevel' $false))
        Out-Result $r {
            param($o)
            "MCP status: $($o.Status)"
            foreach ($s in $o.Servers) { "  $($s.Scope) $($s.Client) $($s.File) server=$($s.Server) key=$($s.KeyKind)$(if ($s.Issue) { " — $($s.Issue)" })" }
            if ($o.Probe) { "  probe: $($o.Probe.Status) ($($o.Probe.Detail))" }
            "  $($o.Advice)"
        }
        if ($r.Status -eq 'secret-in-repo') { $exit = 1 }
    }
    'baseline' {
        $r = New-SkrBuildBaseline -Repository $repo -SkipTests:([bool](Get-Arg 'SkipTests' $false))
        Out-Result $r { param($o) "Baseline: build $(if ($o.BuildSucceeded) { 'OK' } else { 'FAILED' }), $($o.Warnings) warning(s), $($o.FailingTests) failing test(s) -> $($o.Path)" }
        if (-not $r.BuildSucceeded) { $exit = 1 }
    }
    'new-feature' {
        $name = if ($positional.Count) { $positional -join ' ' } else { Get-Arg 'Name' }
        if (-not $name) { throw 'Usage: new-feature "<name>"' }
        $r = New-SkrFeature -Name $name -Repository $repo
        Out-Result $r { param($o) "Created $($o.Id) at $($o.Path)"; "Next: detect, mcp-check, state -Feature $($o.Number) -McpAvailability …, gate G0 -Feature $($o.Number)" }
    }
    'state' {
        if (Get-Arg 'McpAvailability') {
            $r = Set-SkrFeaturePhase -Feature (Get-Arg 'Feature') -McpAvailability (Get-Arg 'McpAvailability') -Note (Get-Arg 'Note') -Repository $repo
        }
        elseif (Get-Arg 'All') { $r = @(Get-SkrFeatureState -All -Repository $repo) }
        else { $r = Get-SkrFeatureState -Feature (Get-Arg 'Feature') -Repository $repo }
        Out-Result $r {
            param($o)
            if ($o -is [array]) { $o | Format-Table -AutoSize | Out-String -Width 200 }
            else {
                "Feature : $($o.Feature)"; "Phase   : $($o.Phase)"; "MCP     : $($o.Mcp)"
                "Gates   : $((@($o.Gates.Keys | Sort-Object | ForEach-Object { "$_=$($o.Gates[$_].status)" })) -join ' ')"
                if ($o.Slices.Count) { "Slices  : $((@($o.Slices.Keys | Sort-Object | ForEach-Object { "$_=$($o.Slices[$_].status)" })) -join ' ')" }
                "Next    : $($o.NextStep)"
            }
        }
    }
    'phase' {
        $phase = if ($positional.Count) { $positional[0] } else { Get-Arg 'Phase' }
        $params = @{ Repository = $repo; Feature = (Get-Arg 'Feature'); Note = (Get-Arg 'Note'); Force = [bool](Get-Arg 'Force' $false) }
        if (Get-Arg 'CompleteSlice') { $params.CompleteSlice = Get-Arg 'CompleteSlice' }
        if ($phase -and -not ($phase -eq 'implement' -and $params.CompleteSlice)) { $params.Phase = $phase }
        $r = Set-SkrFeaturePhase @params
        Out-Result $r { param($o) "Phase: $($o.Phase). Next: $($o.NextStep)" }
    }
    'lint' {
        $r = @(Test-SkrArtifact -Feature (Get-Arg 'Feature') -Artifact (Get-List 'Artifact') -Strict:([bool](Get-Arg 'Strict' $false)) -Repository $repo)
        Out-Result $r { param($o) if (-not $o.Count) { 'Lint: clean' } else { $o | Format-Table artifact, severity, rule, message -AutoSize -Wrap | Out-String -Width 200 } }
        if (@($r | Where-Object severity -eq 'error').Count) { $exit = 1 }
    }
    'analyze' {
        $r = @(Invoke-SkrAnalysis -Feature (Get-Arg 'Feature') -Repository $repo)
        Out-Result $r { param($o) if (-not $o.Count) { 'Analysis: no findings (analysis.md updated)' } else { $o | Format-Table severity, rule, message -AutoSize -Wrap | Out-String -Width 200 } }
        if (@($r | Where-Object severity -eq 'error').Count) { $exit = 1 }
    }
    'evidence' {
        $sub = if ($positional.Count) { $positional[0] } else { 'list' }
        if ($sub -eq 'add') {
            $params = @{
                Repository = $repo; Feature = (Get-Arg 'Feature'); Component = (Get-Arg 'Component'); Members = (Get-List 'Members')
                Question = (Get-Arg 'Question'); Query = (Get-Arg 'Query'); Source = (Get-Arg 'Source'); Summary = (Get-Arg 'Summary')
                Server = (Get-Arg 'Server'); Tool = (Get-Arg 'Tool'); RadzenVersion = (Get-Arg 'RadzenVersion'); ProjectEvidence = (Get-List 'ProjectEvidence')
                CompileVerified = [bool](Get-Arg 'CompileVerified' $false); FallbackApproved = [bool](Get-Arg 'FallbackApproved' $false)
                FallbackReason = (Get-Arg 'FallbackReason'); Force = [bool](Get-Arg 'Force' $false)
            }
            if (Get-Arg 'Status') { $params.Status = Get-Arg 'Status' }
            if (Get-Arg 'Supersedes') { $params.Supersedes = Get-Arg 'Supersedes' }
            $r = Add-SkrMcpEvidence @params
            Out-Result $r { param($o) "Recorded $($o.id): $($o.component) [$($o.members -join ', ')] source=$($o.source) rank=$($o.rank)" }
        }
        else {
            $f = Get-SkrFeatureState -Feature (Get-Arg 'Feature') -Repository $repo
            $doc = Get-Content (Join-Path $f.Path 'mcp-evidence.json') -Raw | ConvertFrom-Json
            Out-Result @($doc.entries) { param($o) if (-not $o.Count) { 'No evidence recorded.' } else { $o | Format-Table id, component, @{ n = 'members'; e = { $_.members -join ',' } }, source, rank, compileVerified, status -AutoSize | Out-String -Width 200 } }
        }
    }
    'scan' {
        if (Get-Arg 'ListManual') {
            $r = Invoke-SkrAntiPatternScan -Repository $repo -ListManual
            Out-Result $r { param($o) 'Manual-review anti-patterns (G7):'; $o | Format-Table -AutoSize | Out-String -Width 200 }
        }
        else {
            $params = @{ Repository = $repo; All = [bool](Get-Arg 'All' $false) }
            if (Get-Arg 'Feature') { $params.Feature = Get-Arg 'Feature' }
            if (Get-Arg 'Base') { $params.Base = Get-Arg 'Base' }
            if (Get-Arg 'Path') { $params.Path = Get-List 'Path' }
            $r = Invoke-SkrAntiPatternScan @params
            Out-Result $r {
                param($o)
                "Scanned $($o.scannedFiles) file(s) ($($o.scope)): blocker $($o.summary.blocker), major $($o.summary.major), minor $($o.summary.minor), waived $($o.summary.waived)"
                foreach ($x in ($o.findings | Where-Object { -not $_.waived })) { "  [$($x.severity)] $($x.rule) $($x.file):$($x.line) $($x.message)" }
            }
            $cfgFail = @('blocker', 'major')
            if (@($r.findings | Where-Object { -not $_.waived -and $cfgFail -contains $_.severity }).Count) { $exit = 1 }
        }
    }
    'gate' {
        $gate = if ($positional.Count) { $positional[0].ToUpperInvariant() } else { Get-Arg 'Gate' }
        $params = @{ Gate = $gate; Repository = $repo; Feature = (Get-Arg 'Feature') }
        if (Get-Arg 'Slice') { $params.Slice = Get-Arg 'Slice' }
        $r = Invoke-SkrQualityGate @params
        Out-Result $r {
            param($o)
            "Gate $($o.gate) ($($o.name)): $($o.status.ToUpperInvariant())$(if ($o.slice) { " [$($o.slice)]" }) — specs/$($o.feature)/gates/$($o.gate).json"
            foreach ($c in $o.checks) {
                "  [$($c.status)] $($c.check): $($c.message)"
                foreach ($e in @($c.evidence | Select-Object -First 10)) { "      $e" }
            }
        }
        $exit = $r.exitCode
    }
    'status' {
        $ver = (Get-Module SpecKitRadzen).Version.ToString()
        $prof = $null
        $pp = Join-Path $repo '.speckit' 'radzen' 'profile.json'
        if (Test-Path $pp) { $prof = Get-Content $pp -Raw | ConvertFrom-Json }
        $features = @(try { Get-SkrFeatureState -All -Repository $repo } catch { @() })
        $mcp = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
        $o = [pscustomobject]@{ kitVersion = $ver; profileGeneratedAt = $prof.generatedAt; health = @($prof.health); mcp = $mcp.Status; features = $features }
        Out-Result $o {
            param($s)
            "Spec Kit Radzen $($s.kitVersion)"
            "Profile : $(if ($s.profileGeneratedAt) { $s.profileGeneratedAt } else { 'missing — run detect' })"
            foreach ($h in $s.health) { "  [$($h.severity)] $($h.id): $($h.message)" }
            "MCP     : $($s.mcp)"
            if ($s.features.Count) { $s.features | Format-Table -AutoSize | Out-String -Width 200 } else { 'Features: none' }
        }
    }
    'install' { $r = Install-SpecKitRadzen -Repository $repo -Agents (Get-List 'Agents') -McpClient (Get-List 'McpClient') -Force:([bool](Get-Arg 'Force' $false)) -Yes:([bool](Get-Arg 'Yes' $false)) -EnableHooks:([bool](Get-Arg 'EnableHooks' $false)) -WhatIf:([bool](Get-Arg 'WhatIf' $false)); Out-Result $r { param($o) $o.Summary } }
    'update' { $r = Update-SpecKitRadzen -Repository $repo -Source (Get-Arg 'Source') -Force:([bool](Get-Arg 'Force' $false)) -WhatIf:([bool](Get-Arg 'WhatIf' $false)); Out-Result $r { param($o) $o.Summary } }
    'uninstall' { $r = Uninstall-SpecKitRadzen -Repository $repo -KeepLocal:([bool](Get-Arg 'KeepLocal' $true)) -WhatIf:([bool](Get-Arg 'WhatIf' $false)); Out-Result $r { param($o) $o.Summary } }
    default { Write-Error "Unknown command '$Command'. Run 'help'."; $exit = 3 }
}
exit $exit
