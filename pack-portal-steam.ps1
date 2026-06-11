# Pack only the Steam install scripts (~10 files). No Armbian build tree.
# Run in PowerShell:  .\pack-portal-steam.ps1
# Copy portal-steam-bundle.zip to the Portal via USB or scp.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $Root 'os\portal-steam'
$Out = Join-Path $Root 'portal-steam-bundle'
$Zip = Join-Path $Root 'portal-steam-bundle.zip'

if (-not (Test-Path (Join-Path $Src 'portal-steam'))) {
    Write-Error "Not found: $Src\portal-steam"
}

$ReinstallProton = Join-Path $Root 'portal-steam-bundle\reinstall-proton.sh'
$ReinstallBackup = $null
if (Test-Path $ReinstallProton) {
    $ReinstallBackup = Join-Path $env:TEMP 'reinstall-proton.sh.portal'
    Copy-Item $ReinstallProton $ReinstallBackup -Force
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
if (Test-Path $Zip) { Remove-Item $Zip -Force }

New-Item -ItemType Directory -Path $Out -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Out 'share') -Force | Out-Null

Copy-Item (Join-Path $Root 'install-portal-steam.sh') $Out
Copy-Item (Join-Path $Src 'portal-steam') $Out
Copy-Item (Join-Path $Src 'install-steam.sh') $Out
Copy-Item (Join-Path $Src 'portal-steam-common.sh') $Out
Copy-Item (Join-Path $Src 'install-fex.sh') $Out
Copy-Item (Join-Path $Src 'setup-games.sh') $Out
Copy-Item (Join-Path $Src 'install-proton-stack.sh') $Out
Copy-Item (Join-Path $Src 'install-controller-support.sh') $Out
Copy-Item (Join-Path $Src 'restore-portal-wayland.sh') $Out
Copy-Item (Join-Path $Src 'try-portal-x11-gaming.sh') $Out
Copy-Item (Join-Path $Src 'portal-game-launch') $Out
Copy-Item (Join-Path $Src 'diagnose-game.sh') $Out
Copy-Item (Join-Path $Src 'reset-prefix.sh') $Out
if (Test-Path (Join-Path $Src 'share\fex-emu')) {
    New-Item -ItemType Directory -Path (Join-Path $Out 'share\fex-emu') -Force | Out-Null
    Copy-Item (Join-Path $Src 'share\fex-emu\*') (Join-Path $Out 'share\fex-emu') -Recurse -Force
}
Copy-Item (Join-Path $Src 'share\*') (Join-Path $Out 'share') -Recurse -Force
if ($ReinstallBackup -and (Test-Path $ReinstallBackup)) {
    Copy-Item $ReinstallBackup (Join-Path $Out 'reinstall-proton.sh') -Force
}

Compress-Archive -Path (Join-Path $Out '*') -DestinationPath $Zip -Force

Write-Host ''
Write-Host 'Created (copy ONE of these to the Portal):'
Write-Host "  Folder: $Out"
Write-Host "  Zip:    $Zip"
Write-Host ''
Write-Host 'On Portal:'
Write-Host '  unzip portal-steam-bundle.zip -d portal-steam-bundle'
Write-Host '  cd portal-steam-bundle'
Write-Host '  sudo bash install-portal-steam.sh'
Write-Host '  portal-install-steam'
Write-Host '  bash reinstall-proton.sh          # Proton 11 + CachyOS only'
Write-Host '  sudo portal-install-controller'
Write-Host '  portal-steam --gaming'
