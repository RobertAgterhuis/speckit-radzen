function Invoke-SkrAntiPatternScan {
    <#
    .SYNOPSIS
        Scans source files for catalogued anti-patterns.
    .DESCRIPTION
        Scope (first that applies): -Path, -All, changed files since the feature's base commit (-Feature), changed files since -Base (default HEAD).
        Without git, -All is implied.
    .PARAMETER ListManual
        Only list the manual-review rules (for the G7 review).
    #>
    [CmdletBinding()]
    param(
        [string] $Repository = (Get-Location).Path,
        [string] $Feature,
        [string[]] $Path,
        [switch] $All,
        [string] $Base,
        [switch] $ListManual,
        [switch] $NoWrite
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $config = Get-SkrConfig -Repository $repo
    $rules = @(Get-SkrAntiPatternRule -Repository $repo -Config $config)
    $manual = @($rules | Where-Object detection -eq 'manual-review' | ForEach-Object { [pscustomobject]@{ id = $_.id; severity = $_.severity; title = $_.title } })
    if ($ListManual) { return $manual }

    $featureInfo = $null
    if ($Feature) { $featureInfo = Resolve-SkrFeature -Repository $repo -Feature $Feature }

    # ----- scope -----
    $scope = ''
    $relFiles = @()
    $gitAvailable = (Get-Command git -ErrorAction Ignore) -and (Test-Path (Join-Path $repo '.git'))
    if ($Path) {
        $scope = 'explicit paths'
        foreach ($p in $Path) {
            $full = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $repo $p }
            if (Test-Path $full -PathType Container) { $relFiles += @(Get-SkrRepositoryFile -Repository $full | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName }) }
            elseif (Test-Path $full) { $relFiles += Get-SkrRelativePath -Base $repo -Path (Resolve-Path $full).Path }
            else { throw "Path '$p' not found." }
        }
    }
    elseif ($All -or -not $gitAvailable) {
        $scope = 'all files'
        $relFiles = @(Get-SkrRepositoryFile -Repository $repo | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
    }
    else {
        if (-not $Base -and $featureInfo) {
            $st = Read-SkrJson -Path (Join-Path $featureInfo.Path 'state.json')
            if ($st -and $st.PSObject.Properties['baseRef'] -and $st.baseRef) { $Base = $st.baseRef }
        }
        if (-not $Base) { $Base = 'HEAD' }
        $scope = "changed since $($Base.Substring(0, [Math]::Min(12, $Base.Length)))"
        $relFiles = @(Get-SkrGitChangedFile -Repository $repo -Base $Base)
    }
    $specsRel = Get-SkrRelativePath -Base $repo -Path (Get-SkrSpecsRoot -Repository $repo)
    $exclude = @($config.scan.excludePaths) + @("$specsRel/**", '.speckit/**', '**/bin/**', '**/obj/**', '**/node_modules/**')
    $relFiles = @($relFiles | Select-Object -Unique | Where-Object {
            $f = $_
            (Test-Path (Join-Path $repo $f) -PathType Leaf) -and -not ($exclude | Where-Object { Test-SkrGlob -Path $f -Pattern $_ })
        })

    $findings = [System.Collections.Generic.List[object]]::new()
    $configWaivers = @($config.scan.waivers)
    $applyConfigWaiver = {
        param($finding)
        $w = $configWaivers | Where-Object { $_.rule -eq $finding.rule -and (Test-SkrGlob -Path $finding.file -Pattern $_.path) } | Select-Object -First 1
        if ($w -and -not $finding.waived) { $finding.waived = $true; $finding.waiver = "config: $($w.reason)" }
        $finding
    }

    $textRules = @($rules | Where-Object { $_.detection -in 'regex', 'absence' })
    $scanned = 0
    foreach ($rel in $relFiles) {
        $applicable = @($textRules | Where-Object { $r = $_; @($r.files | Where-Object { Test-SkrGlob -Path $rel -Pattern $_ }).Count })
        if (-not $applicable.Count) { continue }
        $full = Join-Path $repo $rel
        if ([System.IO.FileInfo]::new($full).Length -gt 2MB) { continue }
        $text = [System.IO.File]::ReadAllText($full)
        $scanned++
        $lines = $text -split "`r?`n"
        $fileWaivers = @($lines | Where-Object { $_ -match 'speckit-radzen:ignore-file' })
        # waivers without reason
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in [regex]::Matches($lines[$i], $script:SkrWaiverPattern)) {
                if (-not $m.Groups['reason'].Success -or $m.Groups['reason'].Value.Trim().Length -lt 3) {
                    $wr = $rules | Where-Object id -eq 'AP-AGT-08' | Select-Object -First 1
                    if ($wr) { $findings.Add((New-SkrFinding -Rule $wr -File $rel -Line ($i + 1) -Snippet $lines[$i] -Waived $false)) }
                }
            }
        }
        $isTest = Test-SkrTestPath -RelativePath $rel
        foreach ($rule in $applicable) {
            if ($isTest -and $rule.PSObject.Properties['excludeTests'] -and $rule.excludeTests) { continue }
            if ($rule.PSObject.Properties['unlessInFile'] -and $rule.unlessInFile -and $text -match $rule.unlessInFile) { continue }
            $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline
            if ($rule.detection -eq 'absence') {
                $m = [regex]::Match($text, $rule.pattern, $opts)
                if (-not $m.Success -or [regex]::IsMatch($text, $rule.requires, $opts)) { continue }
                $hits = @($m)
            }
            else {
                if ($rule.PSObject.Properties['requires'] -and $rule.requires -and -not [regex]::IsMatch($text, $rule.requires, $opts)) { continue }
                $hits = @([regex]::Matches($text, $rule.pattern, $opts))
            }
            foreach ($m in $hits) {
                $line = Get-SkrLineNumber -Text $text -Index $m.Index
                $lineText = $lines[$line - 1]
                if ($rule.PSObject.Properties['unless'] -and $rule.unless -and ($m.Value -match $rule.unless -or $lineText -match $rule.unless)) { continue }
                $waiver = @(Get-SkrWaiver -Lines $lines -LineNumber $line -FileWaiverLines $fileWaivers | Where-Object { $_.Id -eq $rule.id })
                $valid = @($waiver | Where-Object HasReason)
                $f = New-SkrFinding -Rule $rule -File $rel -Line $line -Snippet $m.Value -Waived ([bool]$valid.Count) -WaiverReason $(if ($valid.Count) { $valid[0].Reason } else { $null })
                $findings.Add((& $applyConfigWaiver $f))
            }
        }
    }

    # ----- tool rules -----
    $ruleById = @{}; foreach ($r in $rules) { $ruleById[$r.id] = $r }
    $profilePath = Join-Path (Get-SkrStateRoot $repo) 'profile.json'
    $prof = Read-SkrJson -Path $profilePath
    if ($prof) {
        $map = @{ 'RDZ-H01' = 'AP-RDZ-06'; 'RDZ-H02' = 'AP-RDZ-05'; 'RND-H02' = 'AP-RDZ-13'; 'RND-H01' = 'AP-RND-01' }
        foreach ($h in @($prof.health)) {
            if ($map.ContainsKey($h.id) -and $ruleById.ContainsKey($map[$h.id])) {
                $ev = @($h.evidence) | Select-Object -First 1
                $file, $ln = if ($ev -and $ev -match '^(.*):(\d+)$') { $Matches[1], [int]$Matches[2] } else { "$ev", 0 }
                $f = New-SkrFinding -Rule $ruleById[$map[$h.id]] -File $file -Line $ln -Message "$($h.message) (project detection $($h.id))" -Waived $false
                $findings.Add((& $applyConfigWaiver $f))
            }
        }
    }
    if ($ruleById.ContainsKey('AP-FRM-01')) {
        $razorFiles = @($relFiles | Where-Object { $_ -like '*.razor' })
        if ($razorFiles.Count) {
            $entities = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($cs in (Get-SkrRepositoryFile -Repository $repo -Include '*.cs')) {
                if ($cs.Length -gt 1MB) { continue }
                foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($cs.FullName), 'DbSet<\s*([A-Za-z_][\w.]*)\s*>')) { $null = $entities.Add(($m.Groups[1].Value -split '\.')[-1]) }
            }
            if ($entities.Count) {
                foreach ($rel in $razorFiles) {
                    $text = [System.IO.File]::ReadAllText((Join-Path $repo $rel))
                    $lines = $text -split "`r?`n"
                    foreach ($m in [regex]::Matches($text, '<RadzenTemplateForm\b[^>]*\bTItem\s*=\s*"([\w.]+)"')) {
                        $type = ($m.Groups[1].Value -split '\.')[-1]
                        if (-not $entities.Contains($type)) { continue }
                        $line = Get-SkrLineNumber -Text $text -Index $m.Index
                        $waiver = @(Get-SkrWaiver -Lines $lines -LineNumber $line -FileWaiverLines @($lines | Where-Object { $_ -match 'speckit-radzen:ignore-file' }) | Where-Object { $_.Id -eq 'AP-FRM-01' -and $_.HasReason })
                        $f = New-SkrFinding -Rule $ruleById['AP-FRM-01'] -File $rel -Line $line -Snippet $m.Value -Message ($ruleById['AP-FRM-01'].message -f $type) -Waived ([bool]$waiver.Count) -WaiverReason $(if ($waiver.Count) { $waiver[0].Reason })
                        $findings.Add((& $applyConfigWaiver $f))
                    }
                }
            }
        }
    }
    if ($ruleById.ContainsKey('AP-TST-03') -and $gitAvailable -and -not $All -and -not $Path) {
        $deleted = & git -C $repo diff --name-only --diff-filter=D $Base 2>$null
        foreach ($d in @($deleted | Where-Object { $_ -match '(?i)tests?[^/]*\.cs$' })) {
            $f = New-SkrFinding -Rule $ruleById['AP-TST-03'] -File $d -Line 0 -Message ($ruleById['AP-TST-03'].message -f $d) -Waived $false
            $findings.Add((& $applyConfigWaiver $f))
        }
    }

    $active = @($findings | Where-Object { -not $_.waived })
    $result = [pscustomobject]@{
        generatedAt  = Get-SkrTimestamp
        scope        = $scope
        scannedFiles = $scanned
        candidateFiles = $relFiles.Count
        summary      = [pscustomobject]@{
            blocker = @($active | Where-Object severity -eq 'blocker').Count
            major   = @($active | Where-Object severity -eq 'major').Count
            minor   = @($active | Where-Object severity -eq 'minor').Count
            waived  = @($findings | Where-Object waived).Count
        }
        findings     = $findings.ToArray()
        manual       = $manual
    }
    if ($featureInfo -and -not $NoWrite) {
        $gates = Join-Path $featureInfo.Path 'gates'
        Write-SkrText -Path (Join-Path $gates 'scan.md') -Content (ConvertTo-SkrScanMarkdown -Result $result)
        Write-SkrJson -Path (Join-Path $gates 'scan.sarif') -InputObject (ConvertTo-SkrSarif -Result $result -Rules $rules)
    }
    return $result
}
