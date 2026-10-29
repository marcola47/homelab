$ErrorActionPreference = 'Stop'

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $winget) {
    throw 'winget is required. Install or update App Installer from the Microsoft Store, then rerun this script.'
}

$uv = Get-Command uv -ErrorAction SilentlyContinue
if ($null -eq $uv) {
    & $winget.Source install --id astral-sh.uv --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw 'uv installation failed.'
    }

    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
    $uv = Get-Command uv -ErrorAction SilentlyContinue
}

if ($null -eq $uv) {
    throw 'uv was installed but could not be found on PATH. Open a new PowerShell session and rerun this script.'
}

& $uv.Source python install 3.14.5
if ($LASTEXITCODE -ne 0) {
    throw 'Python 3.14.5 installation through uv failed.'
}

Write-Host 'Python 3.14.5 is installed and managed by uv.'