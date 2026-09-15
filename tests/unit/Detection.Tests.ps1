BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    $script:Profiles = @{}
    foreach ($name in Get-ChildItem (Join-Path (Get-KitRoot) 'tests' 'fixtures' 'repos') -Directory | ForEach-Object Name) {
        $path = Copy-Fixture -Name $name
        $script:Profiles[$name] = @{ Path = $path; Profile = (Get-SkrProjectProfile -Repository $path) }
    }
}

AfterAll {
    foreach ($p in $script:Profiles.Values) { Remove-TestRepository $p.Path }
}

Describe 'Project detection' {
    Context 'webapp-interactive-server (CPM, global render mode, Entra, EF, bUnit)' {
        BeforeAll { $p = $script:Profiles['webapp-interactive-server'].Profile }
        It 'selects the single solution' { $p.repository.solutionSelection | Should -Be 'single'; $p.repository.solution | Should -Be 'Contoso.Crm.sln' }
        It 'reads SDK from global.json' { $p.runtime.sdk.value | Should -Be '10.0.100' }
        It 'resolves the Radzen version through central package management and a property' { $p.radzen.version.value | Should -Be '7.1.2'; $p.runtime.centralPackageManagement.value | Should -BeTrue }
        It 'inherits the target framework from Directory.Build.props' { $p.runtime.targetFrameworks.value | Should -Be @('net10.0') }
        It 'detects a Blazor Web App with global InteractiveServer' {
            $p.blazor.hostingModel.value | Should -Be @('Blazor Web App')
            $p.blazor.renderModeScope.value | Should -Be 'global'
            $p.blazor.globalRenderMode.value | Should -Be 'InteractiveServer'
        }
        It 'detects complete Radzen wiring' {
            $p.radzen.serviceRegistration.value | Should -Be 'AddRadzenComponents'
            $p.radzen.componentHost.value | Should -Be 'RadzenComponents'
            $p.radzen.theme.value | Should -Be 'material'
            $p.radzen.script.value | Should -BeTrue
            @($p.health).Count | Should -Be 0
        }
        It 'finds the AppGrid wrapper' { $p.radzen.wrappers.value | Should -Contain 'src/Contoso.Crm.Web/Components/Shared/AppGrid.razor' }
        It 'detects architecture and security facts with evidence' {
            $p.architecture.persistence.value | Should -Contain 'EF Core'
            $p.architecture.validation.value | Should -Contain 'FluentValidation'
            $p.architecture.errorHandling.value | Should -Contain 'ProblemDetails'
            $p.security.authentication.value | Should -Contain 'Microsoft Entra ID (Microsoft.Identity.Web)'
            $p.security.authorization.value | Should -Contain 'Named policies'
            $p.security.authorization.evidence | Should -Not -BeNullOrEmpty
        }
        It 'detects the test stack' {
            $p.testing.framework.value | Should -Contain 'xUnit'
            $p.testing.component.value | Should -Contain 'bUnit'
            $p.testing.mocking.value | Should -Contain 'NSubstitute'
        }
        It 'lists repository instructions and agent environment' { $p.repository.instructions | Should -Contain 'AGENTS.md' }
        It 'writes profile.json and profile.md' {
            $root = $script:Profiles['webapp-interactive-server'].Path
            Join-Path $root '.speckit/radzen/profile.json' | Should -Exist
            Get-Content (Join-Path $root '.speckit/radzen/profile.md') -Raw | Should -Match '## Radzen'
        }
    }

    Context 'webapp-auto-per-page (slnx, per-page render modes)' {
        BeforeAll { $p = $script:Profiles['webapp-auto-per-page'].Profile }
        It 'parses the slnx solution' { $p.repository.solution | Should -Be 'Shop.slnx'; @($p.projects).Count | Should -Be 2 }
        It 'detects both interactivity modes and per-page scope' {
            $p.blazor.interactivity.value | Should -Be @('Server', 'WebAssembly')
            $p.blazor.renderModeScope.value | Should -Be 'per-page/component'
            $p.blazor.pageRenderModes.value | Should -Contain 'InteractiveWebAssembly'
        }
        It 'notices disabled prerendering' { $p.blazor.prerendering.value | Should -Be 'disabled in some places' }
        It 'reports missing theme, script and a non-interactive component host' {
            $ids = @($p.health | ForEach-Object id)
            $ids | Should -Contain 'RDZ-H03'
            $ids | Should -Contain 'RDZ-H04'
            $ids | Should -Contain 'RND-H02'
        }
        It 'classifies the client as a WebAssembly project' { ($p.projects | Where-Object name -eq 'Shop.Client').kind | Should -Be 'blazor-wasm' }
    }

    Context 'wasm-hosted-api' {
        BeforeAll { $p = $script:Profiles['wasm-hosted-api'].Profile }
        It 'detects hosted WebAssembly' { $p.blazor.hostingModel.value | Should -Be @('Blazor WebAssembly (ASP.NET Core hosted)') }
        It 'detects individual service registration and legacy hosts' {
            $p.radzen.serviceRegistration.value | Should -Be 'individual services'
            $p.radzen.componentHost.value | Should -Match 'individual hosts'
            $p.radzen.theme.value | Should -Be 'standard-base'
        }
        It 'detects controllers, Refit, JWT and MSAL' {
            $p.architecture.apiStyle.value | Should -Contain 'Controllers'
            $p.architecture.httpClients.value | Should -Contain 'Refit'
            $p.security.authentication.value | Should -Contain 'JWT bearer'
            $p.security.authentication.value | Should -Contain 'MSAL for WebAssembly'
        }
    }

    Context 'blazor-server-legacy' {
        BeforeAll { $p = $script:Profiles['blazor-server-legacy'].Profile }
        It 'detects legacy Blazor Server' { $p.blazor.hostingModel.value | Should -Be @('Blazor Server (legacy)') }
        It 'reads a Version child element' { $p.radzen.version.value | Should -Be '4.4.1' }
        It 'flags the missing dialog host' { @($p.health | ForEach-Object id) | Should -Contain 'RDZ-H02' }
        It 'detects Identity and Dapper' {
            $p.security.authentication.value | Should -Contain 'ASP.NET Core Identity'
            $p.architecture.persistence.value | Should -Contain 'Dapper'
        }
    }

    Context 'clean-arch-mediatr' {
        BeforeAll { $p = $script:Profiles['clean-arch-mediatr'].Profile }
        It 'detects mediator, validation, mapping and persistence' {
            $p.architecture.mediator.value | Should -Contain 'MediatR'
            $p.architecture.validation.value | Should -Contain 'FluentValidation'
            $p.architecture.mapping.value | Should -Contain 'Mapster'
            $p.architecture.persistence.value | Should -Contain 'EF Core (PostgreSQL)'
            $p.architecture.errorHandling.value | Should -Contain 'IExceptionHandler'
        }
        It 'builds the project graph' { ($p.architecture.projectGraph.value -join ';') | Should -Match 'CleanShop.Web \[web\] -> CleanShop.Application, CleanShop.Infrastructure' }
        It 'detects test stack from an IsTestProject project' {
            $p.testing.framework.value | Should -Contain 'NUnit'
            $p.testing.integration.value | Should -Contain 'Testcontainers'
            ($p.projects | Where-Object name -eq 'CleanShop.Tests').isTest | Should -BeTrue
        }
    }

    Context 'no-radzen' {
        BeforeAll { $p = $script:Profiles['no-radzen'].Profile }
        It 'reports Radzen as not installed without inventing a version' {
            $p.radzen.installed.value | Should -BeFalse
            $p.radzen.version.value | Should -BeNullOrEmpty
            $p.radzen.version.confidence | Should -Be 'unknown'
            @($p.health | ForEach-Object id) | Should -Contain 'RDZ-H06'
        }
    }

    Context 'hybrid-maui' {
        BeforeAll { $p = $script:Profiles['hybrid-maui'].Profile }
        It 'detects Blazor Hybrid with multi-targeting' {
            $p.blazor.hostingModel.value | Should -Be @('Blazor Hybrid')
            $p.runtime.targetFrameworks.value | Should -Contain 'net10.0-android'
            ($p.projects | Select-Object -First 1).kind | Should -Be 'maui'
        }
    }

    Context 'monorepo-two-solutions' {
        BeforeAll { $p = $script:Profiles['monorepo-two-solutions'].Profile }
        It 'marks solution selection as ambiguous and raises a blocker' {
            $p.repository.solutionSelection | Should -Be 'ambiguous'
            ($p.health | Where-Object id -eq 'REPO-H01').severity | Should -Be 'blocker'
        }
        It 'scopes to a chosen solution and stores the choice' {
            $root = $script:Profiles['monorepo-two-solutions'].Path
            $scoped = Get-SkrProjectProfile -Repository $root -Solution 'portal/Portal.sln'
            $scoped.repository.solutionSelection | Should -Be 'configured'
            @($scoped.projects).Count | Should -Be 1
            $scoped.radzen.version.value | Should -Be '6.0.0'
            (Get-Content (Join-Path $root '.speckit/radzen/config.json') -Raw | ConvertFrom-Json).solution | Should -Be 'portal/Portal.sln'
            (Get-SkrProjectProfile -Repository $root -NoWrite).repository.solutionSelection | Should -Be 'configured'
        }
    }

    Context 'brownfield-mixed' {
        BeforeAll { $p = $script:Profiles['brownfield-mixed'].Profile }
        It 'detects static-only Blazor Web App with Radzen wiring problems' {
            $p.blazor.interactivity.value | Should -Be @('None (static SSR only)')
            $ids = @($p.health | ForEach-Object id)
            foreach ($id in 'RDZ-H01', 'RDZ-H02', 'RND-H01') { $ids | Should -Contain $id }
        }
        It 'detects both API styles, Fluxor and UI-only authorization' {
            $p.architecture.apiStyle.value | Should -Contain 'Minimal APIs'
            $p.architecture.apiStyle.value | Should -Contain 'Controllers'
            $p.architecture.state.value | Should -Contain 'Fluxor'
            $p.security.authorization.value | Should -Contain 'AuthorizeView (UI only)'
            $p.architecture.httpClients.value | Should -Contain 'HttpClient injected into components'
        }
    }

    Context 'fingerprint' {
        It 'is stable and changes when a project file changes' {
            $root = $script:Profiles['buildable-sample'].Path
            $a = (Get-SkrProjectProfile -Repository $root -NoWrite).fingerprint
            $b = (Get-SkrProjectProfile -Repository $root -NoWrite).fingerprint
            $a | Should -Be $b
            Add-Content -Path (Join-Path $root 'src/Sample.Web/Sample.Web.csproj') -Value '<!-- changed -->'
            (Get-SkrProjectProfile -Repository $root -NoWrite).fingerprint | Should -Not -Be $a
        }
    }

    Context 'schema' {
        It 'every generated profile validates against profile.schema.json' {
            foreach ($entry in $script:Profiles.GetEnumerator()) {
                $json = Get-Content (Join-Path $entry.Value.Path '.speckit/radzen/profile.json') -Raw
                Test-Json -Json $json -SchemaFile (Join-Path (Get-KitRoot) 'core/schemas/profile.schema.json') | Should -BeTrue -Because $entry.Key
            }
        }
    }
}
