# Shared helpers for Spec Kit Radzen tests.

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Get-KitRoot { $script:RepoRoot }

function Import-KitModule {
    Import-Module (Join-Path $script:RepoRoot 'tools' 'SpecKitRadzen' 'SpecKitRadzen.psd1') -Force -Global
}

function Copy-Fixture {
    <# Copies a fixture repository to a fresh temp folder and returns its path. -Git initialises a repository with one commit. #>
    param([Parameter(Mandatory)][string] $Name, [switch] $Git)
    $source = Join-Path $script:RepoRoot 'tests' 'fixtures' 'repos' $Name
    $target = Join-Path ([System.IO.Path]::GetTempPath()) ("skr-" + $Name + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Copy-Item -Path $source -Destination $target -Recurse
    if ($Git) { Initialize-GitRepository -Path $target }
    return $target
}

function New-EmptyRepository {
    param([switch] $Git)
    $target = Join-Path ([System.IO.Path]::GetTempPath()) ("skr-empty-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $target
    Set-Content -Path (Join-Path $target 'global.json') -Value '{ "sdk": { "version": "10.0.100" } }'
    if ($Git) { Initialize-GitRepository -Path $target }
    return $target
}

function Initialize-GitRepository {
    param([Parameter(Mandatory)][string] $Path)
    & git -C $Path init -q -b main 2>$null
    & git -C $Path config user.email 'test@example.invalid'
    & git -C $Path config user.name 'test'
    & git -C $Path config core.autocrlf false
    & git -C $Path add -A
    & git -C $Path commit -q -m 'fixture' --allow-empty
}

function Remove-TestRepository {
    param([string] $Path)
    if ($Path -and (Test-Path $Path) -and $Path.StartsWith([System.IO.Path]::GetTempPath())) { Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue }
}

Export-ModuleMember -Function *
