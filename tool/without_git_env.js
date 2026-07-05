#!/usr/bin/env node
'use strict';

// Cross-platform stand-in for the Unix-only shell prefix
//   env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE <command>
// used by BrainFrame's local pre-commit / pre-push hooks.
//
// Why it exists
//   Git exports GIT_DIR, GIT_WORK_TREE, and GIT_INDEX_FILE (all pointing at
//   this repo) whenever it invokes a hook. On Linux/macOS those hijack the git
//   calls Flutter makes to detect its own SDK version, so `flutter` reports
//   "0.0.0-unknown" and pub resolution breaks — which is why the hooks stripped
//   them. Windows Flutter reads a cached version stamp and is unaffected, but
//   there `env` isn't on PATH at all (Git ships it under usr\bin), so the
//   original prefix simply can't run.
//
//   This launcher removes those three variables in-process — exactly what
//   `env -u` did — and then runs the command, so the hooks behave identically
//   on POSIX and finally work on Windows. On Windows it also adds Git's bundled
//   Unix tools to PATH so the coverage hook's `bash tool/coverage.sh` resolves.
//
//   It runs under Node on purpose: Node is a required dev dependency (the
//   markdown lint hook needs Node >= 20) and, unlike dart/flutter, is immune to
//   the GIT_DIR hijack, so it is safe as the outer process. These hooks are
//   local-only; CI runs the underlying scripts (tool/coverage.sh,
//   tool/check_l10n.dart) directly, so nothing in CI depends on this file.
//
// Usage: node tool/without_git_env.js <command> [args...]

const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

// This launcher is only ever invoked with the fixed, space-free hook commands
// wired in .pre-commit-config.yaml (e.g. `flutter analyze`, `bash
// tool/coverage.sh`) — never with arbitrary user input. That lets us use
// `shell: true` on Windows (required to launch the .bat shims) without the
// argument-escaping hazard Node 24 warns about via DEP0190; silence that
// warning so it doesn't clutter every hook run.
process.noDeprecation = true;

const argv = process.argv.slice(2);
if (argv.length === 0) {
  console.error('usage: node tool/without_git_env.js <command> [args...]');
  process.exit(64); // EX_USAGE
}

const env = { ...process.env };
delete env.GIT_DIR;
delete env.GIT_WORK_TREE;
delete env.GIT_INDEX_FILE;

if (process.platform === 'win32') {
  addGitUnixToolsToPath(env);
}

const [command, ...args] = argv;
const child = spawn(command, args, {
  stdio: 'inherit',
  env,
  // Needed on Windows to launch the .bat shims (flutter, dart) and Git's bash
  // by name; harmless on POSIX where the command is found on PATH directly.
  shell: process.platform === 'win32',
});
child.on('error', (err) => {
  console.error(`without_git_env: cannot run "${command}": ${err.message}`);
  process.exit(127);
});
child.on('exit', (code, signal) => {
  process.exit(signal ? 1 : code ?? 1);
});

// Git for Windows ships bash/sh (Git\bin) and env plus the coreutils
// (Git\usr\bin) but leaves both directories off PATH. Locate them relative to
// the `git` executable so `bash tool/coverage.sh` can run.
function addGitUnixToolsToPath(childEnv) {
  let gitExe;
  try {
    gitExe = execFileSync('where', ['git'], { encoding: 'utf8' })
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)[0];
  } catch {
    return; // git not found via `where`; leave PATH untouched
  }
  if (!gitExe) return;
  // git.exe lives at <root>\cmd\git.exe (or <root>\bin\git.exe); the Unix tools
  // are siblings under <root>.
  const gitRoot = path.dirname(path.dirname(gitExe));
  const dirs = [path.join(gitRoot, 'bin'), path.join(gitRoot, 'usr', 'bin')]
    .filter((dir) => fs.existsSync(dir));
  if (dirs.length === 0) return;
  // The PATH key casing varies on Windows; Node normalizes it to "Path".
  const pathKey =
    Object.keys(childEnv).find((k) => k.toLowerCase() === 'path') || 'Path';
  childEnv[pathKey] =
    dirs.join(path.delimiter) + path.delimiter + (childEnv[pathKey] || '');
}
