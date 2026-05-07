# grep-for-windows

> Linux-style `grep` for Windows PowerShell — search files without learning `Select-String`.

`grep-for-windows` is a lightweight PowerShell module that brings the familiar `grep` command to Windows, with both literal and regex search built into a single command. If you come from Linux or macOS and miss running `grep -r "TODO" .` in your terminal, this project gives you the exact same experience on PowerShell — colored output included — without having to memorize `Get-ChildItem | Select-String` pipelines.

No external binaries. No dependencies. The module lives under your standard PowerShell modules directory and a single `Import-Module grep-for-windows` line in your `$PROFILE` makes `grep` available in every session.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option 1: Install script (recommended)](#option-1-install-script-recommended)
  - [Option 2: Manual module install](#option-2-manual-module-install)
- [Usage](#usage)
  - [Synopsis](#synopsis)
  - [Options](#options)
- [Examples](#examples)
- [Configuration](#configuration)
- [Output format](#output-format)
- [Update](#update)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Familiar syntax** — `grep -r -i "pattern" .` works exactly like you'd expect.
- **Literal by default, regex on demand** — pass `-e` (or `--regexp`) to switch to regular expressions.
- **Colored output** — file paths in magenta, matches highlighted in red, just like GNU grep.
- **Reads from pipes** — `Get-Content app.log | grep -i "error"` works out of the box.
- **Recursive search** with `-r` or `--recursive`.
- **Case-insensitive search** with `-i` or `--ignore-case`.
- **Word match** with `-w` or `--word-regexp`.
- **Invert match, count and file listing** with `-v`, `-c` and `-l`.
- **Only-matching mode** with `-o` to print just the matched substrings.
- **Context lines** around each match with `-A`, `-B` and `-C` (or their long forms).
- **File and directory filters** with `--include=GLOB`, `--exclude=GLOB` and `--exclude-dir=NAME` (all repeatable).
- **Zero dependencies** — pure PowerShell, no external binaries to install.

---

## Requirements

- Windows 10 or later
- Windows PowerShell 5.1 **or** PowerShell 7+

---

## Installation

You can install `grep-for-windows` in two ways. Pick whichever you prefer.

### Option 1: Install script (recommended)

Run this one-liner in PowerShell:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

The script:

1. Drops the module under your user modules path (e.g. `~\Documents\PowerShell\Modules\grep-for-windows\` on PowerShell 7, or `~\Documents\WindowsPowerShell\Modules\…` on Windows PowerShell 5.1).
2. Adds a single `Import-Module grep-for-windows` line to your `$PROFILE` (creating the profile file if needed).
3. Imports the module into the current session, so `grep` is ready immediately — no restart required.

The installer is **idempotent**: re-running it on an up-to-date install is a no-op, and on an older install it overwrites the module folder cleanly. If you previously had the v1 inline-in-`$PROFILE` install, the script also detects and removes that block automatically.

> `irm` downloads the script content and `iex` executes it. If you'd rather inspect first, download with `irm <url> -OutFile Install-GrepForWindows.ps1`, review, then run `. .\Install-GrepForWindows.ps1`.

### Option 2: Manual module install

If you'd rather not run the script:

1. Download (or `git clone`) this repository.
2. Copy the [`module/`](module/) folder to your user modules path, renaming it to `grep-for-windows`:

   ```powershell
   $dest = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\grep-for-windows'
   New-Item -ItemType Directory -Path $dest -Force | Out-Null
   Copy-Item .\module\* $dest -Force
   ```

   On Windows PowerShell 5.1, replace `PowerShell` with `WindowsPowerShell` in the path above.

3. Add the import line to your profile:

   ```powershell
   Add-Content -Path $PROFILE -Value "`r`nImport-Module grep-for-windows"
   ```

   If `$PROFILE` does not exist yet, run `New-Item -ItemType File -Path $PROFILE -Force` first.

4. Reload: `. $PROFILE`.

`grep` is now available in every PowerShell session.

---

## Usage

### Synopsis

```
grep [options] <pattern> [path] [filter options...]
cmd  | grep [options] <pattern>
```

By default, `grep` searches for the pattern as **literal text** (special regex characters are treated as plain characters). Add `-e` or `--regexp` to interpret the pattern as a **regular expression** instead. If no `[path]` is given and input is piped, `grep` reads from the pipeline (stdin).

### Options

#### General

| Option | Description |
|---|---|
| `--help` | Show help and exit. |
| `-V`, `--version` | Print the installed version and exit. |
| `--update` | Check for a newer version on GitHub and update if found. |

#### Pattern selection

| Option | Description |
|---|---|
| `-e`, `--regexp` | Interpret `<pattern>` as a regular expression instead of literal text. |
| `-i`, `--ignore-case` | Case-insensitive match. |
| `-w`, `--word-regexp` | Match only whole words (wraps the pattern with `\b`). |
| `-v`, `--invert-match` | Print lines that do **not** match. |

#### Output control

| Option | Description |
|---|---|
| `-n`, `--line-number` | Prefix each match with its line number. |
| `-c`, `--count` | Print only a count of matching lines per file. |
| `-l`, `--files-with-matches` | Print only file names that contain matches. |
| `-o`, `--only-matching` | Print only the matched parts of a line, one per output line. |

#### Context control

| Option | Description |
|---|---|
| `-A NUM`, `--after-context=NUM` | Print `NUM` lines after each match. |
| `-B NUM`, `--before-context=NUM` | Print `NUM` lines before each match. |
| `-C NUM`, `--context=NUM` | Print `NUM` lines of context (before and after). |

#### File traversal

| Option | Description |
|---|---|
| `-r`, `--recursive` | Recursive search through subdirectories. |
| `--include=GLOB` | Search only files whose name matches `GLOB`. Repeatable. |
| `--exclude=GLOB` | Skip files whose name matches `GLOB`. Repeatable. |
| `--exclude-dir=NAME` | Skip any directory named `NAME`. Repeatable. |

#### Arguments

| Argument | Description |
|---|---|
| `<pattern>` | Required. The text or regex to search for. |
| `[path]` | Optional. File or directory to search. Defaults to the current directory (`.`). Use `-` or pipe input to read from stdin. |

> **Heads up:** `-h` is **not** a shortcut for `--help` (it never was in GNU grep either, where `-h` means `--no-filename`). Use `--help`. If you previously aliased `grep -h` in scripts, switch to `grep --help`.

---

## Examples

Search for the word `TODO` in the current directory:

```powershell
grep "TODO"
```

Search recursively, case-insensitive, for `error` starting at `C:\projects\myapp`:

```powershell
grep -r -i "error" C:\projects\myapp
```

Find all email-like strings using regex, recursively:

```powershell
grep -r -e "[\w.+-]+@[\w-]+\.[\w.-]+" .
```

Search for `import` excluding `node_modules` and `dist`:

```powershell
grep -r "import" . --exclude-dir=node_modules --exclude-dir=dist
```

Find function definitions in a single file (regex mode via long flag):

```powershell
grep --regexp "^function\s+\w+" .\script.ps1
```

Read from a pipeline (stdin) and filter case-insensitively:

```powershell
Get-Content .\app.log | grep -i "error"
```

Show 2 lines of context before and after each match:

```powershell
grep -A 2 -B 2 "TODO" .\notes.txt
# or, equivalently
grep -C 2 "TODO" .\notes.txt
```

List only the file names that contain `function`, restricted to `.ps1` files:

```powershell
grep -r -l "function" . --include="*.ps1"
```

Count how many `TODO`s each file has, recursively:

```powershell
grep -r -c "TODO" .
```

Print only the matched substrings (e.g., extract every email in a tree):

```powershell
grep -r -o -e "[\w.+-]+@[\w-]+\.[\w.-]+" .
```

Show lines that do **not** contain `DEBUG`:

```powershell
grep -v "DEBUG" .\app.log
```

Match only whole words. `\b` treats hyphens as word boundaries, so `grep` matches `grep-for-windows` but not `mygrep`:

```powershell
grep -w "grep" .\README.md
```

---

## Configuration

If there are folders you want `grep` to skip in **every** search (for example `node_modules`, `.git`, or `__pycache__`), define `$global:GrepAlwaysExcludedDirs` in your `$PROFILE` **after** the `Import-Module` line:

```powershell
Import-Module grep-for-windows
$global:GrepAlwaysExcludedDirs = @('node_modules', '.git', '__pycache__', 'dist')
```

Reload your profile (`. $PROFILE`) or open a new session. From that point on, those directories are skipped automatically. Any folders you pass via `--exclude-dir=...` on the command line are added on top of this list, so you can still exclude extra folders ad hoc.

This approach survives module updates — your customisation lives in `$PROFILE`, not inside the module itself, so `grep --update` won't overwrite it.

---

## Output format

Match lines mirror GNU `grep` defaults: the file path is shown only when
multiple files are involved (directory or recursive search), and the line
number is shown only when `-n` / `--line-number` is passed.

| Invocation | Output |
|---|---|
| `grep "x" file.txt` | `line content` |
| `grep -n "x" file.txt` | `42: line content` |
| `grep "x" .` (dir) | `path\file.ext:line content` |
| `grep -rn "x" .` | `path\file.ext:42: line content` |
| `cmd \| grep "x"` | `line content` |
| `cmd \| grep -n "x"` | `42: line content` |

- The file path is shown in **magenta**.
- The matched substring is highlighted in **red**.
- Context lines (`-A` / `-B` / `-C`) use a `-` separator instead of `:`, so you
  can tell match lines from context at a glance.

---

## Update

You can update `grep-for-windows` directly from the command line:

```powershell
grep --update
```

This fetches the latest `Install-GrepForWindows.ps1` from GitHub and runs it. The installer compares its embedded version against the manifest in your installed module folder; if they match, it prints `is already installed` and exits. Otherwise it overwrites the module files in place and reloads the module in the current session.

Alternatively, run the installer directly:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

Check the installed version any time with:

```powershell
grep --version
```

---

## Uninstall

Run the bundled uninstaller from any PowerShell session:

```powershell
Uninstall-GrepForWindows
```

It does three things, in order:

1. Removes the `Import-Module grep-for-windows` line from your `$PROFILE` (saving a `.bak` copy of the original profile next to it).
2. Unloads the module from the current session, freeing the `.psm1` file lock.
3. Deletes the module folder from your modules path.

Pass `-WhatIf` to preview without touching anything, or `-Confirm` to be prompted before it runs.

If `grep` failed to import for some reason (broken profile, manifest tampered with), do it manually: delete the `Import-Module grep-for-windows` line from `$PROFILE`, then `Remove-Item -Recurse "$env:USERPROFILE\Documents\PowerShell\Modules\grep-for-windows"`.

---

## Contributing

Issues and pull requests are welcome. If you find a bug, have a feature request, or want to improve the documentation, please open an issue on the [GitHub repository](https://github.com/kithuto/grep-for-windows).

When submitting a pull request:

1. Fork the repository and create a feature branch.
2. Keep changes focused and write a clear commit message.
3. Test the script in both Windows PowerShell 5.1 and PowerShell 7 if possible.

---

## License

This project is released under the MIT License. See the [`LICENSE`](LICENSE) file for details.
