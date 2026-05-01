<#
.SYNOPSIS
    Windows Nerd Themes - Customize Windows with nerd themes.

.DESCRIPTION
    Applies a theme configuration to Windows Terminal, WSL, PowerShell,
    wallpaper, and screensaver. Themes are self-contained folders or zip files
    containing a theme.json and assets (wallpapers, fonts).

.PARAMETER Theme
    Name of the theme to apply (corresponds to a folder in themes/).

.PARAMETER Components
    Comma-separated list of components to configure. Default: all.
    Valid values: wallpaper, screensaver, terminal, wsl, powershell

.PARAMETER Exclude
    Comma-separated list of components to skip.

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER ThemeFile
    Path to a theme folder, .json file, or .zip package (overrides -Theme).

.EXAMPLE
    .\install.ps1 -Theme starwars
    .\install.ps1 -Theme motogp -Exclude wallpaper,screensaver
    .\install.ps1 -Theme starwars -Components terminal,wsl
    .\install.ps1 -ThemeFile C:\Downloads\my-theme.zip -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Theme = "starwars",

    [string[]]$Components = @("wallpaper", "screensaver", "terminal", "wsl", "powershell", "vscode"),

    [string[]]$Exclude = @("wallpaper", "screensaver"),

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

# --- Resolve Theme Path ---

$cleanupTempDir = $false

if ($ThemeFile) {
    if ($ThemeFile -match '\.zip$') {
        # Extract zip to temp folder
        $tempDir = Join-Path $env:TEMP "nerdtheme_$(Get-Random)"
        Expand-Archive -Path $ThemeFile -DestinationPath $tempDir -Force
        $themePath = $tempDir
        $cleanupTempDir = $true
    } elseif (Test-Path $ThemeFile -PathType Container) {
        $themePath = $ThemeFile
    } elseif ($ThemeFile -match '\.json$') {
        # Legacy: bare JSON file
        $themePath = Split-Path $ThemeFile -Parent
    } else {
        Write-Error "ThemeFile must be a folder, .json, or .zip: $ThemeFile"
        exit 1
    }
} else {
    $themePath = Join-Path $ScriptRoot "themes\$Theme"
}

# Find theme.json
$themeJsonPath = Join-Path $themePath "theme.json"
if (-not (Test-Path $themeJsonPath)) {
    # Fallback: look for <name>.json (legacy format)
    $themeJsonPath = Join-Path $themePath "$Theme.json"
    if (-not (Test-Path $themeJsonPath)) {
        Write-Error "Theme not found. Expected theme.json in: $themePath"
        exit 1
    }
}

# --- Load Theme ---

Write-Host @"

╔══════════════════════════════════════════════════╗
║        Windows Nerd Themes Installer             ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

$themeConfig = Get-Content $themeJsonPath -Raw | ConvertFrom-Json
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
    & "$ScriptRoot\scripts\configure-wallpaper.ps1" -Config $themeConfig.components.wallpaper -AssetsPath $themePath -DryRun:$DryRun
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
    & "$ScriptRoot\scripts\configure-terminal.ps1" -Config $themeConfig.components.windows_terminal -AssetsPath $themePath -DryRun:$DryRun
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
    & "$ScriptRoot\scripts\configure-powershell.ps1" -Config $themeConfig.components.powershell -ThemePath $themePath -DryRun:$DryRun
} elseif ("powershell" -in $Exclude) {
    Write-Skip "PowerShell (excluded)"
}

# --- Component: VSCode ---

if ("vscode" -in $activeComponents -and $themeConfig.components.vscode.enabled) {
    Write-Step "Configuring Visual Studio Code"
    & "$ScriptRoot\scripts\configure-vscode.ps1" -Config $themeConfig.components.vscode -DryRun:$DryRun
} elseif ("vscode" -in $Exclude) {
    Write-Skip "VSCode (excluded)"
}

# --- Cleanup ---

if ($cleanupTempDir -and (Test-Path $tempDir)) {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Done ---

Write-Host @"

╔══════════════════════════════════════════════════╗
║              Installation Complete!              ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "Theme '$($themeConfig.name)' applied successfully." -ForegroundColor White
Write-Host "Restart Windows Terminal to see all changes.`n" -ForegroundColor Gray
