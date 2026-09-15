@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Write-Host is intentional for interactive CLI output.
        'PSAvoidUsingWriteHost',
        # Public functions use the SpeckitRadzen noun prefix; some nouns are plural by design (e.g. Findings).
        'PSUseSingularNouns'
    )
}
