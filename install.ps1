<#
.SYNOPSIS
    Windows Nerd Themes - Customize Windows with nerd themes.

.DESCRIPTION
    Applies a theme configuration to Windows Terminal, WSL, PowerShell,
    wallpaper, and screensaver. Themes are defined as JSON files.

.PARAMETER Theme
    Name of the theme to apply (corresponds to a file in themes/ folder).

.PARAMETER Components
    Comma-separated list of components to configure. Default: all.
    Valid values: wallpaper, screensaver, terminal, wsl, powershell

.PARAMETER Exclude
    Comma-separated list of components to skip.

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER ThemeFile
    Path to a custom theme JSON file (overrides -Theme).

.EXAMPLE
    .\install.ps1 -Theme star-wars
    .\install.ps1 -Theme star-wars -Exclude wallpaper,screensaver
    .\install.ps1 -Theme star-wars -Components terminal,wsl
    .\install.ps1 -ThemeFile C:\mytheme.json -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Theme = "star-wars",

    [string[]]$Components = @("wallpaper", "screensaver", "terminal", "wsl", "powershell"),

    [string[]]$Exclude = @(),

    [switch]$DryRun,

    [string]$ThemeFile
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot

# --- Helper Functions ---

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  ⊘ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Gray
}

# --- Load Theme ---

Write-Host @"

╔══════════════════════════════════════════════════╗
║        Windows Nerd Themes Installer            ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

if ($ThemeFile) {
    $themeFilePath = $ThemeFile
} else {
    $themeFilePath = Join-Path $ScriptRoot "themes\$Theme.json"
}

if (-not (Test-Path $themeFilePath)) {
    Write-Error "Theme file not found: $themeFilePath"
    exit 1
}

$themeConfig = Get-Content $themeFilePath -Raw | ConvertFrom-Json
Write-Host "`nTheme: $($themeConfig.name)" -ForegroundColor White
Write-Host "Description: $($themeConfig.description)" -ForegroundColor Gray

# Filter components
$activeComponents = $Components | Where-Object { $_ -notin $Exclude }
Write-Host "Components: $($activeComponents -join ', ')" -ForegroundColor Gray

if ($DryRun) {
    Write-Host "`n[DRY RUN MODE - No changes will be made]" -ForegroundColor Yellow
}

# --- Component: Wallpaper ---

if ("wallpaper" -in $activeComponents -and $themeConfig.components.wallpaper.enabled) {
    Write-Step "Configuring Desktop Wallpaper"
    & "$ScriptRoot\scripts\configure-wallpaper.ps1" -Config $themeConfig.components.wallpaper -AssetsPath "$ScriptRoot\assets\wallpapers" -DryRun:$DryRun
} elseif ("wallpaper" -in $Exclude) {
    Write-Skip "Wallpaper (excluded)"
}

# --- Component: Screensaver ---

if ("screensaver" -in $activeComponents -and $themeConfig.components.screensaver.enabled) {
    Write-Step "Configuring Screensaver"
    & "$ScriptRoot\scripts\configure-screensaver.ps1" -Config $themeConfig.components.screensaver -DryRun:$DryRun
} elseif ("screensaver" -in $Exclude) {
    Write-Skip "Screensaver (excluded)"
}

# --- Component: Windows Terminal ---

if ("terminal" -in $activeComponents -and $themeConfig.components.windows_terminal.enabled) {
    Write-Step "Configuring Windows Terminal"
    & "$ScriptRoot\scripts\configure-terminal.ps1" -Config $themeConfig.components.windows_terminal -AssetsPath "$ScriptRoot\assets\wallpapers" -DryRun:$DryRun
} elseif ("terminal" -in $Exclude) {
    Write-Skip "Windows Terminal (excluded)"
}

# --- Component: WSL ---

if ("wsl" -in $activeComponents -and $themeConfig.components.wsl.enabled) {
    Write-Step "Configuring WSL ($($themeConfig.components.wsl.distro))"
    & "$ScriptRoot\scripts\configure-wsl.ps1" -Config $themeConfig.components.wsl -DryRun:$DryRun
} elseif ("wsl" -in $Exclude) {
    Write-Skip "WSL (excluded)"
}

# --- Component: PowerShell ---

if ("powershell" -in $activeComponents -and $themeConfig.components.powershell.enabled) {
    Write-Step "Configuring PowerShell"
    & "$ScriptRoot\scripts\configure-powershell.ps1" -Config $themeConfig.components.powershell -DryRun:$DryRun
} elseif ("powershell" -in $Exclude) {
    Write-Skip "PowerShell (excluded)"
}

# --- Done ---

Write-Host @"

╔══════════════════════════════════════════════════╗
║              Installation Complete!              ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "Theme '$($themeConfig.name)' applied successfully." -ForegroundColor White
Write-Host "Restart Windows Terminal to see all changes.`n" -ForegroundColor Gray
