# Project detection internals.

function New-SkrFact {
    param($Value, [ValidateSet('proven', 'inferred', 'unknown')][string] $Confidence = 'proven', [string[]] $Evidence = @(), [string] $Note)
    $f = [ordered]@{ value = $Value; confidence = $Confidence; evidence = @($Evidence | Select-Object -First 8) }
    if ($Note) { $f.note = $Note }
    return $f
}

function Get-SkrXml {
    param([Parameter(Mandatory)][string] $Path)
    try {
        $xml = [System.Xml.XmlDocument]::new()
        $xml.PreserveWhitespace = $false
        $xml.Load($Path)
        return $xml
    }
    catch { Write-Verbose "Cannot parse XML '$Path': $($_.Exception.Message)"; return $null }
}

function Get-SkrMsBuildProperty {
    <# Reads simple (unconditioned or conditioned) property values from an MSBuild file. Last definition wins. #>
    param([Parameter(Mandatory)] $Xml)
    $props = @{}
    if (-not $Xml) { return $props }
    foreach ($group in $Xml.SelectNodes('//*[local-name()="PropertyGroup"]')) {
        foreach ($node in $group.ChildNodes) {
            if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $props[$node.LocalName] = $node.InnerText.Trim()
        }
    }
    return $props
}

function Expand-SkrMsBuildValue {
    param([AllowNull()][string] $Value, [hashtable] $Properties)
    if (-not $Value) { return $Value }
    return ([regex]::Replace($Value, '\$\(([A-Za-z_][A-Za-z0-9_.]*)\)', { param($m) if ($Properties.ContainsKey($m.Groups[1].Value)) { $Properties[$m.Groups[1].Value] } else { $m.Value } }))
}

function Find-SkrUpward {
    <# Finds the nearest file with the given name from a directory up to the repository root. #>
    param([Parameter(Mandatory)][string] $StartDirectory, [Parameter(Mandatory)][string] $FileName, [Parameter(Mandatory)][string] $Repository)
    $dir = $StartDirectory
    while ($dir) {
        $candidate = Join-Path $dir $FileName
        if (Test-Path $candidate -PathType Leaf) { return $candidate }
        if ([System.IO.Path]::GetFullPath($dir).TrimEnd('/', '\') -eq [System.IO.Path]::GetFullPath($Repository).TrimEnd('/', '\')) { break }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-SkrSolutionProject {
    <# Returns project paths (relative to the repository) listed in a .sln or .slnx file. #>
    param([Parameter(Mandatory)][string] $SolutionPath, [Parameter(Mandatory)][string] $Repository)
    $dir = Split-Path $SolutionPath -Parent
    $paths = @()
    if ($SolutionPath -like '*.slnx') {
        $xml = Get-SkrXml -Path $SolutionPath
        if ($xml) { $paths = @($xml.SelectNodes('//*[local-name()="Project"]') | ForEach-Object { $_.GetAttribute('Path') } | Where-Object { $_ -like '*.csproj' }) }
    }
    else {
        $text = Get-Content $SolutionPath -Raw
        $paths = @([regex]::Matches($text, 'Project\("\{[^}]+\}"\)\s*=\s*"[^"]*",\s*"([^"]+\.csproj)"') | ForEach-Object { $_.Groups[1].Value })
    }
    foreach ($p in $paths) {
        $full = [System.IO.Path]::GetFullPath((Join-Path $dir ($p -replace '\\', [System.IO.Path]::DirectorySeparatorChar)))
        Get-SkrRelativePath -Base $Repository -Path $full
    }
}

function Read-SkrProject {
    param([Parameter(Mandatory)][System.IO.FileInfo] $File, [Parameter(Mandatory)][string] $Repository, [hashtable] $CentralVersions, [hashtable] $SharedProperties)
    $xml = Get-SkrXml -Path $File.FullName
    $rel = Get-SkrRelativePath -Base $Repository -Path $File.FullName
    $props = @{}
    foreach ($k in $SharedProperties.Keys) { $props[$k] = $SharedProperties[$k] }
    $own = Get-SkrMsBuildProperty -Xml $xml
    foreach ($k in $own.Keys) { $props[$k] = $own[$k] }

    $sdk = $null
    if ($xml) {
        $sdk = $xml.DocumentElement.GetAttribute('Sdk')
        if (-not $sdk) { $sdkNode = $xml.SelectSingleNode('//*[local-name()="Sdk"]'); if ($sdkNode) { $sdk = $sdkNode.GetAttribute('Name') } }
        if (-not $sdk) { $imp = $xml.SelectSingleNode('//*[local-name()="Import"][@Sdk]'); if ($imp) { $sdk = $imp.GetAttribute('Sdk') } }
    }
    $tfms = @()
    foreach ($key in 'TargetFrameworks', 'TargetFramework') {
        if ($props[$key]) { $tfms = @((Expand-SkrMsBuildValue $props[$key] $props) -split ';' | ForEach-Object Trim | Where-Object { $_ }); break }
    }
    $packages = [ordered]@{}
    $packageLines = @{}
    if ($xml) {
        $raw = Get-Content $File.FullName
        foreach ($node in $xml.SelectNodes('//*[local-name()="PackageReference"]')) {
            $id = $node.GetAttribute('Include'); if (-not $id) { $id = $node.GetAttribute('Update') }
            if (-not $id) { continue }
            $ver = $node.GetAttribute('Version')
            if (-not $ver) { $ver = $node.GetAttribute('VersionOverride') }
            if (-not $ver) { $child = $node.SelectSingleNode('*[local-name()="Version"]'); if ($child) { $ver = $child.InnerText.Trim() } }
            if (-not $ver -and $CentralVersions.ContainsKey($id)) { $ver = $CentralVersions[$id] }
            $packages[$id] = if ($ver) { Expand-SkrMsBuildValue $ver $props } else { $null }
            $line = 1 + [Array]::FindIndex([string[]]$raw, [Predicate[string]] { param($l) $l -match ('Include="' + [regex]::Escape($id) + '"') })
            $packageLines[$id] = "${rel}:$([Math]::Max($line, 1))"
        }
    }
    $refs = @()
    if ($xml) {
        $refs = @($xml.SelectNodes('//*[local-name()="ProjectReference"]') | ForEach-Object {
                $inc = $_.GetAttribute('Include') -replace '\\', '/'
                Get-SkrRelativePath -Base $Repository -Path ([System.IO.Path]::GetFullPath((Join-Path $File.DirectoryName $inc)))
            })
    }
    $frameworkRefs = @()
    if ($xml) { $frameworkRefs = @($xml.SelectNodes('//*[local-name()="FrameworkReference"]') | ForEach-Object { $_.GetAttribute('Include') }) }

    $testPackages = '^(Microsoft\.NET\.Test\.Sdk|xunit(\.v3)?|NUnit|MSTest(\.TestFramework|\.Sdk)?|TUnit|bunit)$'
    $isTest = ($props['IsTestProject'] -eq 'true') -or [bool]@($packages.Keys | Where-Object { $_ -match $testPackages }).Count -or ($sdk -match 'MSTest\.Sdk')
    $kind = if ($isTest) { 'test' }
    elseif ($sdk -match 'BlazorWebAssembly') { 'blazor-wasm' }
    elseif ($props['UseMaui'] -eq 'true') { 'maui' }
    elseif ($sdk -match 'Microsoft\.NET\.Sdk\.Web') { 'web' }
    elseif ($sdk -match 'Microsoft\.NET\.Sdk\.Razor') { 'razor-library' }
    elseif ($props['UseWPF'] -eq 'true' -or $props['UseWindowsForms'] -eq 'true') { 'desktop' }
    elseif ($props['OutputType'] -match 'Exe') { 'console' }
    else { 'library' }

    [pscustomobject]@{
        path              = $rel
        name              = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        sdk               = $(if ($sdk) { $sdk } else { $null })
        targetFrameworks  = @($tfms)
        kind              = $kind
        packages          = $packages
        projectReferences = @($refs)
        isTest            = [bool]$isTest
        frameworkReferences = @($frameworkRefs)
        nullable          = $props['Nullable']
        packageEvidence   = $packageLines
        directory         = $File.DirectoryName
    }
}

function Find-SkrContentMatch {
    <# Searches files for a regex. Returns 'path:line' evidence strings (first match per file), up to -Limit. #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Files,
        [Parameter(Mandatory)][string] $Pattern,
        [Parameter(Mandatory)][string] $Repository,
        [int] $Limit = 8,
        [switch] $All
    )
    $rx = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $Files) {
        $text = $script:SkrContentCache[$f.FullName]
        if ($null -eq $text) { continue }
        $matchesFound = if ($All) { $rx.Matches($text) } else { @($rx.Match($text)) | Where-Object Success }
        foreach ($m in $matchesFound) {
            $results.Add("$(Get-SkrRelativePath -Base $Repository -Path $f.FullName):$(Get-SkrLineNumber -Text $text -Index $m.Index)")
            if ($results.Count -ge $Limit) { return $results.ToArray() }
        }
    }
    return $results.ToArray()
}

function Get-SkrFirstCapture {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]] $Files, [Parameter(Mandatory)][string] $Pattern, [Parameter(Mandatory)][string] $Repository)
    $rx = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($f in $Files) {
        $text = $script:SkrContentCache[$f.FullName]
        if ($null -eq $text) { continue }
        $m = $rx.Match($text)
        if ($m.Success) {
            return [pscustomobject]@{ Value = $m.Groups[1].Value; Evidence = "$(Get-SkrRelativePath -Base $Repository -Path $f.FullName):$(Get-SkrLineNumber -Text $text -Index $m.Index)" }
        }
    }
    return $null
}

function Get-SkrProfileFingerprint {
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Repository)
    $names = @('*.sln', '*.slnx', '*.csproj', 'Directory.Build.props', 'Directory.Packages.props', 'global.json', 'Program.cs', 'App.razor', 'Routes.razor', '_Imports.razor', 'MainLayout.razor', 'packages.lock.json')
    $files = Get-SkrRepositoryFile -Repository $Repository -Include $names | Sort-Object { Get-SkrRelativePath -Base $Repository -Path $_.FullName }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($f in $files) { $null = $sb.AppendLine("$(Get-SkrRelativePath -Base $Repository -Path $f.FullName):$(Get-SkrContentHash -Path $f.FullName)") }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}
