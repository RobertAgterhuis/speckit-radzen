function Add-SkrMcpEvidence {
    <#
    .SYNOPSIS
        Appends an MCP-### evidence entry to specs/NNN-*/mcp-evidence.json and re-renders mcp-evidence.md.
    .EXAMPLE
        Add-SkrMcpEvidence -Feature 001 -Component RadzenDataGrid -Members LoadData,Count -Question '…' -Query '…' -Source mcp -Summary '…'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Feature,
        [Parameter(Mandatory)][string] $Component,
        [string[]] $Members = @(),
        [Parameter(Mandatory)][string] $Question,
        [string] $Query,
        [Parameter(Mandatory)][ValidateSet('compiler', 'project', 'mcp', 'docs', 'model')][string] $Source,
        [Parameter(Mandatory)][string] $Summary,
        [string] $Server,
        [string] $Tool,
        [string] $RadzenVersion,
        [string[]] $ProjectEvidence = @(),
        [switch] $CompileVerified,
        [switch] $FallbackApproved,
        [string] $FallbackReason,
        [ValidateSet('confirmed', 'conflict')][string] $Status = 'confirmed',
        [ValidatePattern('^MCP-[0-9]{3}$')][string] $Supersedes,
        [switch] $Force,
        [string] $Repository = (Get-Location).Path
    )
    $Members = @($Members | Where-Object { $_ })
    $ProjectEvidence = @($ProjectEvidence | Where-Object { $_ })
    $repo = Resolve-SkrRepository -Path $Repository
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $path = Join-Path $f.Path 'mcp-evidence.json'
    $doc = Read-SkrJson -Path $path -AsHashtable
    if (-not $doc) { $doc = @{ schemaVersion = 1; feature = $f.Id; entries = @() } }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($doc.entries)) { $entries.Add($e) }

    if ($Source -eq 'mcp' -and -not $Query) { throw '-Query is required when -Source is mcp.' }
    if ($Source -eq 'mcp' -and -not $Server) { $Server = 'radzen-blazor' }
    if ($Source -eq 'mcp' -and -not $Tool) { $Tool = 'search' }
    if ($FallbackApproved -and -not $FallbackReason) { throw '-FallbackReason is required with -FallbackApproved (who approved and why).' }
    if ($Source -eq 'project' -and -not $ProjectEvidence.Count) { throw '-ProjectEvidence (file:line) is required when -Source is project.' }
    if ($Source -eq 'model') { Write-Warning 'Model knowledge (rank 5) is never sufficient on its own; G4 will fail unless a stronger entry supersedes it.' }
    foreach ($text in @($Summary, $Query, $Question)) {
        if ($text -and $text -match '(?i)x-radzen-key\s*[:=]\s*\S{8,}') { throw 'Evidence text appears to contain a licence key. Remove it.' }
    }

    if (-not $RadzenVersion) {
        $prof = Read-SkrJson -Path (Join-Path (Get-SkrStateRoot $repo) 'profile.json')
        if ($prof -and $prof.radzen -and $prof.radzen.version) { $RadzenVersion = [string]$prof.radzen.version.value }
    }

    $memberKey = (@($Members | Sort-Object) -join ',')
    $existing = $entries | Where-Object { $_.component -eq $Component -and ((@($_.members | Sort-Object) -join ',') -eq $memberKey) -and $_.status -eq 'confirmed' -and $_.rank -le (Get-SkrEvidenceRank $Source) }
    if ($existing -and -not $Force -and -not $Supersedes -and $Status -eq 'confirmed') {
        Write-Warning "Equivalent evidence already exists: $(@($existing)[0].id). Reuse it (or pass -Force)."
        return [pscustomobject]@(@($existing)[0])
    }

    $next = 1
    if ($entries.Count) { $next = ([int](($entries | ForEach-Object { [int]($_.id.Substring(4)) } | Measure-Object -Maximum).Maximum)) + 1 }
    $id = 'MCP-{0:D3}' -f $next
    $entry = [ordered]@{
        id = $id; at = (Get-SkrTimestamp); component = $Component; members = @($Members); question = $Question
        query = $Query; source = $Source; rank = (Get-SkrEvidenceRank $Source); server = $Server; tool = $Tool
        summary = $Summary; radzenVersion = $RadzenVersion; projectEvidence = @($ProjectEvidence)
        compileVerified = ([bool]$CompileVerified -or $Source -eq 'compiler'); fallbackApproved = [bool]$FallbackApproved; fallbackReason = $FallbackReason
        status = $Status; supersedes = $Supersedes
    }
    if ($Supersedes) {
        $old = $entries | Where-Object id -eq $Supersedes
        if (-not $old) { throw "Cannot supersede unknown $Supersedes." }
        $old.status = 'superseded'
    }
    $entries.Add($entry)
    $doc.entries = $entries.ToArray()

    $json = $doc | ConvertTo-Json -Depth 20
    $errors = Test-SkrJsonSchema -Json $json -SchemaName 'mcp-evidence'
    if ($errors.Count) { throw "Evidence entry is invalid: $($errors -join '; ')" }
    if ($PSCmdlet.ShouldProcess($path, "Add $id")) {
        Write-SkrText -Path $path -Content $json
        Write-SkrEvidenceMarkdown -FeaturePath $f.Path
    }
    [pscustomobject]$entry
}
