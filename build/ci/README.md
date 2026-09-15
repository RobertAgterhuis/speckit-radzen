# CI workflows

GitHub Actions workflows for this repository. They live here because the tooling that produced V2 cannot write into `.github/workflows/`.

Activate them once:

```powershell
New-Item -ItemType Directory -Force .github/workflows | Out-Null
Copy-Item build/ci/ci.yml, build/ci/release.yml .github/workflows/
```

`build/Test-Repository.ps1` warns when the copies in `.github/workflows/` differ from these files.
