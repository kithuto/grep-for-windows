# --- grep-for-windows: start ---
# version: 1.0.0
# grep-for-windows provides a Linux-style grep command for PowerShell.
# Source: https://github.com/kithuto/grep-for-windows

# Renders a line with grep-style colors:
# - file path in magenta
# - matches highlighted in red
function Write-GrepColoredLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber,

        [Parameter(Mandatory = $true)]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [bool]$CaseSensitive = $true,
        [bool]$Literal = $false
    )

    $regexPattern = if ($Literal) { [regex]::Escape($Pattern) } else { $Pattern }
    $options = [System.Text.RegularExpressions.RegexOptions]::None
    if (-not $CaseSensitive) {
        $options = $options -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    }

    try {
        $grep_matches = [regex]::Matches($Line, $regexPattern, $options)
    } catch {
        # If the regex pattern is invalid, display the line without highlighting.
        $grep_matches = @()
    }

    Write-Host "${Path}:" -ForegroundColor Magenta -NoNewline
    Write-Host "${LineNumber}: " -NoNewline

    if ($grep_matches.Count -eq 0 -or ($grep_matches | Where-Object { $_.Length -eq 0 }).Count -gt 0) {
        Write-Host $Line
        return
    }

    $cursor = 0
    foreach ($m in $grep_matches) {
        if ($m.Index -gt $cursor) {
            Write-Host $Line.Substring($cursor, $m.Index - $cursor) -NoNewline
        }
        Write-Host $m.Value -ForegroundColor Red -NoNewline
        $cursor = $m.Index + $m.Length
    }

    if ($cursor -lt $Line.Length) {
        Write-Host $Line.Substring($cursor) -NoNewline
    }

    Write-Host
}

# Parses extra arguments and returns the list of directories to exclude from search.
function Get-GrepExcludedDirs {
    param(
        [string[]]$ExtraArgs
    )

    # Add folder names here to always exclude them, e.g. @('node_modules', '.git', '__pycache__')
    $excludedDirs = @()

    foreach ($arg in $ExtraArgs) {
        if ([string]::IsNullOrWhiteSpace($arg)) {
            continue
        }

        if ($arg -like '--exclude-dir=*') {
            $dir = $arg.Substring('--exclude-dir='.Length).Trim()
            if ([string]::IsNullOrWhiteSpace($dir)) {
                throw "invalid argument: '$arg'. Use --exclude-dir=folder_name"
            }
            $excludedDirs += $dir
            continue
        }

        throw "unrecognized argument: '$arg'. Only --exclude-dir=folder_name is supported"
    }

    return ,$excludedDirs
}

# Returns $true if the given path falls inside one of the excluded directories.
function Test-GrepExcludedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ExcludedDirs
    )

    foreach ($dir in $ExcludedDirs) {
        if ([string]::IsNullOrWhiteSpace($dir)) {
            continue
        }

        if ($FullPath -match "\\$([regex]::Escape($dir))\\") {
            return $true
        }
    }

    return $false
}

# grep: text search in files (literal by default, regex with -e | --regexp)
# Usage: grep [-h | --help] [--version] [--update] [-r] [-i | --ignore-case] [-e | --regexp] <pattern> [path] [--exclude-dir=folder ...]
function grep {
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Pattern,

        [Parameter(Position = 1)]
        [string]$Path = ".",

        [switch]$r,            # recursive search
        [switch]$i,            # case-insensitive
        [switch]$ignore_case,  # long alias for -i
        [switch]$e,            # interpret pattern as regex
        [switch]$regexp,       # long alias for -e
        [switch]$h,            # show help

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ExtraArgs
    )

    if ($h -or $Pattern -eq '--help') {
        Write-Host
        Write-Host "  grep-for-windows" -ForegroundColor Cyan -NoNewline
        Write-Host " — Linux-style grep for PowerShell"
        Write-Host
        Write-Host "  USAGE" -ForegroundColor Yellow
        Write-Host "    grep " -NoNewline
        Write-Host "[-h | --help]" -ForegroundColor Green -NoNewline
        Write-Host " [--version] [--update] [-r] [-i | --ignore-case] [-e | --regexp]"
        Write-Host "         <pattern> [path] [--exclude-dir=folder ...]"
        Write-Host
        Write-Host "  OPTIONS" -ForegroundColor Yellow
        Write-Host "    " -NoNewline; Write-Host "-h" -ForegroundColor Green -NoNewline; Write-Host ", " -NoNewline; Write-Host "--help" -ForegroundColor Green -NoNewline; Write-Host "           Shows this help and exits."
        Write-Host "        " -NoNewline; Write-Host "--version" -ForegroundColor Green -NoNewline; Write-Host "            Shows the installed version and exits."
        Write-Host "        " -NoNewline; Write-Host "--update" -ForegroundColor Green -NoNewline; Write-Host "             Checks for a newer version on GitHub and updates if found."
        Write-Host "    " -NoNewline; Write-Host "-r" -ForegroundColor Green -NoNewline; Write-Host "                    Recursive search through subdirectories."
        Write-Host "    " -NoNewline; Write-Host "-i" -ForegroundColor Green -NoNewline; Write-Host ", " -NoNewline; Write-Host "--ignore-case" -ForegroundColor Green -NoNewline; Write-Host "    Case-insensitive match."
        Write-Host "    " -NoNewline; Write-Host "-e" -ForegroundColor Green -NoNewline; Write-Host ", " -NoNewline; Write-Host "--regexp" -ForegroundColor Green -NoNewline; Write-Host "         Interpret pattern as a regular expression."
        Write-Host "        " -NoNewline; Write-Host "--exclude-dir=NAME" -ForegroundColor Green -NoNewline; Write-Host "   Skip any directory named NAME. Repeatable."
        Write-Host
        Write-Host "  ARGUMENTS" -ForegroundColor Yellow
        Write-Host "    " -NoNewline; Write-Host "<pattern>" -ForegroundColor Magenta -NoNewline; Write-Host "            Required. The text or regex to search for."
        Write-Host "    " -NoNewline; Write-Host "[path]" -ForegroundColor Magenta -NoNewline; Write-Host "               File or directory to search. Defaults to current directory."
        Write-Host
        Write-Host "  EXAMPLES" -ForegroundColor Yellow
        Write-Host "    grep " -NoNewline; Write-Host "`"TODO`"" -ForegroundColor DarkCyan
        Write-Host "    grep -r -i " -NoNewline; Write-Host "`"error`"" -ForegroundColor DarkCyan -NoNewline; Write-Host " C:\projects\myapp"
        Write-Host "    grep -r -e " -NoNewline; Write-Host "`"[\w.+-]+@[\w-]+\.[\w.-]+`"" -ForegroundColor DarkCyan -NoNewline; Write-Host " ."
        Write-Host "    grep -r " -NoNewline; Write-Host "`"import`"" -ForegroundColor DarkCyan -NoNewline; Write-Host " . --exclude-dir=node_modules --exclude-dir=dist"
        Write-Host
        return
    }

    if ($Pattern -eq '--update') {
        $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
        $installedVersion = if ($profileContent -match '# --- grep-for-windows: start ---\s*\r?\n# version:\s*(.+)') {
            $Matches[1].Trim()
        } else { $null }

        Write-Host "Checking for updates..." -ForegroundColor Cyan

        try {
            $remoteScript = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1' -ErrorAction Stop
        } catch {
            Write-Host "grep: could not reach GitHub. Check your internet connection." -ForegroundColor Red
            return
        }

        $remoteVersion = if ($remoteScript -match '# version:\s*(.+)') { $Matches[1].Trim() } else { $null }

        if (-not $remoteVersion) {
            Write-Host "grep: could not determine the remote version." -ForegroundColor Red
            return
        }

        if ($installedVersion -eq $remoteVersion) {
            Write-Host "grep-for-windows $installedVersion is already up to date."
            return
        }

        Invoke-Expression $remoteScript
        return
    }

    if ($Pattern -eq '--version') {
        $hasExtraArgs = (
            $Path -ne '.' -or
            $r -or $i -or $ignore_case -or $e -or $regexp -or
            ($ExtraArgs -and $ExtraArgs.Count -gt 0)
        )
        if ($hasExtraArgs) {
            Write-Host "grep: --version cannot be combined with other arguments." -ForegroundColor Red
            return
        }
        $installedVersion = if ($MyInvocation.MyCommand.ScriptBlock.Module) {
            # loaded as module — not expected, but handled gracefully
            $null
        } else {
            $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
            if ($profileContent -match '# --- grep-for-windows: start ---\s*\r?\n# version:\s*(.+)') {
                $Matches[1].Trim()
            } else {
                $null
            }
        }
        if ($installedVersion) {
            Write-Host "grep-for-windows $installedVersion"
        } else {
            Write-Host "grep-for-windows (version unknown)"
        }
        return
    }

    if ([string]::IsNullOrEmpty($Pattern)) {
        Write-Host "grep: a pattern is required. Run 'grep -h' for help." -ForegroundColor Red
        return
    }

    # If $Path starts with '-' it is an unknown flag (PowerShell placed it there
    # because it was preceded by '--'); move it to ExtraArgs for validation.
    if ($Path -like '-*') {
        $ExtraArgs = @($Path) + @($ExtraArgs | Where-Object { $_ })
        $Path = '.'
    }

    try {
        $excludedDirs = Get-GrepExcludedDirs -ExtraArgs $ExtraArgs
    } catch {
        Write-Host "grep: $_" -ForegroundColor Red
        return
    }

    $caseSensitive = -not ($i -or $ignore_case)
    $recurse       = $r.IsPresent
    $useRegex      = $e.IsPresent -or $regexp.IsPresent

    $files = Get-ChildItem -Path $Path -Recurse:$recurse -File -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-GrepExcludedPath -FullPath $_.FullName -ExcludedDirs $excludedDirs) }

    if ($useRegex) {
        $files |
            Select-String -Pattern $Pattern -CaseSensitive:$caseSensitive |
            ForEach-Object {
                Write-GrepColoredLine -Path $_.Path -LineNumber $_.LineNumber -Line $_.Line.TrimEnd() -Pattern $Pattern -CaseSensitive $caseSensitive
            }
    } else {
        $files |
            Select-String -Pattern $Pattern -CaseSensitive:$caseSensitive -SimpleMatch |
            ForEach-Object {
                Write-GrepColoredLine -Path $_.Path -LineNumber $_.LineNumber -Line $_.Line.TrimEnd() -Pattern $Pattern -CaseSensitive $caseSensitive -Literal $true
            }
    }
}
# --- grep-for-windows: end ---
