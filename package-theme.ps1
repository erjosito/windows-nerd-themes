<#
.SYNOPSIS
    Package a theme folder into a distributable .zip file.

.DESCRIPTION
    Creates a self-contained .zip from a theme folder, including:
    - theme.json (configuration)
    - wallpapers/ (background images)
    - fonts/ (optional Nerd Font files)

.PARAMETER Theme
    Name of the theme folder under themes/.

.PARAMETER OutputPath
    Where to save the .zip. Defaults to themes/<name>.zip.

.EXAMPLE
    .\package-theme.ps1 -Theme starwars
    .\package-theme.ps1 -Theme motogp -OutputPath C:\exports\motogp.zip
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Theme,

    [string]$OutputPath
)

$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$themePath = Join-Path $ScriptRoot "themes\$Theme"

if (-not (Test-Path $themePath)) {
    Write-Error "Theme folder not found: $themePath"
    exit 1
}

if (-not (Test-Path (Join-Path $themePath "theme.json"))) {
    Write-Error "theme.json not found in: $themePath"
    exit 1
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $ScriptRoot "themes\$Theme.zip"
}

# Remove existing zip
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

Write-Host "Packaging theme: $Theme" -ForegroundColor Cyan

# Create zip
Compress-Archive -Path "$themePath\*" -DestinationPath $OutputPath -CompressionLevel Optimal

$size = (Get-Item $OutputPath).Length / 1MB
Write-Host "✓ Created: $OutputPath ($($size.ToString('N1')) MB)" -ForegroundColor Green
Write-Host ""
Write-Host "To install from zip:" -ForegroundColor Gray
Write-Host "  .\install.ps1 -ThemeFile $OutputPath" -ForegroundColor White
