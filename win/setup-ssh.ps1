# Run this script from an elevated PowerShell session.
$ErrorActionPreference = 'Stop'

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from PowerShell as Administrator.'
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -eq $winget) {
    throw 'winget is required. Install or update App Installer from the Microsoft Store, then rerun this script.'
}

& $winget.Source install --id WinFsp.WinFsp --exact --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    throw 'WinFsp installation failed.'
}

& $winget.Source install --id SSHFS-Win.SSHFS-Win --exact --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    throw 'SSHFS-Win installation failed.'
}

$sshClient = Get-WindowsCapability -Online |
    Where-Object Name -like 'OpenSSH.Client*'

if ($null -eq $sshClient) {
    throw 'The OpenSSH Client Windows capability was not found.'
}

if ($sshClient.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name $sshClient.Name | Out-Null
}

Write-Host 'SSHFS-Win and WinFsp are installed.'
Write-Host 'Map a Linux home directory with: net use X: \\sshfs\<linux-user>@<linux-host>'
Write-Host 'Map an absolute Linux path with: net use X: \\sshfs.r\<linux-user>@<linux-host>\home\<linux-user>'