<#
.SYNOPSIS
    Configure Windows desktop wallpaper.
#>
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,

    [Parameter(Mandatory)]
    [string]$AssetsPath,

    [switch]$DryRun
)

$wallpaperPath = Join-Path $AssetsPath $Config.image
$style = switch ($Config.style) {
    "fill"    { "10" }
    "fit"     { "6" }
    "stretch" { "2" }
    "tile"    { "0" }
    "center"  { "0" }
    "span"    { "22" }
    default   { "10" }
}

# Check if wallpaper image exists, download if not
if (-not (Test-Path $wallpaperPath)) {
    if ($Config.image_url) {
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would download wallpaper from: $($Config.image_url)" -ForegroundColor Yellow
        } else {
            Write-Host "    ⬇ Downloading wallpaper..." -ForegroundColor Gray
            try {
                Invoke-WebRequest -Uri $Config.image_url -OutFile $wallpaperPath -UseBasicParsing
                Write-Host "    ✓ Wallpaper downloaded" -ForegroundColor Green
            } catch {
                Write-Warning "    Failed to download wallpaper: $_"
                return
            }
        }
    } else {
        Write-Warning "    Wallpaper image not found: $wallpaperPath"
        Write-Warning "    Place your wallpaper in: $AssetsPath"
        return
    }
}

if ($DryRun) {
    Write-Host "    [DRY RUN] Would set wallpaper: $wallpaperPath (style: $($Config.style))" -ForegroundColor Yellow
    return
}

# Set wallpaper style in registry
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value $style
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0"

# Set wallpaper using SystemParametersInfo
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public const int SPI_SETDESKWALLPAPER = 20;
    public const int SPIF_UPDATEINIFILE = 0x01;
    public const int SPIF_SENDWININICHANGE = 0x02;
}
"@

$result = [Wallpaper]::SystemParametersInfo(
    [Wallpaper]::SPI_SETDESKWALLPAPER,
    0,
    $wallpaperPath,
    [Wallpaper]::SPIF_UPDATEINIFILE -bor [Wallpaper]::SPIF_SENDWININICHANGE
)

if ($result) {
    Write-Host "  ✓ Wallpaper set: $wallpaperPath" -ForegroundColor Green
} else {
    Write-Warning "  Failed to set wallpaper"
}
