<#
.SYNOPSIS
    Configure Windows Terminal with theme settings.
#>
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,

    [Parameter(Mandatory)]
    [string]$AssetsPath,

    [switch]$DryRun
)

$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$terminalRoamingPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\RoamingState"

if (-not (Test-Path $terminalSettingsPath)) {
    Write-Warning "Windows Terminal settings not found. Is Windows Terminal installed?"
    return
}

# --- Install Nerd Fonts ---

if ($Config.nerd_fonts) {
    Write-Host "  Installing Nerd Fonts..." -ForegroundColor Gray
    $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

    foreach ($font in $Config.nerd_fonts) {
        $fontInstalled = Get-ChildItem "$fontsFolder\*$($font.name.Split(' ')[0])*" -ErrorAction SilentlyContinue
        if ($fontInstalled) {
            Write-Host "    ✓ $($font.name) already installed" -ForegroundColor Green
            continue
        }

        if ($DryRun) {
            Write-Host "    [DRY RUN] Would install: $($font.name)" -ForegroundColor Yellow
            continue
        }

        Write-Host "    ⬇ Downloading $($font.name)..." -ForegroundColor Gray
        $zipPath = "$env:TEMP\$($font.name -replace ' ', '_').zip"
        try {
            Invoke-WebRequest -Uri $font.url -OutFile $zipPath -UseBasicParsing
            $extractPath = "$env:TEMP\nerd_font_extract"
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

            Get-ChildItem "$extractPath\*.ttf", "$extractPath\*.otf" | ForEach-Object {
                Copy-Item $_.FullName $fontsFolder -Force
                # Register font
                $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
                $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                New-ItemProperty -Path $regPath -Name "$fontName (TrueType)" -Value $_.FullName -PropertyType String -Force | Out-Null
            }

            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    ✓ $($font.name) installed" -ForegroundColor Green
        } catch {
            Write-Warning "    Failed to install $($font.name): $_"
        }
    }
}

# --- Copy Background Images ---

Write-Host "  Copying background images..." -ForegroundColor Gray
if (-not (Test-Path $terminalRoamingPath)) {
    New-Item -ItemType Directory -Path $terminalRoamingPath -Force | Out-Null
}

foreach ($profile in $Config.profiles.PSObject.Properties) {
    $bgImage = $profile.Value.background_image
    if ($bgImage) {
        $sourcePath = Join-Path $AssetsPath $bgImage
        $destPath = Join-Path $terminalRoamingPath $bgImage

        if (Test-Path $sourcePath) {
            if (-not $DryRun) {
                Copy-Item $sourcePath $destPath -Force
            }
            Write-Host "    ✓ $bgImage" -ForegroundColor Green
        } else {
            # Try to download from URL
            $imageUrl = $profile.Value.background_image_url
            if ($imageUrl -and -not $DryRun) {
                Write-Host "    ⬇ Downloading $bgImage..." -ForegroundColor Gray
                try {
                    Invoke-WebRequest -Uri $imageUrl -OutFile $destPath -UseBasicParsing
                    Write-Host "    ✓ $bgImage (downloaded)" -ForegroundColor Green
                } catch {
                    Write-Warning "    Could not download $bgImage. Place it manually in: $terminalRoamingPath"
                }
            } elseif ($DryRun) {
                Write-Host "    [DRY RUN] Would copy/download: $bgImage" -ForegroundColor Yellow
            } else {
                Write-Warning "    Image not found: $bgImage - Place it in $AssetsPath or provide a URL."
            }
        }
    }
}

# --- Generate Terminal Settings ---

Write-Host "  Generating Windows Terminal settings..." -ForegroundColor Gray

# Read existing settings to preserve actions/keybindings
$existingSettings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

# Build profiles list
$profilesList = @()
foreach ($profileEntry in $Config.profiles.PSObject.Properties) {
    $p = $profileEntry.Value
    $profileObj = @{
        name              = $p.name
        backgroundImage   = "ms-appdata:///roaming/$($p.background_image)"
        backgroundImageOpacity = $p.background_image_opacity
        colorScheme       = $p.color_scheme
        cursorColor       = $p.cursor_color
        cursorShape       = $p.cursor_shape
        closeOnExit       = "graceful"
        historySize       = 9001
        hidden            = $false
        font              = @{
            face = $p.font_face
            size = $p.font_size
        }
        opacity           = $p.opacity
        useAcrylic        = $false
    }

    if ($p.commandline) { $profileObj.commandline = $p.commandline }
    if ($p.background_color) { $profileObj.background = $p.background_color }
    if ($p.tab_title) { $profileObj.tabTitle = $p.tab_title }
    if ($p.elevate) { $profileObj.elevate = $true }
    if ($p.starting_directory) { $profileObj.startingDirectory = $p.starting_directory }

    # Generate a consistent GUID from the name
    $guidBytes = [System.Text.Encoding]::UTF8.GetBytes($p.name)
    $hash = [System.Security.Cryptography.MD5]::Create().ComputeHash($guidBytes)
    $guid = [guid]::new($hash[0..3] + $hash[4..5] + $hash[6..7] + $hash[8..15])
    $profileObj.guid = "{$guid}"

    $profilesList += $profileObj
}

# Preserve existing profiles that aren't in our theme (like VS Dev shells, etc.)
$themeProfileNames = $Config.profiles.PSObject.Properties | ForEach-Object { $_.Value.name }
$existingOtherProfiles = $existingSettings.profiles.list | Where-Object {
    $_.name -notin $themeProfileNames -and
    $_.name -ne "ubuntu" -and $_.name -ne "Ubuntu" -and
    $_.name -ne "PowerShell" -and $_.name -ne "cmd" -and
    $_.name -ne "Command Prompt" -and $_.name -ne "PowerShell (Admin)"
}

if ($existingOtherProfiles) {
    $profilesList += $existingOtherProfiles
}

# Build color schemes
$schemes = @()
foreach ($scheme in $Config.color_schemes) {
    $schemes += $scheme
}

# Assemble final settings
$newSettings = @{
    '$help'   = "https://aka.ms/terminal-documentation"
    '$schema' = "https://aka.ms/terminal-profiles-schema"
    defaultProfile = $profilesList[0].guid
    launchMode = $Config.launch_mode
    theme = "dark"
    themes = @()
    "warning.confirmCloseAllTabs" = -not $Config.confirm_close_all_tabs
    profiles = @{
        defaults = @{}
        list = $profilesList
    }
    schemes = $schemes
    actions = $existingSettings.actions
    keybindings = $existingSettings.keybindings
    newTabMenu = @(@{ type = "remainingProfiles" })
}

if ($DryRun) {
    Write-Host "    [DRY RUN] Would write settings to: $terminalSettingsPath" -ForegroundColor Yellow
    Write-Host "    Profiles: $($profilesList.Count)" -ForegroundColor Gray
} else {
    # Backup existing settings
    $backupPath = "$terminalSettingsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $terminalSettingsPath $backupPath
    Write-Host "    ✓ Backup: $backupPath" -ForegroundColor Green

    $newSettings | ConvertTo-Json -Depth 10 | Set-Content $terminalSettingsPath -Encoding UTF8
    Write-Host "    ✓ Settings written" -ForegroundColor Green
}

Write-Host "  ✓ Windows Terminal configured" -ForegroundColor Green
