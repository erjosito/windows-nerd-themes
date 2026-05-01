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

# Detect unsupported Windows Terminal variants
$previewPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
$unpackagedPath = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"

if (-not (Test-Path $terminalSettingsPath)) {
    if (Test-Path $previewPath) {
        Write-Error "Windows Terminal Preview is not currently supported. Please install the stable version from the Microsoft Store."
        return
    }
    if (Test-Path $unpackagedPath) {
        Write-Error "Unpackaged Windows Terminal (e.g. scoop/winget portable) is not currently supported. Please install the stable version from the Microsoft Store."
        return
    }
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
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                try {
                    Copy-Item $sourcePath $destPath -Force
                } catch {
                    # File may be locked by WT — use stream copy to overwrite
                    try {
                        $bytes = [System.IO.File]::ReadAllBytes($sourcePath)
                        [System.IO.File]::WriteAllBytes($destPath, $bytes)
                    } catch {
                        Write-Warning "    Could not update $bgImage (file locked by WT — restart WT and re-run)"
                    }
                }
            }
            Write-Host "    ✓ $bgImage" -ForegroundColor Green
        } else {
            # Try to download from URL
            $imageUrl = $profile.Value.background_image_url
            if ($imageUrl -and -not $DryRun) {
                Write-Host "    ⬇ Downloading $bgImage..." -ForegroundColor Gray
                try {
                    $destDir = Split-Path $destPath -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
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

# --- Configure Terminal Profiles ---
# Strategy: find and style EXISTING dynamic profiles (those with a 'source' field)
# instead of creating new ones. This avoids crashes caused by duplicate profiles
# with explicit commandlines conflicting with WT's auto-generated profiles.

Write-Host "  Configuring Windows Terminal profiles..." -ForegroundColor Gray

$existingSettings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

# --- Merge color schemes first (needed for stale scheme cleanup) ---
$themeSchemes = @()
$themeSchemeNames = @()
foreach ($scheme in $Config.color_schemes) {
    $themeSchemes += $scheme
    $themeSchemeNames += $scheme.name
}
$mergedSchemes = @() + $themeSchemes
if ($existingSettings.schemes) {
    foreach ($existing in $existingSettings.schemes) {
        if ($existing.name -notin $themeSchemeNames) {
            $mergedSchemes += $existing
        }
    }
}
$mergedSchemeNames = $mergedSchemes | ForEach-Object { $_.name }

# --- Helper: apply theme visual properties to a profile ---
function Apply-ThemeStyling {
    param(
        [Parameter(Mandatory)] $TargetProfile,
        [Parameter(Mandatory)] $ThemeProfile
    )
    if ($ThemeProfile.color_scheme) {
        $TargetProfile | Add-Member -NotePropertyName colorScheme -NotePropertyValue $ThemeProfile.color_scheme -Force
    }
    if ($ThemeProfile.cursor_color) {
        $TargetProfile | Add-Member -NotePropertyName cursorColor -NotePropertyValue $ThemeProfile.cursor_color -Force
    }
    if ($ThemeProfile.cursor_shape) {
        $TargetProfile | Add-Member -NotePropertyName cursorShape -NotePropertyValue $ThemeProfile.cursor_shape -Force
    }
    if ($ThemeProfile.font_face -or $ThemeProfile.font_size) {
        $font = @{}
        if ($ThemeProfile.font_face) {
            # Validate font exists — missing fonts can crash WT
            $installedFonts = [System.Drawing.Text.InstalledFontCollection]::new().Families.Name
            if ($installedFonts -contains $ThemeProfile.font_face) {
                $font.face = $ThemeProfile.font_face
            } else {
                Write-Warning "Font '$($ThemeProfile.font_face)' not installed. Looking for fallback..."
                $fallback = $installedFonts | Where-Object { $_ -match 'Nerd Font|NF' } | Select-Object -First 1
                if ($fallback) {
                    $font.face = $fallback
                    Write-Host "  Using fallback font: $fallback"
                } else {
                    $font.face = "Cascadia Code"
                    Write-Host "  No Nerd Font found, using Cascadia Code"
                }
            }
        }
        if ($ThemeProfile.font_size) { $font.size = $ThemeProfile.font_size }
        $TargetProfile | Add-Member -NotePropertyName font -NotePropertyValue ([PSCustomObject]$font) -Force
    }
    if ($null -ne $ThemeProfile.opacity) {
        # Never set opacity < 100 — it enables acrylic transparency which triggers
        # a known WT crash (divide-by-zero in Terminal.Control.dll)
        $TargetProfile.PSObject.Properties.Remove("opacity")
    }
    if ($ThemeProfile.background_image) {
        $TargetProfile | Add-Member -NotePropertyName backgroundImage -NotePropertyValue "ms-appdata:///roaming/$($ThemeProfile.background_image)" -Force
        if ($null -ne $ThemeProfile.background_image_opacity) {
            $TargetProfile | Add-Member -NotePropertyName backgroundImageOpacity -NotePropertyValue $ThemeProfile.background_image_opacity -Force
        }
    } else {
        $TargetProfile.PSObject.Properties.Remove("backgroundImage")
        $TargetProfile.PSObject.Properties.Remove("backgroundImageOpacity")
    }
    if ($ThemeProfile.tab_title) {
        $TargetProfile | Add-Member -NotePropertyName tabTitle -NotePropertyValue $ThemeProfile.tab_title -Force
    }
    $TargetProfile | Add-Member -NotePropertyName hidden -NotePropertyValue $false -Force
    $TargetProfile | Add-Member -NotePropertyName historySize -NotePropertyValue 9001 -Force
    $TargetProfile | Add-Member -NotePropertyName closeOnExit -NotePropertyValue "graceful" -Force
    # Remove properties known to crash WT (divide-by-zero in Terminal.Control.dll)
    $TargetProfile.PSObject.Properties.Remove("background")
    $TargetProfile.PSObject.Properties.Remove("useAcrylic")
}

# --- Match theme profiles to existing dynamic profiles ---
$profileMatchers = @{
    'ubuntu'           = { param($p) $p.source -and $p.source -like 'CanonicalGroupLimited.Ubuntu*' }
    'powershell'       = { param($p) $p.source -and $p.source -eq 'Windows.Terminal.PowershellCore' }
    'cmd'              = { param($p) $p.guid -eq '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}' }
    'powershell_admin' = $null  # No dynamic equivalent — created if needed
}

$defaultProfileGuid = $null
$styledProfileGuids = @()

foreach ($profileEntry in $Config.profiles.PSObject.Properties) {
    $themeKey = $profileEntry.Name
    $themeProfile = $profileEntry.Value

    $matcher = $profileMatchers[$themeKey]
    $matched = $null

    if ($matcher) {
        $matched = $existingSettings.profiles.list | Where-Object { & $matcher $_ } | Select-Object -First 1
    }

    if ($matched) {
        Write-Host "    ✓ Styling dynamic profile: $($matched.name) (source: $($matched.source))" -ForegroundColor Green
        Apply-ThemeStyling -TargetProfile $matched -ThemeProfile $themeProfile
        $styledProfileGuids += $matched.guid
        if ($themeKey -eq 'ubuntu') { $defaultProfileGuid = $matched.guid }
    } elseif ($themeKey -eq 'powershell_admin' -and $themeProfile.elevate) {
        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($pwsh) {
            $existingAdmin = $existingSettings.profiles.list | Where-Object {
                $_.name -eq $themeProfile.name -and $_.elevate -eq $true
            }
            if ($existingAdmin) {
                Write-Host "    ✓ Styling existing admin profile: $($existingAdmin.name)" -ForegroundColor Green
                Apply-ThemeStyling -TargetProfile $existingAdmin -ThemeProfile $themeProfile
                $existingAdmin | Add-Member -NotePropertyName elevate -NotePropertyValue $true -Force
                $styledProfileGuids += $existingAdmin.guid
            } else {
                Write-Host "    + Creating admin profile: $($themeProfile.name)" -ForegroundColor Green
                $adminGuid = "{$(New-Guid)}"
                $adminProfile = [PSCustomObject]@{
                    guid        = $adminGuid
                    name        = $themeProfile.name
                    commandline = "pwsh.exe"
                    elevate     = $true
                    hidden      = $false
                }
                if ($themeProfile.starting_directory) {
                    $adminProfile | Add-Member -NotePropertyName startingDirectory -NotePropertyValue $themeProfile.starting_directory
                }
                Apply-ThemeStyling -TargetProfile $adminProfile -ThemeProfile $themeProfile
                $existingSettings.profiles.list = @($existingSettings.profiles.list) + @($adminProfile)
                $styledProfileGuids += $adminGuid
            }
        } else {
            Write-Warning "    pwsh.exe not found on PATH — skipping admin profile"
        }
    } elseif ($themeKey -ne 'powershell_admin') {
        Write-Warning "    No dynamic profile found for theme key '$themeKey' ($($themeProfile.name)) — skipping"
    }
}

# --- Clean up stale theme-created profiles from previous runs ---
# Stale profiles: no 'source' field, name matches a theme profile name,
# and not one we just styled (i.e. leftover from old script that created new profiles)
$themeProfileNames = $Config.profiles.PSObject.Properties | ForEach-Object { $_.Value.name }
$cleanedList = @()
foreach ($p in $existingSettings.profiles.list) {
    $isStale = (
        -not $p.source -and
        $p.name -in $themeProfileNames -and
        $p.guid -notin $styledProfileGuids
    )
    if ($isStale) {
        Write-Host "    🗑 Removing stale profile: $($p.name) ($($p.guid))" -ForegroundColor Yellow
    } else {
        # Sanitize all preserved profiles
        $p.PSObject.Properties.Remove("background")
        $p.PSObject.Properties.Remove("useAcrylic")
        if ($p.colorScheme -and $p.colorScheme -notin $mergedSchemeNames) {
            Write-Host "    ℹ Removing stale colorScheme '$($p.colorScheme)' from '$($p.name)'" -ForegroundColor Gray
            $p.PSObject.Properties.Remove("colorScheme")
        }
        $cleanedList += $p
    }
}

# --- Set default profile with fallback ---
if (-not $defaultProfileGuid) {
    $ps7 = $cleanedList | Where-Object { $_.source -eq 'Windows.Terminal.PowershellCore' } | Select-Object -First 1
    if ($ps7) { $defaultProfileGuid = $ps7.guid }
    else { $defaultProfileGuid = $existingSettings.defaultProfile }
    Write-Host "    ℹ No Ubuntu profile found — default set to fallback" -ForegroundColor Gray
}

# --- Update settings in-place (merge, don't rebuild from scratch) ---
$existingSettings | Add-Member -NotePropertyName defaultProfile -NotePropertyValue $defaultProfileGuid -Force
$existingSettings | Add-Member -NotePropertyName launchMode -NotePropertyValue $Config.launch_mode -Force
$existingSettings | Add-Member -NotePropertyName theme -NotePropertyValue "dark" -Force
$existingSettings.profiles.list = $cleanedList
$existingSettings | Add-Member -NotePropertyName schemes -NotePropertyValue $mergedSchemes -Force
if (-not $existingSettings.newTabMenu) {
    $existingSettings | Add-Member -NotePropertyName newTabMenu -NotePropertyValue @(@{ type = "remainingProfiles" })
}

if ($DryRun) {
    Write-Host "    [DRY RUN] Would write settings to: $terminalSettingsPath" -ForegroundColor Yellow
    Write-Host "    Profiles: $($cleanedList.Count)" -ForegroundColor Gray
} else {
    $backupPath = "$terminalSettingsPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $terminalSettingsPath $backupPath
    Write-Host "    ✓ Backup: $backupPath" -ForegroundColor Green
    $existingSettings | ConvertTo-Json -Depth 10 | Set-Content $terminalSettingsPath -Encoding UTF8
    Write-Host "    ✓ Settings written" -ForegroundColor Green
}

Write-Host "  ✓ Windows Terminal configured" -ForegroundColor Green

# --- Configure console host font (for PowerShell/cmd outside Windows Terminal) ---
$consoleFontName = $null
$consoleFontSize = 14
$psProfile = ($Config.profiles.PSObject.Properties | Where-Object { $_.Name -eq 'powershell' }).Value
if ($psProfile) {
    $consoleFontName = $psProfile.font_face
    if ($psProfile.font_size) { $consoleFontSize = $psProfile.font_size }
} else {
    $firstProfile = ($Config.profiles.PSObject.Properties | Select-Object -First 1).Value
    if ($firstProfile) { $consoleFontName = $firstProfile.font_face }
}
if ($consoleFontName) {
    Write-Host "  Setting default console font to '$consoleFontName' (${consoleFontSize}pt)..." -ForegroundColor Gray
    if (-not $DryRun) {
        $consoleRegPath = "HKCU:\Console"
        Set-ItemProperty -Path $consoleRegPath -Name "FaceName" -Value $consoleFontName
        # FontSize DWORD: height in the high word (height << 16)
        Set-ItemProperty -Path $consoleRegPath -Name "FontSize" -Value ([int]($consoleFontSize -shl 16))
        Set-ItemProperty -Path $consoleRegPath -Name "FontFamily" -Value 0x36  # TrueType
        Write-Host "    ✓ Console font set" -ForegroundColor Green
    } else {
        Write-Host "    [DRY RUN] Would set console font" -ForegroundColor Yellow
    }
}
