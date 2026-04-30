<#
.SYNOPSIS
    Configure Windows screensaver.
#>
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,

    [switch]$DryRun
)

$screensaverMap = @{
    "mystify"  = "Mystify.scr"
    "ribbons"  = "Ribbons.scr"
    "bubbles"  = "Bubbles.scr"
    "blank"    = "scrnsave.scr"
    "photos"   = "PhotoScreensaver.scr"
}

$scrFile = $screensaverMap[$Config.type]
if (-not $scrFile) {
    $scrFile = "$($Config.type).scr"
}

$scrPath = "$env:SystemRoot\System32\$scrFile"
$timeout = ($Config.timeout_minutes * 60)

if ($DryRun) {
    Write-Host "    [DRY RUN] Would set screensaver: $($Config.type) (timeout: $($Config.timeout_minutes) min)" -ForegroundColor Yellow
    return
}

# Set screensaver via registry
$regPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1"
Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value $timeout.ToString()
Set-ItemProperty -Path $regPath -Name "SCRNSAVE.EXE" -Value $scrPath
Set-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -Value "0"

Write-Host "  ✓ Screensaver: $($Config.type) (timeout: $($Config.timeout_minutes) min)" -ForegroundColor Green
