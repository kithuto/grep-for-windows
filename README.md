# grep-for-windows

> Linux-style `grep` for Windows PowerShell — search files without learning `Select-String`.

`grep-for-windows` is a lightweight PowerShell module that brings the familiar `grep` command to Windows, with both literal and regex search built into a single command. If you come from Linux or macOS and miss running `grep -r "TODO" .` in your terminal, this project gives you the exact same experience on PowerShell — colored output included — without having to memorize `Get-ChildItem | Select-String` pipelines.

No external binaries. No dependencies. Just one function that lives in your PowerShell profile.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option 1: Install script (recommended)](#option-1-install-script-recommended)
  - [Option 2: Manual installation via `$PROFILE`](#option-2-manual-installation-via-profile)
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
- **Recursive search** with `-r` or `--recursive`.
- **Case-insensitive search** with `-i` or `--ignore-case`.
- **Directory exclusion** with `--exclude-dir=name` (repeatable).
- **Zero dependencies** — pure PowerShell, no external binaries to install.

---

## Requirements

- Windows 10 or later
- Windows PowerShell 5.1 **or** PowerShell 7+

---

## Installation

You can install `grep-for-windows` in two ways. Pick whichever you prefer.

### Option 1: Install script (recommended)

Download `Install-GrepForWindows.ps1` from this repository and run it. The script appends the `grep` function to your current user's PowerShell profile, creating the profile file if it does not already exist.

Run this one-liner in PowerShell:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

The installer downloads and runs in your current session, then reloads your profile, so `grep` is ready to use as soon as the script finishes — no need to restart PowerShell.

> `irm` (`Invoke-RestMethod`) downloads the script content and `iex` (`Invoke-Expression`) executes it in the current session. If you'd rather inspect the script before running it, download it first with `irm <url> -OutFile Install-GrepForWindows.ps1`, review the file, and then run it with `. .\Install-GrepForWindows.ps1`.

### Option 2: Manual installation via `$PROFILE`

If you'd rather not run a script, you can copy the function directly into your PowerShell profile.

1. Open your profile in an editor:

   ```powershell
   notepad $PROFILE
   ```

   If PowerShell warns that the file does not exist, create it first:

   ```powershell
   New-Item -ItemType File -Path $PROFILE -Force
   ```

2. Copy the contents of [`Microsoft.PowerShell_profile.ps1`](Microsoft.PowerShell_profile.ps1) (the block between `# --- grep-for-windows: start ---` and `# --- grep-for-windows: end ---`) and paste it at the end of your profile.

3. Save and close the file.

4. Reload the profile:

   ```powershell
   . $PROFILE
   ```

That's it — `grep` is now available in every new PowerShell session.

---

## Usage

### Synopsis

```
grep [-h | --help] [--version] [--update] [-r | --recursive] [-i | --ignore-case] [-e | --regexp] <pattern> [path] [--exclude-dir=folder ...]
```

By default, `grep` searches for the pattern as **literal text** (special regex characters are treated as plain characters). Add `-e` or `--regexp` to interpret the pattern as a **regular expression** instead.

### Options

| Option | Description |
|---|---|
| `-h`, `--help` | Show help and exit. |
| `--version` | Print the installed version and exit. |
| `--update` | Check for a newer version on GitHub and update if found. |
| `-r`, `--recursive` | Recursive search through subdirectories. |
| `-i`, `--ignore-case` | Case-insensitive match. |
| `-e`, `--regexp` | Interpret `<pattern>` as a regular expression instead of literal text. |
| `--exclude-dir=NAME` | Skip any directory named `NAME`. Can be passed multiple times. |
| `<pattern>` | Required. The text or regex to search for. |
| `[path]` | Optional. File or directory to search. Defaults to the current directory (`.`). |

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

---

## Configuration

If there are folders you want `grep` to skip in **every** search (for example `node_modules`, `.git`, or `__pycache__`), you can set them once in your profile instead of typing `--exclude-dir=...` every time.

Open `$PROFILE` and look inside the `Get-GrepExcludedDirs` function for this line:

```powershell
# Add folder names here to always exclude them, e.g. @('node_modules', '.git', '__pycache__')
$excludedDirs = @()
```

Add the folder names you want to exclude as a string array, for example:

```powershell
$excludedDirs = @('node_modules', '.git', '__pycache__', 'dist')
```

Save the file and reload your profile (`. $PROFILE`) or open a new PowerShell session. From that point on, those directories will be skipped automatically. Any folders you pass via `--exclude-dir=...` on the command line are added on top of this list, not replaced — so you can still exclude extra folders ad hoc.

---

## Output format

Each match is printed on its own line in the form:

```
path\to\file.ext:42: line content with the match highlighted
```

- The file path is shown in **magenta**.
- The matched substring is highlighted in **red**.
- The line number follows the path, separated by a colon — same layout as GNU `grep -n`.

---

## Update

You can update `grep-for-windows` directly from the command line:

```powershell
grep --update
```

This fetches the latest `Install-GrepForWindows.ps1` from GitHub, compares the remote version with the one installed in your `$PROFILE`, and:

- If the versions **match** — prints `grep-for-windows X.X.X is already up to date.` and exits.
- If a **newer version is available** — replaces the old block in your profile with the updated code and reloads the profile automatically, so the new `grep` is available immediately in the current session.

Alternatively, you can run the installer directly as you did during installation:

```powershell
iex (irm "https://raw.githubusercontent.com/kithuto/grep-for-windows/main/Install-GrepForWindows.ps1")
```

You can check which version is currently installed at any time with:

```powershell
grep --version
```

---

## Uninstall

Open your profile (`notepad $PROFILE`) and remove everything between the markers:

```
# --- grep-for-windows: start ---
...
# --- grep-for-windows: end ---
```

Save the file and start a new PowerShell session. The `grep` command will be gone.

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
