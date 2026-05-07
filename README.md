# grep-for-windows

> Linux-style `grep` for PowerShell — same flags, same defaults, same colored output.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE?logo=powershell)](https://learn.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D6)](#requirements)

`grep-for-windows` is a small PowerShell module that gives you the GNU `grep`
command you already know. If you came to Windows from Linux or macOS and miss
typing `grep -rn "TODO" .` instead of `Get-ChildItem | Select-String`, this is
for you. No external binaries, no `git-bash`, no WSL — just one module that
plugs into your existing PowerShell.

```powershell
# Find every TODO in your project, with line numbers
grep -rn "TODO" .

# Filter a log file for errors as it grows
Get-Content .\app.log -Wait | grep -i "error"

# Extract every email address in a directory tree
grep -r -o -e "[\w.+-]+@[\w-]+\.[\w.-]+" .

# Show the function definitions in a script, with two lines of context
grep -B 1 -A 2 "^function" .\script.ps1
```

---

## Contents

- [Install](#install)
- [Requirements](#requirements)
- [Features](#features)
- [Usage](#usage)
- [Reference](#reference)
- [Output format](#output-format)
- [Configuration](#configuration)
- [Update](#update)
- [Uninstall](#uninstall)
- [Manual install](#manual-install-without-the-script)
- [Compatibility notes](#compatibility-notes)
- [Contributing](#contributing)
- [License](#license)

---

## Install

Run this one-liner in any PowerShell session:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

The installer:

1. Downloads the module to your standard modules folder
   (`~\Documents\PowerShell\Modules\grep-for-windows\` on PowerShell 7+, or
   `~\Documents\WindowsPowerShell\Modules\…` on Windows PowerShell 5.1).
2. Loads the module in the current session, so `grep` works **immediately** —
   no shell restart needed.

Your `$PROFILE` is **not** modified. PowerShell's automatic module loading
picks `grep` up the first time you run it in any new session.

Re-running the same one-liner updates to the latest version, or no-ops if
you're already up to date.

> `irm` (`Invoke-RestMethod`) downloads the script and `iex`
> (`Invoke-Expression`) runs it. If you'd rather inspect first:
> `irm <url> -OutFile Install-GrepForWindows.ps1`, review, then
> `. .\Install-GrepForWindows.ps1`.

## Requirements

- Windows 10 or later
- Windows PowerShell **5.1** or PowerShell **7+**

---

## Features

- **Familiar syntax.** `grep -rni "error" .` does what you'd expect.
- **Literal by default, regex on demand.** Pass `-e` (or `--regexp`) to switch.
- **Reads from pipes.** `Get-Content app.log | grep -i "error"` works out of the box.
- **Recursive search** with directory and glob filters (`-r`, `--include`, `--exclude`, `--exclude-dir`).
- **Context lines** around each match (`-A`, `-B`, `-C`).
- **Counting and listing** (`-c`, `-l`).
- **Invert, word-match, only-matching** (`-v`, `-w`, `-o`).
- **Streaming output.** Hits print the moment they're found, just like real `grep`.
- **Colored output.** File paths in magenta, matches in red, context lines kept plain.
- **GNU grep defaults.** Path shown only on multi-file/recursive search; line numbers off unless `-n`.
- **Zero dependencies.** Pure PowerShell, no external binaries.

---

## Usage

### Search a file or directory

```powershell
grep "TODO" .\notes.txt              # single file → just the matching lines
grep "TODO" .                        # directory → path-prefixed matches
grep -r "TODO" .                     # recursive
grep -ri "todo" .                    # case-insensitive
grep -rn "TODO" .                    # show line numbers
```

### Read from stdin (pipes)

```powershell
"hello","world" | grep "world"
Get-Content .\app.log | grep -i "error"
Get-Content .\app.log -Wait | grep -i "error"   # follow the file
```

### Recurse with filters

```powershell
grep -r "function" . --include="*.ps1"
grep -r "import"   . --exclude-dir=node_modules --exclude-dir=.git
grep -r "TODO"     . --include="*.md" --include="*.txt" --exclude="*.bak"
```

### Context around matches

```powershell
grep -A 2 "function grep" .\script.ps1     # 2 lines after each match
grep -B 1 "throw" .\error.ps1              # 1 line before each match
grep -C 3 "ERROR" .\big.log                # 3 lines on either side
```

Context lines use a `-` separator (e.g., `42-...`) instead of `:`, so match
lines remain easy to spot even in dense output.

### Counts and file lists

```powershell
grep -c "TODO" .\notes.txt           # count matching lines in one file
grep -rc "TODO" .                    # per-file counts, recursive
grep -rl "function" . --include="*.ps1"   # just print files that contain a match
```

### Invert, word-match, only-matching

```powershell
grep -v "DEBUG" .\app.log            # lines that do NOT contain "DEBUG"
grep -w "grep" .\README.md           # whole-word match
grep -o -e "[\w]+@[\w.-]+" .\file    # print only the matched substrings
```

### Patterns starting with `-`

PowerShell strips bare `--`, so quote it explicitly:

```powershell
grep "--" "-foo" .\file              # pattern is the literal "-foo"
```

---

## Reference

The full option list, mirroring GNU `grep` where it makes sense.

### General

| Option | Description |
|---|---|
| `--help` | Show the help banner and exit. |
| `-V`, `--version` | Print the installed version and exit. |
| `--update` | Re-run the installer to fetch the latest version from GitHub. |

### Pattern selection

| Option | Description |
|---|---|
| `-e`, `--regexp` | Treat `<pattern>` as a regular expression instead of literal text. |
| `-i`, `--ignore-case` | Case-insensitive match. |
| `-w`, `--word-regexp` | Match whole words only (wraps the pattern with `\b`). |
| `-v`, `--invert-match` | Print lines that do **not** match. |

### Output control

| Option | Description |
|---|---|
| `-n`, `--line-number` | Prefix each match with its line number. |
| `-c`, `--count` | Print only a count of matching lines per file. |
| `-l`, `--files-with-matches` | Print only the names of files that contain matches. |
| `-o`, `--only-matching` | Print only the matched portion of a line, one match per output line. |

### Context

| Option | Description |
|---|---|
| `-A NUM`, `--after-context=NUM` | Print `NUM` lines after each match. |
| `-B NUM`, `--before-context=NUM` | Print `NUM` lines before each match. |
| `-C NUM`, `--context=NUM` | Print `NUM` lines of context (before and after). |

`-A`/`-B`/`-C` can be combined; `-A NUM` and `-B NUM` override `-C` when both are given.

### File traversal

| Option | Description |
|---|---|
| `-r`, `--recursive` | Recurse into subdirectories. |
| `--include=GLOB` | Include only files whose name matches `GLOB`. Repeatable. |
| `--exclude=GLOB` | Skip files whose name matches `GLOB`. Repeatable. |
| `--exclude-dir=NAME` | Skip any directory named `NAME`. Repeatable. |

### Arguments

| Argument | Description |
|---|---|
| `<pattern>` | Required. The text or regex to search for. |
| `[path]` | Optional. File or directory to search. Defaults to `.`. Use `-` (or pipe) to read from stdin. |

---

## Output format

`grep-for-windows` follows GNU `grep` defaults: it shows the file path only
when the search spans multiple files (a directory or recursive search), and it
prints line numbers only when you ask for them with `-n`.

| Invocation | Output line |
|---|---|
| `grep "x" file.txt` | `line content` |
| `grep -n "x" file.txt` | `42: line content` |
| `grep "x" .` *(directory)* | `path\file.ext:line content` |
| `grep -rn "x" .` | `path\file.ext:42: line content` |
| `cmd \| grep "x"` | `line content` |
| `cmd \| grep -n "x"` | `42: line content` |

- File paths are printed in **magenta**, matches highlighted in **red**.
- Context lines (`-A` / `-B` / `-C`) use a `-` separator instead of `:`.

Exit codes match GNU `grep`: `0` (match found), `1` (no match), `2` (error).

---

## Configuration

To skip certain folders in **every** search (e.g. `node_modules`, `.git`),
add `$global:GrepAlwaysExcludedDirs` to your `$PROFILE`:

```powershell
$global:GrepAlwaysExcludedDirs = @('node_modules', '.git', '__pycache__', 'dist')
```

Reload (`. $PROFILE`) or open a new shell. Folders passed explicitly via
`--exclude-dir=` on the command line are added on top of this list, never
replacing it.

This is the only `grep-for-windows` setting that lives in your profile — the
module itself loads automatically the first time you call `grep`, no
`Import-Module` line required.

---

## Update

```powershell
grep --update
```

That re-runs the installer, which fetches the latest manifest from GitHub.
If your installed version matches the remote, nothing happens. Otherwise the
module files are overwritten in place and the module reloads in the current
session.

You can also re-run the install one-liner — same effect:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

Check the installed version any time:

```powershell
grep --version
```

---

## Uninstall

```powershell
Uninstall-GrepForWindows
```

This:

1. Unloads the module from the current session.
2. Deletes the module folder from disk.

If you added `$global:GrepAlwaysExcludedDirs` to your `$PROFILE` you can leave
it (harmless) or remove it manually. Pass `-WhatIf` to preview without
touching anything, or `-Confirm` to be prompted first.

---

## Manual install (without the script)

If you'd rather not run a remote script:

1. Clone or download this repository.
2. Copy the [`module/`](module/) folder into your modules path, naming the
   destination folder `grep-for-windows`:

   ```powershell
   $dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\grep-for-windows'
   New-Item -ItemType Directory -Path $dest -Force | Out-Null
   Copy-Item .\module\* $dest -Force
   ```

   On Windows PowerShell 5.1, replace `PowerShell` with `WindowsPowerShell` in
   the path above.

That's it. PowerShell's automatic module loading will pick up `grep` the next
time you call it in any new session. To use it immediately in the current
session: `Import-Module grep-for-windows`.

---

## Compatibility notes

- **`-h` is not the help shortcut.** GNU `grep` reserves `-h` for `--no-filename`,
  not help. Use `--help` (or `-?`).
- **Patterns starting with `-`.** PowerShell strips bare `--` from the command
  line before reaching the function. To search for a literal `-foo`, quote the
  end-of-options marker: `grep "--" "-foo" .\file`.
- **Multiple file arguments.** Currently `grep` accepts one path per
  invocation. To search several files explicitly, point at their parent
  directory and use `--include=GLOB`.

---

## Contributing

Issues and pull requests are welcome at the
[GitHub repository](https://github.com/kithuto/grep-for-windows).

When submitting a pull request:

1. Fork the repository and create a feature branch.
2. Keep changes focused; write a clear commit message.
3. Test on both Windows PowerShell 5.1 and PowerShell 7+ when possible.

---

## License

MIT — see [LICENSE](LICENSE).
