<#
.SYNOPSIS
    BrainFrame dev-environment setup / validation (Windows / PowerShell port).

.DESCRIPTION
    The Windows counterpart to scripts/install.sh. Same seven checks, same
    exit contract:

        scripts\install.ps1            set up the environment (install missing
                                       tooling, wire git hooks)
        scripts\install.ps1 -Check     validate only; change nothing; exit
                                       non-zero if anything is missing (good
                                       for CI / a quick "am I ready?" check)

    Runs on Windows PowerShell 5.1 and PowerShell 7+. The bash script stays the
    tested path on Linux/macOS; this file keeps the two in step on Windows.
#>
[CmdletBinding()]
param(
    [switch]$Check
)

Set-StrictMode -Version Latest

# We shell out to native CLIs (git, node, flutter, dart, npm, pre-commit) that
# routinely write progress and notices to stderr — e.g. `npm notice ...`. Under
# $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns any native
# stderr line into a terminating NativeCommandError and aborts the whole script,
# and a `*>` redirect can't catch it (it's thrown, not written to a stream). So
# leave this at the default 'Continue' and gate on $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'

# Decode native-tool stdout as UTF-8 so Flutter's bullet separators (•) and
# similar characters don't render as mojibake on the default OEM code page.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$NodeMinMajor = 20   # markdownlint-cli2 needs Node 20+ (uses the regex /v flag)

# ---- output helpers ------------------------------------------------------
# Write-Host with -ForegroundColor renders on both 5.1 and 7+ regardless of
# VT support, so we lean on it instead of raw ANSI escapes.
function Write-Ok   { param([string]$Msg) Write-Host '  ok   ' -ForegroundColor Green      -NoNewline; Write-Host $Msg }
function Write-Warn { param([string]$Msg) Write-Host '  warn ' -ForegroundColor Yellow     -NoNewline; Write-Host $Msg }
function Write-Fail { param([string]$Msg) Write-Host '  fail ' -ForegroundColor Red        -NoNewline; Write-Host $Msg }
function Write-Hint { param([string]$Msg) Write-Host "       $Msg"                          -ForegroundColor DarkGray }

$script:Problems = 0
function Add-Problem { $script:Problems++ }

# `command -v` equivalent: does this command resolve on PATH?
function Test-Cmd {
    param([string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---- 0. must be inside the repo -----------------------------------------
git rev-parse --is-inside-work-tree 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Fail 'Not inside a git repository — run this from your BrainFrame checkout.'
    exit 1
}
$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root
Write-Host "BrainFrame environment check" -ForegroundColor White -NoNewline
Write-Host "  ($Root)"

# ---- 1. Node >= 20 -------------------------------------------------------
if (-not (Test-Cmd node)) {
    Write-Fail 'node not found.'
    Write-Hint "Install Node ${NodeMinMajor}+, e.g. via winget:  winget install OpenJS.NodeJS.LTS"
    Add-Problem
}
else {
    $nodeVer = (node -v).Trim()                       # e.g. v20.11.1
    $nodeMajor = 0
    [int]::TryParse($nodeVer.TrimStart('v').Split('.')[0], [ref]$nodeMajor) | Out-Null
    if ($nodeMajor -lt $NodeMinMajor) {
        Write-Fail "node $nodeVer is too old — need ${NodeMinMajor}+."
        Write-Hint 'Install a newer LTS:  winget install OpenJS.NodeJS.LTS  (then restart the shell)'
        Add-Problem
    }
    else {
        Write-Ok "node $nodeVer"
    }
}

# ---- 2. Flutter SDK -----------------------------------------------------
# Flutter can't be auto-installed (it's a large SDK), so we only validate it.
# The analyze (pre-commit) and coverage (pre-push) git hooks depend on it, and
# its bundled `dart` is what installs coverde below.
if (Test-Cmd flutter) {
    $flutterLine = (flutter --version 2>$null | Select-Object -First 1)
    Write-Ok $flutterLine
}
else {
    Write-Fail 'flutter not found — required by the analyze and coverage git hooks.'
    Write-Hint 'Install Flutter: https://docs.flutter.dev/get-started/install/windows'
    Add-Problem
}

# ---- 3. coverde (Dart global) -------------------------------------------
# The pre-push coverage gate (tool/coverage.sh) uses coverde to filter the
# trace and enforce the 90% threshold. `dart pub global activate` drops
# coverde.bat into %LOCALAPPDATA%\Pub\Cache\bin, which must be on PATH for the
# git hook to find it — so we test that `coverde` actually resolves, not just
# that it was activated. `dart` ships with Flutter (checked above).
$PubCacheBin = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin'
function Get-CoverdeVersion {
    $line = dart pub global list 2>$null | Where-Object { $_ -match '^coverde\s' } | Select-Object -First 1
    if ($line) { ($line -split '\s+')[1] }
}
if (Test-Cmd coverde) {
    $ver = Get-CoverdeVersion
    if (-not $ver) { $ver = 'present' }
    Write-Ok "coverde $ver"
}
elseif ($Check) {
    Write-Fail 'coverde not found on PATH — the pre-push coverage gate needs it.'
    Write-Hint 'dart pub global activate coverde'
    Write-Hint "and add to PATH:  $PubCacheBin"
    Add-Problem
}
elseif (Test-Cmd dart) {
    Write-Warn 'coverde missing — installing via dart pub global activate...'
    dart pub global activate coverde 2>&1 | Out-Null
    if (Test-Cmd coverde) {
        Write-Ok 'coverde installed'
    }
    elseif (Get-CoverdeVersion) {
        # Activated, but the binary doesn't resolve -> pub-cache bin isn't on PATH.
        Write-Fail 'coverde installed but not on PATH.'
        Write-Hint "Add this to your PATH:  $PubCacheBin"
        Write-Hint "e.g.  setx PATH `"`$env:PATH;$PubCacheBin`"   (then restart the shell)"
        Add-Problem
    }
    else {
        Write-Fail 'dart pub global activate coverde failed — install it manually.'
        Add-Problem
    }
}
else {
    Write-Fail 'coverde missing and dart not found to install it — install Flutter.'
    Add-Problem
}

# ---- 4. markdownlint-cli2 ------------------------------------------------
$mdlOk = $false
if (Test-Cmd markdownlint-cli2) {
    markdownlint-cli2 --version 2>&1 | Out-Null
    $mdlOk = ($LASTEXITCODE -eq 0)
}
if ($mdlOk) {
    $verLine = (markdownlint-cli2 --version 2>$null | Select-Object -First 1)
    $m = [regex]::Match($verLine, 'v[0-9.]+')
    $ver = if ($m.Success) { $m.Value } else { 'present' }
    Write-Ok "markdownlint-cli2 $ver"
}
elseif ($Check) {
    Write-Fail 'markdownlint-cli2 not available.'
    Write-Hint 'npm install -g markdownlint-cli2'
    Add-Problem
}
elseif (Test-Cmd npm) {
    Write-Warn 'markdownlint-cli2 missing — installing via npm...'
    npm install -g markdownlint-cli2 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Cmd markdownlint-cli2)) {
        Write-Ok 'markdownlint-cli2 installed'
    }
    else {
        Write-Fail 'npm install of markdownlint-cli2 failed — install it manually.'
        Add-Problem
    }
}
else {
    Write-Fail 'markdownlint-cli2 missing and npm not found to install it.'
    Add-Problem
}

# ---- 5. pre-commit -------------------------------------------------------
function Install-PreCommit {
    # Prefer uv (self-contained, manages its own tool bin), then pipx, then a
    # Python pip. On Windows the bare `pip` command is often absent even when
    # Python is installed, so fall back to `python -m pip` and the `py` launcher.
    if     (Test-Cmd uv)     { uv tool install pre-commit         2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    elseif (Test-Cmd pipx)   { pipx install pre-commit            2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    elseif (Test-Cmd pip)    { pip install --user pre-commit      2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    elseif (Test-Cmd python) { python -m pip install --user pre-commit 2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    elseif (Test-Cmd py)     { py -m pip install --user pre-commit     2>&1 | Out-Null; return ($LASTEXITCODE -eq 0) }
    else                     { return $false }
}
if (Test-Cmd pre-commit) {
    $pcVer = ((pre-commit --version) -split '\s+')[1]
    Write-Ok "pre-commit $pcVer"
}
elseif ($Check) {
    Write-Fail 'pre-commit not installed.'
    Write-Hint 'Easiest on Windows:  winget install astral-sh.uv  then  uv tool install pre-commit'
    Write-Hint 'Or with Python:  py -m pip install --user pre-commit'
    Add-Problem
}
else {
    Write-Warn 'pre-commit missing — installing...'
    if ((Install-PreCommit) -and (Test-Cmd pre-commit)) {
        Write-Ok 'pre-commit installed'
    }
    else {
        Write-Fail 'could not install pre-commit automatically (no uv / pipx / pip / python found, or it landed off PATH).'
        Write-Hint 'Easiest on Windows:  winget install astral-sh.uv  then re-run this script.'
        Write-Hint 'If you installed via pip --user, add its Scripts dir to PATH, then re-run.'
        Add-Problem
    }
}

# ---- 6. repo config files ------------------------------------------------
foreach ($f in @('.pre-commit-config.yaml', '.markdownlint-cli2.jsonc')) {
    if (Test-Path -LiteralPath $f) { Write-Ok "found $f" } else { Write-Fail "missing $f"; Add-Problem }
}

# ---- 7. wire the git hooks ----------------------------------------------
# pre-commit stage: markdownlint + flutter analyze. pre-push stage: the
# coverage gate (flutter test --coverage + coverde 90% threshold).
# Resolve the real hooks dir: honor core.hooksPath if set, else the git-common
# dir — `git rev-parse` gets this right inside a worktree, where .git is a file
# rather than a directory and a literal ".git\hooks" path would not resolve.
$HooksDir = (git config --get core.hooksPath 2>$null)
if (-not $HooksDir) { $HooksDir = git rev-parse --git-path hooks 2>$null }
$HooksDir = if ($HooksDir) { $HooksDir.Trim() } else { '' }

if (Test-Cmd pre-commit) {
    if ($Check) {
        foreach ($hook in @('pre-commit', 'pre-push')) {
            $hookFile = Join-Path $HooksDir $hook
            if ((Test-Path -LiteralPath $hookFile) -and
                (Select-String -LiteralPath $hookFile -Pattern 'pre-commit' -Quiet)) {
                Write-Ok "git $hook hook installed"
            }
            else {
                Write-Fail "git $hook hook not installed."
                Write-Hint 'pre-commit install --hook-type pre-commit --hook-type pre-push'
                Add-Problem
            }
        }
    }
    else {
        pre-commit install --hook-type pre-commit --hook-type pre-push 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'git pre-commit and pre-push hooks installed'
        }
        else {
            Write-Fail 'pre-commit install failed.'
            Add-Problem
        }
    }
}

# ---- summary -------------------------------------------------------------
Write-Host ''
if ($script:Problems -eq 0) {
    Write-Host 'Environment ready.' -ForegroundColor Green -NoNewline
    Write-Host ' Lint + analyze on commit, tests + coverage gate on push.'
    Write-Hint 'Lint everything now:  pre-commit run --all-files'
    exit 0
}
Write-Host "$($script:Problems) issue(s) need attention" -ForegroundColor Red -NoNewline
Write-Host ' — see the fixes above.'
exit 1
