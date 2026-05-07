# Install-GrepForWindows.ps1
# Downloads grep-for-windows from GitHub and drops it into the user's modules
# path. PowerShell's automatic module loading picks it up the first time you
# run `grep` in any new session. Safe to re-run: idempotent and self-updating.
# Source: https://github.com/kithuto/grep-for-windows

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
}
Set-Content -LiteralPath $manifestPath -Value $remoteManifest -Encoding UTF8 -NoNewline
Set-Content -LiteralPath $psm1Path     -Value $remotePsm1     -Encoding UTF8 -NoNewline
Write-Host "Module files written to $installDir" -ForegroundColor Cyan

# 6. Load it now so `grep` is ready in the current session, not just on next launch.
Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
Import-Module $ModuleName -Force

Write-Host "$ModuleName $remoteVersion installed. 'grep' is ready to use." -ForegroundColor Green