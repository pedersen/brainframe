#!/usr/bin/env bash
#
# BrainFrame dev-environment setup / validation.
#
#   scripts/install.sh           set up the environment (install missing
#                                tooling, wire git hooks)
#   scripts/install.sh --check   validate only; change nothing; exit non-zero
#                                if anything is missing (good for CI / a quick
#                                "am I ready?" check)
#
# Linux is the supported platform today; it also runs on macOS (bash). Windows
# isn't covered yet — a PowerShell port would slot in alongside, so each check
# below stays focused on a single tool to keep that port straightforward.
set -uo pipefail

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

NODE_MIN_MAJOR=20   # markdownlint-cli2 needs Node 20+ (uses the regex /v flag)

# ---- output helpers ------------------------------------------------------
if [ -t 1 ]; then
  B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; D=$'\e[2m'; X=$'\e[0m'
else
  B=""; R=""; G=""; Y=""; D=""; X=""
fi
ok()   { printf '  %sok%s   %s\n'   "$G" "$X" "$1"; }
warn() { printf '  %swarn%s %s\n'   "$Y" "$X" "$1"; }
fail() { printf '  %sfail%s %s\n'   "$R" "$X" "$1"; }
hint() { printf '       %s%s%s\n'   "$D" "$1" "$X"; }

PROBLEMS=0
problem() { PROBLEMS=$((PROBLEMS + 1)); }

# ---- 0. must be inside the repo -----------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Not inside a git repository — run this from your BrainFrame checkout."
  exit 1
fi
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1
printf '%sBrainFrame environment check%s  (%s)\n' "$B" "$X" "$ROOT"

case "$(uname -s)" in
  Linux)  ;;
  Darwin) warn "macOS detected — best-effort; Linux is the tested platform." ;;
  *)      warn "$(uname -s) detected — only Linux is supported right now." ;;
esac

# ---- 1. Node >= 20 -------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  fail "node not found."
  hint "Install Node ${NODE_MIN_MAJOR}+, e.g.  nvm install --lts"
  problem
else
  node_major="$(node -v | sed 's/^v//' | cut -d. -f1)"
  if [ "${node_major:-0}" -lt "$NODE_MIN_MAJOR" ]; then
    fail "node $(node -v) is too old — need ${NODE_MIN_MAJOR}+."
    hint "nvm install --lts && nvm alias default 'lts/*'  (then restart shell)"
    problem
  else
    ok "node $(node -v)"
  fi
fi

# ---- 2. markdownlint-cli2 ------------------------------------------------
if command -v markdownlint-cli2 >/dev/null 2>&1 \
   && markdownlint-cli2 --version >/dev/null 2>&1; then
  ver="$(markdownlint-cli2 --version 2>/dev/null | grep -oE 'v[0-9.]+' | head -1)"
  ok "markdownlint-cli2 ${ver:-present}"
elif [ "$CHECK_ONLY" -eq 1 ]; then
  fail "markdownlint-cli2 not available."
  hint "npm install -g markdownlint-cli2"
  problem
elif command -v npm >/dev/null 2>&1; then
  warn "markdownlint-cli2 missing — installing via npm..."
  if npm install -g markdownlint-cli2 >/dev/null 2>&1; then
    ok "markdownlint-cli2 installed"
  else
    fail "npm install of markdownlint-cli2 failed — install it manually."
    problem
  fi
else
  fail "markdownlint-cli2 missing and npm not found to install it."
  problem
fi

# ---- 3. pre-commit -------------------------------------------------------
install_precommit() {
  if   command -v uv   >/dev/null 2>&1; then uv tool install pre-commit  >/dev/null 2>&1
  elif command -v pipx >/dev/null 2>&1; then pipx install pre-commit     >/dev/null 2>&1
  elif command -v pip  >/dev/null 2>&1; then pip install --user pre-commit >/dev/null 2>&1
  else return 1
  fi
}
if command -v pre-commit >/dev/null 2>&1; then
  ok "pre-commit $(pre-commit --version | awk '{print $2}')"
elif [ "$CHECK_ONLY" -eq 1 ]; then
  fail "pre-commit not installed."
  hint "uv tool install pre-commit   (or: pipx install pre-commit)"
  problem
else
  warn "pre-commit missing — installing..."
  if install_precommit && command -v pre-commit >/dev/null 2>&1; then
    ok "pre-commit installed"
  else
    fail "could not install pre-commit automatically."
    hint "Install it, then re-run: uv tool install pre-commit"
    problem
  fi
fi

# ---- 4. repo config files ------------------------------------------------
for f in .pre-commit-config.yaml .markdownlint-cli2.jsonc; do
  if [ -f "$f" ]; then ok "found $f"; else fail "missing $f"; problem; fi
done

# ---- 5. wire the git pre-commit hook ------------------------------------
if command -v pre-commit >/dev/null 2>&1; then
  if [ "$CHECK_ONLY" -eq 1 ]; then
    if grep -q "pre-commit" .git/hooks/pre-commit 2>/dev/null; then
      ok "git pre-commit hook installed"
    else
      fail "git pre-commit hook not installed."
      hint "pre-commit install"
      problem
    fi
  elif pre-commit install >/dev/null 2>&1; then
    ok "git pre-commit hook installed"
  else
    fail "pre-commit install failed."
    problem
  fi
fi

# ---- summary -------------------------------------------------------------
echo
if [ "$PROBLEMS" -eq 0 ]; then
  printf '%sEnvironment ready.%s Markdown is auto-linted on commit.\n' "$G$B" "$X"
  hint "Lint everything now:  pre-commit run --all-files"
  exit 0
fi
printf '%s%d issue(s) need attention%s — see the fixes above.\n' "$R$B" "$PROBLEMS" "$X"
exit 1
