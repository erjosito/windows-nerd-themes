<#
.SYNOPSIS
    Configure Visual Studio Code with theme settings.
#>
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,

    [switch]$DryRun
)

$settingsPath = "$env:APPDATA\Code\User\settings.json"
$settingsDir = Split-Path $settingsPath -Parent

if (-not (Test-Path $settingsDir)) {
    Write-Warning "VSCode settings folder not found. Is VSCode installed?"
    return
}

# --- Install Extensions ---

if ($Config.extensions) {
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        Write-Warning "  'code' command not found. Install VSCode CLI or add to PATH."
        return
    }

    # Filter to extensions not already installed
    $installedExts = code --list-extensions 2>$null
    $missingExts = $Config.extensions | Where-Object { $_ -notin $installedExts }

    if ($missingExts -and -not $DryRun) {
        Write-Host "  The following VSCode extensions are required by the theme:" -ForegroundColor Gray
        foreach ($ext in $missingExts) {
            Write-Host "    • $ext" -ForegroundColor White
        }
        $answer = Read-Host "  Install these extensions? [y/N]"
        if ($answer -ne 'y' -and $answer -ne 'Y') {
            Write-Host "  ⊘ Skipping VSCode configuration (required extensions not installed)" -ForegroundColor Yellow
            return
        }
    }

    foreach ($ext in $Config.extensions) {
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would install: $ext" -ForegroundColor Yellow
        } elseif ($ext -in $missingExts) {
            Write-Host "    ⬇ Installing $ext..." -ForegroundColor Gray
            code --install-extension $ext --force 2>$null
            Write-Host "    ✓ $ext" -ForegroundColor Green
        } else {
            Write-Host "    ✓ $ext (already installed)" -ForegroundColor Green
        }
    }
}

# --- Merge Settings ---

Write-Host "  Updating VSCode settings..." -ForegroundColor Gray

# Read existing settings (or empty object)
$existingSettings = @{}
if (Test-Path $settingsPath) {
    try {
        $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $existingSettings = @{}
    }
}

# Apply theme settings
$themeSettings = @{}

if ($Config.color_theme)    { $themeSettings["workbench.colorTheme"] = $Config.color_theme }
if ($Config.icon_theme)     { $themeSettings["workbench.iconTheme"] = $Config.icon_theme }
if ($Config.font_family)    { $themeSettings["editor.fontFamily"] = $Config.font_family }
if ($Config.font_size)      { $themeSettings["editor.fontSize"] = $Config.font_size }
if ($Config.font_ligatures) { $themeSettings["editor.fontLigatures"] = $Config.font_ligatures }

# Editor settings
if ($null -ne $Config.minimap)                   { $themeSettings["editor.minimap.enabled"] = $Config.minimap }
if ($null -ne $Config.bracket_pair_colorization) { $themeSettings["editor.bracketPairColorization.enabled"] = $Config.bracket_pair_colorization }
if ($null -ne $Config.sticky_scroll)             { $themeSettings["editor.stickyScroll.enabled"] = $Config.sticky_scroll }
if ($Config.cursor_blinking)                     { $themeSettings["editor.cursorBlinking"] = $Config.cursor_blinking }
if ($Config.cursor_style)                        { $themeSettings["editor.cursorStyle"] = $Config.cursor_style }
if ($Config.word_wrap)                           { $themeSettings["editor.wordWrap"] = $Config.word_wrap }
if ($Config.render_whitespace)                   { $themeSettings["editor.renderWhitespace"] = $Config.render_whitespace }

# Workbench settings
if ($Config.workbench) {
    if ($Config.workbench.activity_bar_location) { $themeSettings["workbench.activityBar.location"] = $Config.workbench.activity_bar_location }
    if ($Config.workbench.sidebar_position)      { $themeSettings["workbench.sideBar.location"] = $Config.workbench.sidebar_position }
    if ($Config.workbench.editor_tab_sizing)     { $themeSettings["workbench.editor.tabSizing"] = $Config.workbench.editor_tab_sizing }
    if ($Config.workbench.startup_editor)        { $themeSettings["workbench.startupEditor"] = $Config.workbench.startup_editor }
}

# Terminal settings
if ($Config.terminal) {
    if ($Config.terminal.font_family) {
        $themeSettings["terminal.integrated.fontFamily"] = $Config.terminal.font_family
    }
    if ($Config.terminal.font_size) {
        $themeSettings["terminal.integrated.fontSize"] = $Config.terminal.font_size
    }
    if ($Config.terminal.default_profile) {
        $themeSettings["terminal.integrated.defaultProfile.windows"] = $Config.terminal.default_profile
    }
    if ($Config.terminal.cursor_style) {
        $themeSettings["terminal.integrated.cursorStyle"] = $Config.terminal.cursor_style
    }
}

if ($DryRun) {
    Write-Host "    [DRY RUN] Would apply settings:" -ForegroundColor Yellow
    foreach ($key in $themeSettings.Keys) {
        Write-Host "      $key = $($themeSettings[$key])" -ForegroundColor Gray
    }
    return
}

# Backup
if (Test-Path $settingsPath) {
    $backupPath = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $settingsPath $backupPath
    Write-Host "    ✓ Backup: $backupPath" -ForegroundColor Green
}

# Merge: theme settings override, but preserve everything else
foreach ($key in $themeSettings.Keys) {
    $existingSettings[$key] = $themeSettings[$key]
}

$existingSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "    ✓ Settings written to: $settingsPath" -ForegroundColor Green

Write-Host "  ✓ VSCode configured" -ForegroundColor Green
