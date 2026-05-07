# Install-GrepForWindows.ps1
# Downloads grep-for-windows from GitHub, installs it as a PowerShell module
# under the user's modules path, and adds a single `Import-Module
# grep-for-windows` line to $PROFILE. Safe to re-run: idempotent and
# self-updating. Source: https://github.com/kithuto/grep-for-windows

$ModuleName  = 'grep-for-windows'
$RepoBase    = 'https://raw.githubusercontent.com/kithuto/grep-for-windows/main/module'
$ManifestUrl = "$RepoBase/$ModuleName.psd1"
$Psm1Url     = "$RepoBase/$ModuleName.psm1"

# 1. Pick the user's module directory. Prefer the first user-writable entry of
#    $env:PSModulePath; fall back to the canonical Documents path per edition.
$userModuleRoot = ($env:PSModulePath -split [IO.Path]::PathSeparator)[0]
if (-not $userModuleRoot -or -not $userModuleRoot.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) {
    $userModuleRoot = if ($PSVersionTable.PSEdition -eq 'Core') {
        Join-Path $HOME 'Documents\PowerShell\Modules'
    } else {
        Join-Path $HOME 'Documents\WindowsPowerShell\Modules'
    }
}
$installDir   = Join-Path $userModuleRoot $ModuleName
$manifestPath = Join-Path $installDir "$ModuleName.psd1"
$psm1Path     = Join-Path $installDir "$ModuleName.psm1"

# 2. Download the remote manifest first; the version it embeds determines
#    whether we even need to fetch the (much larger) .psm1.
Write-Host "Fetching $ModuleName manifest from GitHub..." -ForegroundColor Cyan
try {
    $remoteManifest = Invoke-RestMethod -Uri $ManifestUrl -ErrorAction Stop
} catch {
    Write-Host "$ModuleName : could not reach $ManifestUrl. Check your internet connection." -ForegroundColor Red
    return
}
if ($remoteManifest -notmatch "ModuleVersion\s*=\s*'([^']+)'") {
    Write-Host "$ModuleName : remote manifest is missing ModuleVersion field." -ForegroundColor Red
    return
}
$remoteVersion = [Version]$Matches[1]

# 3. If already at the same version, exit early so re-runs are cheap.
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $existing = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        if ($existing.Version -eq $remoteVersion) {
            Write-Host "$ModuleName $remoteVersion is already installed at $installDir"
            return
        }
        Write-Host "Updating $ModuleName from $($existing.Version) to $remoteVersion..."
    } catch {
        Write-Host "Existing manifest is invalid; reinstalling..." -ForegroundColor Yellow
    }
}

# 4. Download the module body now that we know we need it.
Write-Host "Fetching $ModuleName module body from GitHub..." -ForegroundColor Cyan
try {
    $remotePsm1 = Invoke-RestMethod -Uri $Psm1Url -ErrorAction Stop
} catch {
    Write-Host "$ModuleName : could not reach $Psm1Url. Check your internet connection." -ForegroundColor Red
    return
}

# 5. Write the module files.
if (-not (Test-Path -LiteralPath $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "Created $installDir"
}
Set-Content -LiteralPath $manifestPath -Value $remoteManifest -Encoding UTF8 -NoNewline
Set-Content -LiteralPath $psm1Path     -Value $remotePsm1     -Encoding UTF8 -NoNewline
Write-Host "Module files written to $installDir" -ForegroundColor Cyan

# 6. Ensure $PROFILE has an `Import-Module grep-for-windows` line.
$profilePath = $PROFILE
if (-not (Test-Path -LiteralPath $profilePath)) {
    $profileDir = Split-Path -Parent $profilePath
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host "Created profile file: $profilePath"
}
$profileContent = Get-Content -Raw -LiteralPath $profilePath -ErrorAction SilentlyContinue
$importPattern  = '(?m)^[ \t]*Import-Module\s+["'']?' + [regex]::Escape($ModuleName) + '["'']?'
if ($profileContent -notmatch $importPattern) {
    Add-Content -LiteralPath $profilePath -Value "`r`nImport-Module $ModuleName" -Encoding UTF8
    Write-Host "Added 'Import-Module $ModuleName' to $profilePath" -ForegroundColor Cyan
}

# 7. Load it now so `grep` is ready in the current session, not just on next launch.
Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
Import-Module $ModuleName -Force

Write-Host "$ModuleName $remoteVersion installed. 'grep' is ready to use." -ForegroundColor Green
