# --- grep-for-windows: start ---
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
        $matches = [regex]::Matches($Line, $regexPattern, $options)
    } catch {
        # If the regex pattern is invalid, display the line without highlighting.
        $matches = @()
    }

    Write-Host "${Path}:" -ForegroundColor Magenta -NoNewline
    Write-Host "${LineNumber}: " -NoNewline

    if ($matches.Count -eq 0 -or ($matches | Where-Object { $_.Length -eq 0 }).Count -gt 0) {
        Write-Host $Line
        return
    }

    $cursor = 0
    foreach ($m in $matches) {
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
                throw "Invalid argument: '$arg'. Use --exclude-dir=folder_name"
            }
            $excludedDirs += $dir
            continue
        }

        throw "Unrecognized argument: '$arg'. Only --exclude-dir=folder_name is supported"
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
# Usage: grep [-r] [-i | --ignore-case] [-e | --regexp] <pattern> [path] [--exclude-dir=folder ...]
function grep {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,

        [Parameter(Position = 1)]
        [string]$Path = ".",

        [switch]$r,            # recursive search
        [switch]$i,            # case-insensitive
        [switch]$ignore_case,  # long alias for -i
        [switch]$e,            # interpret pattern as regex
        [switch]$regexp,       # long alias for -e

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ExtraArgs
    )

    try {
        $excludedDirs = Get-GrepExcludedDirs -ExtraArgs $ExtraArgs
    } catch {
        Write-Error $_
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
