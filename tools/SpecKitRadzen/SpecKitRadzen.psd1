@{
    RootModule           = 'SpecKitRadzen.psm1'
    ModuleVersion        = '2.0.0'
    GUID                 = '5d7c1f0e-7a57-4a53-9d0e-2b0c4d1f6a21'
    Author               = 'Spec Kit Radzen contributors'
    CompanyName          = 'Spec Kit Radzen'
    Copyright            = '(c) 2026 Spec Kit Radzen contributors. MIT License.'
    Description          = 'Repository-aware, MCP-first spec-driven workflow for Radzen Blazor features: project detection, anti-pattern scanning, quality gates and a lifecycle installer.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Add-SkrMcpEvidence',
        'Get-SkrFeatureState',
        'Get-SkrProjectProfile',
        'Install-SpecKitRadzen',
        'Invoke-SkrAnalysis',
        'Invoke-SkrAntiPatternScan',
        'Invoke-SkrQualityGate',
        'New-SkrBuildBaseline',
        'New-SkrFeature',
        'Set-SkrFeaturePhase',
        'Test-SkrArtifact',
        'Test-SkrMcpConfiguration',
        'Test-SpecKitRadzenInstall',
        'Uninstall-SpecKitRadzen',
        'Update-SpecKitRadzen'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('Radzen', 'Blazor', 'SpecDriven', 'MCP', 'AI', 'Agents', 'QualityGates')
            LicenseUri = 'https://opensource.org/licenses/MIT'
        }
    }
}
