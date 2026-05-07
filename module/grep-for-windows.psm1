# grep-for-windows.psm1
# Linux-style grep for PowerShell. Source: https://github.com/kithuto/grep-for-windows
# Public surface: grep, Uninstall-GrepForWindows. All other functions are private helpers.

# Renders a matching line: [path:][lineno: ]line, with hits highlighted in red.
# Empty Path / LineNumber<=0 skips the corresponding prefix.
function Write-GrepColoredLine {
    param(
        [string]$Path = '',
        [int]$LineNumber = 0,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Line,
        [Parameter(Mandatory)] [regex]$HighlightRegex
    )

    if ($Path)             { Write-Host "${Path}:" -ForegroundColor Magenta -NoNewline }
    if ($LineNumber -gt 0) { Write-Host "${LineNumber}: " -NoNewline }

    $hits = $HighlightRegex.Matches($Line)
    # Skip the highlight loop on no hits or any zero-length match (would loop forever).
    if ($hits.Count -eq 0 -or $hits[0].Length -eq 0) {
        Write-Host $Line
        return
    }

    $cursor = 0
    foreach ($m in $hits) {
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

# Renders a context line (no highlight) with grep's '-' separator instead of ':'.
# Empty Path / LineNumber<=0 skips the corresponding prefix.
function Write-GrepContextLine {
    param(
        [string]$Path = '',
        [int]$LineNumber = 0,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Line
    )
    if ($Path)             { Write-Host "${Path}-" -ForegroundColor Magenta -NoNewline }
    if ($LineNumber -gt 0) { Write-Host "${LineNumber}- " -NoNewline }
    Write-Host $Line
}

# Renders one option row of the help text aligned on a single column.
function Write-GrepHelpRow {
    param([string]$Short, [Parameter(Mandatory)] [string]$Long, [Parameter(Mandatory)] [string]$Desc)
    Write-Host '    ' -NoNewline
    if ($Short) {
        Write-Host $Short -ForegroundColor Green -NoNewline
        Write-Host ', ' -NoNewline
        $col = 4 + $Short.Length + 2
    } else {
        Write-Host '    ' -NoNewline
        $col = 8
    }
    Write-Host $Long -ForegroundColor Green -NoNewline
    $col += $Long.Length
    # 34 = width of the longest row ('-B NUM, --before-context=NUM' = 32) + 2 spaces.
    Write-Host (' ' * [Math]::Max(2, 34 - $col)) -NoNewline
    Write-Host $Desc
}

# Returns folder names to always exclude. Customise by setting
# $global:GrepAlwaysExcludedDirs in your $PROFILE *after* Import-Module.
# Example: $global:GrepAlwaysExcludedDirs = @('node_modules', '.git', '__pycache__')
function Get-GrepAlwaysExcludedDirs {
    if ($null -ne $global:GrepAlwaysExcludedDirs) {
        return @($global:GrepAlwaysExcludedDirs)
    }
    return @()
}

# grep: Linux-style search. Literal by default, regex with -e / --regexp.
# Uses a non-advanced function (no CmdletBinding) so PowerShell's case-insensitive
# parameter binder cannot collapse case-distinct flags such as -v vs -V or -c vs -C.
# All command-line tokens land in $args and are parsed manually.
function grep {
    begin {
        $stdinLines = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($null -ne $_) { $stdinLines.Add([string]$_) }
    }

    end {
        $expectingPipeline = [bool]$MyInvocation.ExpectingInput

        $flagHelp = $false; $flagVersion = $false; $flagUpdate = $false
        $flagRecursive = $false; $flagIgnoreCase = $false; $flagFixed = $false
        $flagInvert = $false; $flagCount = $false; $flagFiles = $false
        $flagFilesNoMatch = $false; $flagQuiet = $false; $flagLineMatch = $false
        $flagWord = $false; $flagOnly = $false; $flagLineNumber = $false
        $afterCtx = -1; $beforeCtx = -1; $ctxBoth = -1; $maxCount = -1

        $excludeDirs = [System.Collections.Generic.List[string]]::new()
        foreach ($d in (Get-GrepAlwaysExcludedDirs)) { $excludeDirs.Add($d) }
        $include   = [System.Collections.Generic.List[string]]::new()
        $exclude   = [System.Collections.Generic.List[string]]::new()
        $ePatterns = [System.Collections.Generic.List[string]]::new()
        $realArgs  = [System.Collections.Generic.List[string]]::new(2)

        $treatRestAsPositional = $false
        # Wrap to keep $args as an Object[] without unrolling the if-expression.
        $argsList = @() + $args
        $idx = 0
        $parseError = $null

        while ($idx -lt $argsList.Count) {
            $a = [string]$argsList[$idx]
            if (-not $a) { $idx++; continue }

            if ($treatRestAsPositional) { $realArgs.Add($a); $idx++; continue }
            if ($a -ceq '--')           { $treatRestAsPositional = $true; $idx++; continue }

            $needValueFor = $null
            switch -CaseSensitive ($a) {
                '-r' { $flagRecursive  = $true }
                '-i' { $flagIgnoreCase = $true }
                '-F' { $flagFixed      = $true }
                '-e' { $needValueFor   = 'e' }
                '-V' { $flagVersion    = $true }
                '-v' { $flagInvert     = $true }
                '-c' { $flagCount      = $true }
                '-l' { $flagFiles      = $true }
                '-L' { $flagFilesNoMatch = $true }
                '-q' { $flagQuiet      = $true }
                '-x' { $flagLineMatch  = $true }
                '-w' { $flagWord       = $true }
                '-o' { $flagOnly       = $true }
                '-n' { $flagLineNumber = $true }
                '-A' { $needValueFor = 'A' }
                '-B' { $needValueFor = 'B' }
                '-C' { $needValueFor = 'C' }
                '-m' { $needValueFor = 'm' }
                '--help'                  { $flagHelp         = $true }
                '--version'               { $flagVersion      = $true }
                '--update'                { $flagUpdate       = $true }
                '--recursive'             { $flagRecursive    = $true }
                '--ignore-case'           { $flagIgnoreCase   = $true }
                '--fixed-strings'         { $flagFixed        = $true }
                '--invert-match'          { $flagInvert       = $true }
                '--count'                 { $flagCount        = $true }
                '--files-with-matches'    { $flagFiles        = $true }
                '--files-without-match'   { $flagFilesNoMatch = $true }
                '--quiet'                 { $flagQuiet        = $true }
                '--silent'                { $flagQuiet        = $true }
                '--line-regexp'           { $flagLineMatch    = $true }
                '--word-regexp'           { $flagWord         = $true }
                '--only-matching'         { $flagOnly         = $true }
                '--line-number'           { $flagLineNumber   = $true }
                default {
                    # Combined short forms with embedded numeric value: -A3, -B5, -C2, -m10.
                    if     ($a -cmatch '^-A(\d+)$') { $afterCtx  = [int]$Matches[1] }
                    elseif ($a -cmatch '^-B(\d+)$') { $beforeCtx = [int]$Matches[1] }
                    elseif ($a -cmatch '^-C(\d+)$') { $ctxBoth   = [int]$Matches[1] }
                    elseif ($a -cmatch '^-m(\d+)$') { $maxCount  = [int]$Matches[1] }
                    # GNU shortcut: -NUM is the same as -C NUM.
                    elseif ($a -cmatch '^-(\d+)$')  { $ctxBoth   = [int]$Matches[1] }
                    # -e PATTERN with the pattern attached (GNU: '-ePATTERN' form).
                    elseif ($a -cmatch '^-e(.+)$')  { $ePatterns.Add($Matches[1]) }
                    # Bundled boolean short flags, optionally ending with 'e' which
                    # consumes the next argv as a pattern (e.g. -re PATTERN).
                    # Value-taking flags -A/-B/-C/-m are NOT bundle-compatible.
                    elseif ($a -cmatch '^-([rivVclLqxwonF]+)(e?)$') {
                        foreach ($ch in $Matches[1].ToCharArray()) {
                            switch -CaseSensitive ([string]$ch) {
                                'r' { $flagRecursive    = $true }
                                'i' { $flagIgnoreCase   = $true }
                                'F' { $flagFixed        = $true }
                                'V' { $flagVersion      = $true }
                                'v' { $flagInvert       = $true }
                                'c' { $flagCount        = $true }
                                'l' { $flagFiles        = $true }
                                'L' { $flagFilesNoMatch = $true }
                                'q' { $flagQuiet        = $true }
                                'x' { $flagLineMatch    = $true }
                                'w' { $flagWord         = $true }
                                'o' { $flagOnly         = $true }
                                'n' { $flagLineNumber   = $true }
                            }
                        }
                        if ($Matches[2] -eq 'e') { $needValueFor = 'e' }
                    }
                    elseif ($a -like '--exclude-dir=*') {
                        $v = $a.Substring(14).Trim()
                        if ($v) { $excludeDirs.Add($v) }
                        else    { $parseError = "invalid argument: '$a'. Use --exclude-dir=folder_name" }
                    }
                    elseif ($a -like '--include=*') {
                        $v = $a.Substring(10).Trim()
                        if ($v) { $include.Add($v) }
                        else    { $parseError = "invalid argument: '$a'. Use --include=glob" }
                    }
                    elseif ($a -like '--exclude=*') {
                        $v = $a.Substring(10).Trim()
                        if ($v) { $exclude.Add($v) }
                        else    { $parseError = "invalid argument: '$a'. Use --exclude=glob" }
                    }
                    elseif ($a -like '--after-context=*') {
                        $v = $a.Substring(16).Trim()
                        if ($v -match '^\d+$') { $afterCtx = [int]$v }
                        else                   { $parseError = "invalid argument: '$a'. Use --after-context=NUM" }
                    }
                    elseif ($a -like '--before-context=*') {
                        $v = $a.Substring(17).Trim()
                        if ($v -match '^\d+$') { $beforeCtx = [int]$v }
                        else                   { $parseError = "invalid argument: '$a'. Use --before-context=NUM" }
                    }
                    elseif ($a -like '--context=*') {
                        $v = $a.Substring(10).Trim()
                        if ($v -match '^\d+$') { $ctxBoth = [int]$v }
                        else                   { $parseError = "invalid argument: '$a'. Use --context=NUM" }
                    }
                    elseif ($a -like '--max-count=*') {
                        $v = $a.Substring(12).Trim()
                        if ($v -match '^\d+$') { $maxCount = [int]$v }
                        else                   { $parseError = "invalid argument: '$a'. Use --max-count=NUM" }
                    }
                    elseif ($a -like '--regexp=*') {
                        $ePatterns.Add($a.Substring(9))
                    }
                    elseif ($a -ceq '--regexp') {
                        $parseError = "option '--regexp' requires a value. Use --regexp=PATTERN."
                    }
                    elseif ($a.Length -gt 1 -and $a[0] -eq '-' -and -not $flagFixed) {
                        $parseError = "unrecognized option '$a'. Run 'grep --help' for help."
                    }
                    else { $realArgs.Add($a) }
                }
            }

            if ($parseError) { break }

            if ($needValueFor) {
                if ($idx + 1 -ge $argsList.Count) {
                    $parseError = "option '-$needValueFor' requires an argument."
                    break
                }
                $rawNext = [string]$argsList[$idx + 1]
                if ($needValueFor -eq 'e') {
                    # GNU '-e PATTERN' takes the next argv verbatim, even if it starts with '-'.
                    $ePatterns.Add($rawNext)
                } elseif ($rawNext -notmatch '^\d+$') {
                    $parseError = "option '-$needValueFor' requires a non-negative integer argument."
                    break
                } else {
                    $next = [int]$rawNext
                    switch ($needValueFor) {
                        'A' { $afterCtx  = $next }
                        'B' { $beforeCtx = $next }
                        'C' { $ctxBoth   = $next }
                        'm' { $maxCount  = $next }
                    }
                }
                $idx++
            }
            $idx++
        }

        # Exit codes follow GNU grep: 0 = match found, 1 = no match, 2 = error.
        $global:LASTEXITCODE = 0

        if ($parseError) {
            Write-Host "grep: $parseError" -ForegroundColor Red
            $global:LASTEXITCODE = 2; return
        }

        if ($flagHelp) {
            Write-Host
            Write-Host "  grep-for-windows" -ForegroundColor Cyan -NoNewline
            Write-Host " - Linux-style grep for PowerShell"
            Write-Host
            Write-Host "  USAGE" -ForegroundColor Yellow
            Write-Host "    grep [options] " -NoNewline
            Write-Host "<pattern>" -ForegroundColor Magenta -NoNewline
            Write-Host " " -NoNewline
            Write-Host "[path]" -ForegroundColor Magenta -NoNewline
            Write-Host " [filter options...]"
            Write-Host "    cmd | grep [options] " -NoNewline
            Write-Host "<pattern>" -ForegroundColor Magenta
            Write-Host
            Write-Host "  GENERAL" -ForegroundColor Yellow
            Write-GrepHelpRow ''   '--help'    'Shows this help and exits.'
            Write-GrepHelpRow '-V' '--version' 'Shows the installed version and exits.'
            Write-GrepHelpRow ''   '--update'  'Checks for a newer version on GitHub and updates if found.'
            Write-Host
            Write-Host "  PATTERN SELECTION" -ForegroundColor Yellow
            Write-Host "    Patterns are regular expressions (.NET regex)." -ForegroundColor DarkGray
            Write-GrepHelpRow '-e PAT' '--regexp=PAT'      'Add PAT as a pattern. Repeatable; combined as OR.'
            Write-GrepHelpRow '-F'     '--fixed-strings'   'Interpret pattern as literal text (not a regex).'
            Write-GrepHelpRow '-i'     '--ignore-case'     'Case-insensitive match.'
            Write-GrepHelpRow '-w'     '--word-regexp'   'Match only whole words.'
            Write-GrepHelpRow '-x'     '--line-regexp'   'Match only whole lines.'
            Write-GrepHelpRow '-v'     '--invert-match'  'Print lines that do NOT match.'
            Write-Host
            Write-Host "  OUTPUT CONTROL" -ForegroundColor Yellow
            Write-GrepHelpRow '-n'     '--line-number'           'Prefix each match with its line number.'
            Write-GrepHelpRow '-c'     '--count'                 'Print only a count of matching lines per file.'
            Write-GrepHelpRow '-l'     '--files-with-matches'    'Print only file names that contain matches.'
            Write-GrepHelpRow '-L'     '--files-without-match'   'Print only file names with no matches.'
            Write-GrepHelpRow '-o'     '--only-matching'         'Print only the matched parts of a line.'
            Write-GrepHelpRow '-q'     '--quiet'                 'Suppress all output. Same as --silent.'
            Write-GrepHelpRow '-m NUM' '--max-count=NUM'         'Stop after NUM matching lines per file.'
            Write-Host
            Write-Host "  CONTEXT CONTROL" -ForegroundColor Yellow
            Write-GrepHelpRow '-A NUM' '--after-context=NUM'  'Print NUM lines after each match.'
            Write-GrepHelpRow '-B NUM' '--before-context=NUM' 'Print NUM lines before each match.'
            Write-GrepHelpRow '-C NUM' '--context=NUM'        'Print NUM lines of context (before and after).'
            Write-GrepHelpRow ''       '-NUM'                 'Same as -C NUM (e.g. -3 prints 3 lines of context).'
            Write-Host
            Write-Host "  FILE TRAVERSAL" -ForegroundColor Yellow
            Write-GrepHelpRow '-r' '--recursive'        'Recurse into subdirectories.'
            Write-GrepHelpRow ''   '--include=GLOB'     'Search only files whose name matches GLOB. Repeatable.'
            Write-GrepHelpRow ''   '--exclude=GLOB'     'Skip files whose name matches GLOB. Repeatable.'
            Write-GrepHelpRow ''   '--exclude-dir=NAME' 'Skip any directory named NAME. Repeatable.'
            Write-Host
            Write-Host "  ARGUMENTS" -ForegroundColor Yellow
            Write-Host "    " -NoNewline; Write-Host "<pattern>" -ForegroundColor Magenta -NoNewline; Write-Host "  Required. The text or regex to search for."
            Write-Host "    " -NoNewline; Write-Host "[path]" -ForegroundColor Magenta -NoNewline;    Write-Host "     File or directory to search. Defaults to '.'. Use '-' or pipe to read stdin."
            Write-Host
            Write-Host "  EXAMPLES" -ForegroundColor Yellow
            Write-Host "    grep " -NoNewline; Write-Host '"TODO"' -ForegroundColor DarkCyan
            Write-Host "    grep -r -i " -NoNewline; Write-Host '"error"' -ForegroundColor DarkCyan -NoNewline; Write-Host " C:\projects\myapp"
            Write-Host "    grep -r -e " -NoNewline; Write-Host '"[\w.+-]+@[\w-]+\.[\w.-]+"' -ForegroundColor DarkCyan -NoNewline; Write-Host " ."
            Write-Host "    grep -r -l " -NoNewline; Write-Host '"function"' -ForegroundColor DarkCyan -NoNewline; Write-Host ' . --include="*.ps1"'
            Write-Host "    grep -A 2 -B 2 " -NoNewline; Write-Host '"TODO"' -ForegroundColor DarkCyan -NoNewline; Write-Host " .\notes.txt"
            Write-Host "    Get-Content .\app.log | grep -i " -NoNewline; Write-Host '"error"' -ForegroundColor DarkCyan
            Write-Host
            Write-Host "  TO UNINSTALL" -ForegroundColor Yellow
            Write-Host "    Uninstall-GrepForWindows" -ForegroundColor Cyan
            Write-Host
            return
        }

        if ($flagUpdate) {
            Write-Host "Checking for updates..." -ForegroundColor Cyan
            try {
                $remoteScript = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1' -ErrorAction Stop
            } catch {
                Write-Host "grep: could not reach GitHub. Check your internet connection." -ForegroundColor Red
                $global:LASTEXITCODE = 2; return
            }
            # The install script handles version comparison and idempotent reinstall.
            Invoke-Expression $remoteScript
            return
        }

        if ($flagVersion) {
            $version = $MyInvocation.MyCommand.Module.Version
            if ($version) { Write-Host "grep-for-windows $version" }
            else          { Write-Host "grep-for-windows (version unknown)" }
            return
        }

        # Resolve positional args. With one or more -e PATTERN, no positional
        # pattern is taken: the first positional is the path.
        if ($ePatterns.Count -gt 0) {
            if ($realArgs.Count -gt 1) {
                Write-Host "grep: too many positional arguments. Run 'grep --help' for help." -ForegroundColor Red
                $global:LASTEXITCODE = 2; return
            }
            $Pattern      = ''
            $Path         = if ($realArgs.Count -ge 1) { $realArgs[0] } else { '.' }
            $pathExplicit = $realArgs.Count -ge 1
        } else {
            if ($realArgs.Count -lt 1) {
                Write-Host "grep: a pattern is required. Run 'grep --help' for help." -ForegroundColor Red
                $global:LASTEXITCODE = 2; return
            }
            if ($realArgs.Count -gt 2) {
                Write-Host "grep: too many positional arguments. Run 'grep --help' for help." -ForegroundColor Red
                $global:LASTEXITCODE = 2; return
            }
            $Pattern      = $realArgs[0]
            $Path         = if ($realArgs.Count -ge 2) { $realArgs[1] } else { '.' }
            $pathExplicit = $realArgs.Count -ge 2
        }

        $caseSensitive  = -not $flagIgnoreCase
        $recurse        = $flagRecursive
        $invertMatch    = $flagInvert
        $countOnly      = $flagCount
        $filesOnly      = $flagFiles
        $filesNoMatch   = $flagFilesNoMatch
        $quietMode      = $flagQuiet
        $lineMatch      = $flagLineMatch
        $wordMatch      = $flagWord
        $onlyMatching   = $flagOnly

        # -C is the default for both -A and -B; explicit -A / -B win.
        if ($ctxBoth -ge 0) {
            if ($afterCtx  -lt 0) { $afterCtx  = $ctxBoth }
            if ($beforeCtx -lt 0) { $beforeCtx = $ctxBoth }
        }
        if ($afterCtx  -lt 0) { $afterCtx  = 0 }
        if ($beforeCtx -lt 0) { $beforeCtx = 0 }

        # Mutually exclusive combinations, mirroring GNU grep:
        # -q wins over all output flags; -L wins over -l/-c; -l wins over -c;
        # -x wins over -w; -v overrides -o; counts/lists suppress context.
        if ($quietMode) { $countOnly = $false; $filesOnly = $false; $filesNoMatch = $false; $onlyMatching = $false }
        if ($filesNoMatch)             { $filesOnly = $false; $countOnly = $false }
        if ($filesOnly)                { $countOnly = $false }
        if ($lineMatch)                { $wordMatch = $false }
        if ($invertMatch)              { $onlyMatching = $false }
        if ($countOnly -or $filesOnly -or $filesNoMatch) { $afterCtx = 0; $beforeCtx = 0 }

        # Stdin mode: pipeline input is used unless an explicit path was given;
        # '-' as path always means stdin.
        $isStdinMode = ($expectingPipeline -and -not $pathExplicit) -or ($Path -eq '-')
        if ($Path -eq '-' -and -not $expectingPipeline) {
            Write-Host "grep: no input piped to '-'." -ForegroundColor Red
            $global:LASTEXITCODE = 2; return
        }
        if (-not $isStdinMode -and -not (Test-Path -LiteralPath $Path)) {
            Write-Host "grep: '$Path': No such file or directory" -ForegroundColor Red
            $global:LASTEXITCODE = 2; return
        }

        # Match real grep: hide the path prefix when the search target is a
        # single file (or stdin); show it when scanning a directory or recursing.
        # Line numbers are off by default and enabled with -n / --line-number.
        $showFilename   = (-not $isStdinMode) -and (Test-Path -LiteralPath $Path -PathType Container)
        $showLineNumber = $flagLineNumber

        # Build the search regex. -F escapes patterns as literals; -w wraps with \b.
        # Compiled flag amortises the per-line .Matches() call when there are many hits.
        $regexOptions = [System.Text.RegularExpressions.RegexOptions]::Compiled
        if (-not $caseSensitive) { $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
        # Patterns are .NET regex. Multiple -e patterns are unioned with OR.
        # -F escapes each pattern so it is matched literally.
        if ($ePatterns.Count -gt 0) {
            $highlightSource = ($ePatterns | ForEach-Object {
                if ($flagFixed) { [regex]::Escape($_) } else { "(?:$_)" }
            }) -join '|'
        } else {
            $highlightSource = if ($flagFixed) { [regex]::Escape($Pattern) } else { $Pattern }
        }
        if     ($lineMatch) { $highlightSource = "\A(?:$highlightSource)\z" }
        elseif ($wordMatch) { $highlightSource = "\b(?:$highlightSource)\b" }

        try {
            $highlightRegex = [regex]::new($highlightSource, $regexOptions)
        } catch {
            $shown = if ($ePatterns.Count -gt 0) { ($ePatterns -join ', ') } else { $Pattern }
            Write-Host "grep: invalid regex pattern '$shown'." -ForegroundColor Red
            $global:LASTEXITCODE = 2; return
        }

        # Combined regex matching \name\ in any path component (case-insensitive).
        $excludeRegex = $null
        if ($excludeDirs.Count -gt 0) {
            $alternation = ($excludeDirs | ForEach-Object { [regex]::Escape($_) }) -join '|'
            $excludeRegex = [regex]::new("\\($alternation)\\", 'IgnoreCase')
        }

        $selectStringArgs = @{ CaseSensitive = $caseSensitive; Pattern = $highlightSource }
        if ($invertMatch)                              { $selectStringArgs['NotMatch'] = $true }
        if ($beforeCtx -gt 0 -or $afterCtx -gt 0)      { $selectStringArgs['Context']  = @($beforeCtx, $afterCtx) }
        # -List makes Select-String stop at the first match per file (used by -l, -L, -q).
        if ($filesOnly -or $filesNoMatch -or $quietMode) { $selectStringArgs['List']   = $true }

        # Streaming: matches flow Select-String -> ForEach-Object so each hit prints
        # the moment it is found. State is held in reference types so mutations
        # inside ForEach-Object's child scope propagate back. -c accumulates and
        # prints once at the end; -l prints each path on first hit; default mode
        # renders match (and context) inline.
        $state        = @{ Total = 0 }
        $seenPaths    = [System.Collections.Generic.HashSet[string]]::new()
        $counts       = [ordered]@{}
        $shownPerFile = @{}  # for -m: matches emitted per file
        $lastPrinted  = @{}  # per-file dedupe for context line numbers
        $hasContext   = $beforeCtx -gt 0 -or $afterCtx -gt 0

        # Reusable file enumeration with --include / --exclude / --exclude-dir filters.
        $produceFiles = {
            $files = Get-ChildItem -Path $Path -Recurse:$recurse -File -ErrorAction SilentlyContinue
            if ($excludeRegex -or $include.Count -gt 0 -or $exclude.Count -gt 0) {
                $files = $files | Where-Object {
                    if ($excludeRegex -and $excludeRegex.IsMatch($_.FullName)) { return $false }
                    if ($include.Count -gt 0) {
                        $ok = $false
                        foreach ($g in $include) { if ($_.Name -like $g) { $ok = $true; break } }
                        if (-not $ok) { return $false }
                    }
                    if ($exclude.Count -gt 0) {
                        foreach ($g in $exclude) { if ($_.Name -like $g) { return $false } }
                    }
                    $true
                }
            }
            $files
        }

        # Match producer shared by -q and default rendering.
        $produceMatches = {
            if ($isStdinMode) {
                if ($stdinLines.Count -gt 0) { $stdinLines | Select-String @selectStringArgs }
                return
            }
            & $produceFiles | Select-String @selectStringArgs
        }

        # -q: stop at first match, print nothing. Select-Object -First 1 closes
        # the upstream pipeline so Select-String can short-circuit on the first hit.
        if ($quietMode) {
            if (-not (& $produceMatches | Select-Object -First 1)) { $global:LASTEXITCODE = 1 }
            return
        }

        # -L: print only paths with NO match. Needs the file list materialised
        # so we can subtract the matched set from it.
        if ($filesNoMatch) {
            if ($isStdinMode) {
                $hit = $false
                if ($stdinLines.Count -gt 0) {
                    $hit = [bool]($stdinLines | Select-String @selectStringArgs | Select-Object -First 1)
                }
                if (-not $hit) { Write-Host '(standard input)' -ForegroundColor Magenta; $state.Total++ }
            } else {
                $allFiles = @(& $produceFiles)
                $matchedSet = [System.Collections.Generic.HashSet[string]]::new()
                $allFiles | Select-String @selectStringArgs | ForEach-Object { [void]$matchedSet.Add($_.Path) }
                foreach ($f in $allFiles) {
                    if (-not $matchedSet.Contains($f.FullName)) {
                        Write-Host $f.FullName -ForegroundColor Magenta
                        $state.Total++
                    }
                }
            }
            if ($state.Total -eq 0) { $global:LASTEXITCODE = 1 }
            return
        }

        & $produceMatches | ForEach-Object {
            $mi = $_

            # -m per-file cap: skip emission once a file has reached its quota.
            if ($maxCount -ge 0) {
                $mkey = if ($isStdinMode) { '<stdin>' } else { $mi.Path }
                $cur  = if ($shownPerFile.ContainsKey($mkey)) { $shownPerFile[$mkey] } else { 0 }
                if ($cur -ge $maxCount) { return }
                $shownPerFile[$mkey] = $cur + 1
            }

            $state.Total++
            $effPath = if ($showFilename) { $mi.Path } else { '' }
            $effLn   = if ($showLineNumber) { $mi.LineNumber } else { 0 }

            if ($filesOnly) {
                $key = if ($isStdinMode) { '(standard input)' } else { $mi.Path }
                if ($seenPaths.Add($key)) { Write-Host $key -ForegroundColor Magenta }
                return
            }

            if ($countOnly) {
                $key = if ($isStdinMode) { '(standard input)' } else { $mi.Path }
                if (-not $counts.Contains($key)) { $counts[$key] = 0 }
                $counts[$key] += 1
                return
            }

            $ctxKey = if ($mi.Path) { $mi.Path } else { '<stdin>' }

            if ($hasContext) {
                $lp = if ($lastPrinted.ContainsKey($ctxKey)) { $lastPrinted[$ctxKey] } else { 0 }
                $preLines = $mi.Context.PreContext
                $preStart = $mi.LineNumber - $preLines.Count

                # '--' separator between non-contiguous match groups.
                if ($lp -gt 0 -and $preStart -gt $lp + 1) { Write-Host "--" }

                for ($k = 0; $k -lt $preLines.Count; $k++) {
                    $ln = $preStart + $k
                    if ($ln -le $lp) { continue }
                    $ctxLn = if ($showLineNumber) { $ln } else { 0 }
                    Write-GrepContextLine -Path $effPath -LineNumber $ctxLn -Line ([string]$preLines[$k]).TrimEnd()
                    $lp = $ln
                }
                $lastPrinted[$ctxKey] = $lp
            }

            $lineText = $mi.Line.TrimEnd()
            if ($onlyMatching -and -not $invertMatch) {
                foreach ($m in $highlightRegex.Matches($lineText)) {
                    if ($m.Length -eq 0) { continue }
                    Write-GrepColoredLine -Path $effPath -LineNumber $effLn -Line $m.Value -HighlightRegex $highlightRegex
                }
            } else {
                Write-GrepColoredLine -Path $effPath -LineNumber $effLn -Line $lineText -HighlightRegex $highlightRegex
            }

            if ($hasContext) {
                $lp = $mi.LineNumber
                $postLines = $mi.Context.PostContext
                for ($k = 0; $k -lt $postLines.Count; $k++) {
                    $ln = $mi.LineNumber + $k + 1
                    if ($ln -le $lp) { continue }
                    $ctxLn = if ($showLineNumber) { $ln } else { 0 }
                    Write-GrepContextLine -Path $effPath -LineNumber $ctxLn -Line ([string]$postLines[$k]).TrimEnd()
                    $lp = $ln
                }
                $lastPrinted[$ctxKey] = $lp
            }
        }

        if ($countOnly) {
            foreach ($k in $counts.Keys) {
                if ($showFilename) {
                    Write-Host "${k}:" -ForegroundColor Magenta -NoNewline
                    Write-Host $counts[$k]
                } else {
                    Write-Host $counts[$k]
                }
            }
        }

        if ($state.Total -eq 0) { $global:LASTEXITCODE = 1 }
    }
}

# Removes grep-for-windows: unloads the module from the current session and
# deletes the module folder. As a courtesy, also strips a stray
# `Import-Module grep-for-windows` line from $PROFILE if one is present (left
# over from older installs or a manual edit). -WhatIf previews; -Confirm prompts.
function Uninstall-GrepForWindows {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param()

    # Capture the install path before unloading: Remove-Module clears the
    # module info that $MyInvocation.MyCommand.Module would otherwise expose.
    $module      = Get-Module -Name 'grep-for-windows'
    $installDir  = if ($module) { $module.ModuleBase } else { $null }
    $profilePath = $PROFILE

    if (-not $PSCmdlet.ShouldProcess('grep-for-windows', 'Uninstall')) { return }

    # 1. Unload the module so the .psm1 file lock is released.
    Remove-Module -Name 'grep-for-windows' -Force -ErrorAction SilentlyContinue

    # 2. Remove the module folder from disk.
    $folderRemoved = $false
    if ($installDir -and (Test-Path -LiteralPath $installDir)) {
        Remove-Item -LiteralPath $installDir -Recurse -Force
        Write-Host "Removed module folder: $installDir" -ForegroundColor Cyan
        $folderRemoved = $true
    }

    # 3. Defensive: strip a stray `Import-Module grep-for-windows` line so the
    #    next session does not try to import a module that no longer exists.
    if (Test-Path -LiteralPath $profilePath) {
        $content = Get-Content -Raw -LiteralPath $profilePath
        $pattern = '(?m)^[ \t]*Import-Module\s+["'']?grep-for-windows["'']?[ \t]*(?:#[^\r\n]*)?\r?\n?'
        if ($content -match $pattern) {
            $newContent = [regex]::Replace($content, $pattern, '')
            Set-Content -LiteralPath $profilePath -Value $newContent -Encoding UTF8 -NoNewline
            Write-Host "Removed stray 'Import-Module grep-for-windows' line from $profilePath" -ForegroundColor DarkGray
        }
    }

    # 4. PowerShell does not always purge exported function bindings when
    #    Remove-Module runs from inside the module itself, so drop them by hand.
    foreach ($fn in 'grep', 'Uninstall-GrepForWindows') {
        if (Test-Path "function:$fn") { Remove-Item "function:$fn" -Force -ErrorAction SilentlyContinue }
    }

    if (-not $folderRemoved) {
        Write-Host "grep-for-windows was not installed; nothing to do." -ForegroundColor Yellow
        return
    }
    Write-Host "grep-for-windows uninstalled." -ForegroundColor Green
}

Export-ModuleMember -Function 'grep', 'Uninstall-GrepForWindows'
