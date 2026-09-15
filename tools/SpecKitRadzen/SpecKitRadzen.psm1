#Requires -Version 7.4
Set-StrictMode -Version 1.0

$script:ModuleRoot = $PSScriptRoot

foreach ($folder in 'Private', 'Public') {
    $dir = Join-Path $PSScriptRoot $folder
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' | ForEach-Object BaseName)
