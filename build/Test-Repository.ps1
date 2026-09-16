#Requires -Version 7.4
<#
.SYNOPSIS
    Repository self-checks: JSON schemas, catalog, internal Markdown links, secrets, obsolete V1 files, version consistency.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$problems = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
function Rel([string] $p) { [System.IO.Path]::GetRelativePath($root, $p) -replace '\\', '/' }

# 1. Schema validation of shipped data
$checks = @(
    @('core/antipatterns/rules.json', 'antipattern-rules'),
    @('core/discovery/detection-rules.json', 'detection-rules'),
    @('core/config/config.default.json', 'config'),
    @('core/examples/specs/001-customer-search/state.json', 'state'),
    @('core/examples/specs/001-customer-search/mcp-evidence.json', 'mcp-evidence')
)
foreach ($c in $checks) {
    $ok = Test-Json -Path (Join-Path $root $c[0]) -SchemaFile (Join-Path $root 'core' 'schemas' "$($c[1]).schema.json") -ErrorAction SilentlyContinue
    if (-not $ok) { $problems.Add("$($c[0]) does not match schema $($c[1])") }
}
foreach ($f in Get-ChildItem (Join-Path $root 'core') -Recurse -Filter '*.json') {
    try { $null = Get-Content $f.FullName -Raw | ConvertFrom-Json -Depth 64 } catch { $problems.Add("Invalid JSON: $(Rel $f.FullName)") }
}

# 2. Regex validity of rules
foreach ($r in (Get-Content (Join-Path $root 'core/antipatterns/rules.json') -Raw | ConvertFrom-Json).rules) {
    foreach ($k in 'pattern', 'requires', 'unless', 'unlessInFile') {
        if ($r.PSObject.Properties[$k]) { try { $null = [regex]::new($r.$k) } catch { $problems.Add("$($r.id).$k is not a valid regex") } }
    }
}
foreach ($r in (Get-Content (Join-Path $root 'core/discovery/detection-rules.json') -Raw | ConvertFrom-Json).rules) {
    try { $null = [regex]::new($r.pattern) } catch { $problems.Add("detection rule $($r.id) has an invalid regex") }
}

# 3. Internal Markdown links
$mdFiles = Get-ChildItem $root -Recurse -Filter '*.md' -File | Where-Object { $_.FullName -notmatch '[\\/](\.git|tests[\\/]fixtures|node_modules|dist)[\\/]' }
foreach ($md in $mdFiles) {
    $text = Get-Content $md.FullName -Raw
    $text = [regex]::Replace($text, '(?ms)^```.*?^```', '')
    $text = [regex]::Replace($text, '`[^`\n]*`', '')
    foreach ($m in [regex]::Matches($text, '\]\((?!https?:|mailto:|#)([^)#\s]+)(#[^)]*)?\)')) {
        $target = Join-Path $md.DirectoryName ($m.Groups[1].Value -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path $target)) { $problems.Add("Broken link in $(Rel $md.FullName): $($m.Groups[1].Value)") }
    }
}

# 4. Secrets
$secretPattern = '(?i)(X-Radzen-Key["'']?\s*[:=]\s*["''](?!\s*\$\{)(?!RADZEN_MCP_KEY)[A-Za-z0-9_\-\.]{16,}["''])|(-----BEGIN [A-Z ]*PRIVATE KEY-----)|(AccountKey=[A-Za-z0-9+/=]{20,})'
foreach ($f in Get-ChildItem $root -Recurse -File -Include '*.json', '*.toml', '*.md', '*.ps1', '*.psm1', '*.yml', '*.cs', '*.razor', '*.sh' | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }) {
    $rel = Rel $f.FullName
    if ($rel -eq 'tests/fixtures/antipatterns/fixtures.json' -or $rel -like 'tests/unit/*' -or $rel -like 'tests/integration/*') { continue }
    if ((Get-Content $f.FullName -Raw) -match $secretPattern) { $problems.Add("Possible secret in $rel") }
}

# 5. Obsolete V1 files
foreach ($p in (Get-Content (Join-Path $PSScriptRoot 'obsolete-files.json') -Raw | ConvertFrom-Json).paths) {
    if (Test-Path (Join-Path $root $p)) { $problems.Add("Obsolete V1 path still present: $p (run build/Remove-ObsoleteFiles.ps1)") }
}

# 6. Version consistency
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
$psd = Import-PowerShellDataFile (Join-Path $root 'tools/SpecKitRadzen/SpecKitRadzen.psd1')
if ($manifest.version -ne $version) { $problems.Add("manifest.json version $($manifest.version) != VERSION $version") }
if ($psd.ModuleVersion -ne ($version -replace '-.*$', '')) { $problems.Add("Module version $($psd.ModuleVersion) != VERSION $version") }
if ((Get-Content (Join-Path $root 'core/VERSION') -Raw).Trim() -ne $version) { $problems.Add('core/VERSION differs from VERSION') }
if ((Get-Content (Join-Path $root 'CHANGELOG.md') -Raw) -notmatch [regex]::Escape("## $version")) { $problems.Add("CHANGELOG.md has no entry for $version") }

# 7. Every constitution principle is referenced by the plan template, every gate is documented
$plan = Get-Content (Join-Path $root 'core/templates/plan.md') -Raw
foreach ($n in 1..16) { $id = 'P-{0:D2}' -f $n; if ($plan -notmatch $id) { $problems.Add("plan template misses $id") } }
$gatesDoc = Get-Content (Join-Path $root 'core/gates/quality-gates.md') -Raw
foreach ($g in (Get-Content (Join-Path $root 'core/gates/gates.json') -Raw | ConvertFrom-Json).gates) { if ($gatesDoc -notmatch "## $($g.id) ") { $problems.Add("quality-gates.md does not document $($g.id)") } }

# 8. Scenario definitions
foreach ($s in Get-ChildItem (Join-Path $root 'tests/scenarios') -Filter 'SC-*.md' -ErrorAction Ignore) {
    $t = Get-Content $s.FullName -Raw
    foreach ($section in '## Prompt', '## Must', '## Must not', '## Scoring') { if ($t -notmatch [regex]::Escape($section)) { $problems.Add("$(Rel $s.FullName) lacks '$section'") } }
}

# 9. CI workflow copies
foreach ($wf in 'ci.yml', 'release.yml') {
    $active = Join-Path $root '.github' 'workflows' $wf
    $src = Join-Path $root 'build' 'ci' $wf
    if (-not (Test-Path $active)) { $warnings.Add(".github/workflows/$wf not activated (copy from build/ci/)") }
    elseif ((Get-Content $active -Raw) -ne (Get-Content $src -Raw)) { $warnings.Add(".github/workflows/$wf differs from build/ci/$wf") }
}

$warnings | ForEach-Object { Write-Host "WARN: $_" -ForegroundColor Yellow }
if ($problems.Count) {
    $problems | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    throw "$($problems.Count) repository check(s) failed."
}
Write-Host 'Repository checks passed.' -ForegroundColor Green
