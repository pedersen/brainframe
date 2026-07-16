# BrainFrame

An open-source, cross-platform **Second Brain + E-Reader** that combines
Obsidian-style knowledge management (markdown notes, graph view, backlinks,
tagging) with Supernote-style document reading and annotation (PDF, EPUB,
handwriting markup).

## Platforms

Built with Flutter for Windows, macOS, Linux, Android, iOS, and the web.
Raspberry Pi + e-ink (via flutter-pi) is a planned target and reuses the Linux
desktop build.

## Architecture notes

- **Adaptive look & feel.** A single Material-based app leans on Flutter's
  built-in adaptive widgets, rendering a Cupertino feel on Apple platforms and
  Material elsewhere. The platform-to-design mapping lives in
  `lib/theme/design_language.dart` and is overridable, so one platform's theme
  is never forced onto another.
- **Desktop window state.** Desktop windows remember their size, position, and
  maximized state between launches (`lib/window/window_state.dart`). This is a
  no-op on web and mobile.
- **Accessibility first.** Custom widgets carry `Semantics` coverage, and the
  app respects system text scaling, high-contrast, reduce-motion, and bold-text
  preferences. See `.claude/rules/accessibility.md`.

## Getting started

```bash
flutter pub get
dart run flutter_launcher_icons   # regenerate platform launcher icons
flutter run -d linux              # or: chrome, windows, macos, android, ios
```

## Command-line options (desktop)

Two startup options are handy for development and testing on desktop targets
(they are ignored on mobile and web, which don't receive command-line
arguments):

| Option | Effect |
| --- | --- |
| `--engram <path>` | Open the engram at `<path>` at startup instead of the last-opened one. If the folder isn't an engram yet, a marker is created in place. The choice is transient — it isn't added to the registry or remembered next launch. |
| `--ignore-config` | Start without reading or writing saved configuration. Preferences are backed by an ephemeral in-memory store, so the engram registry, last-opened engram, window geometry, and theme are neither loaded nor overwritten. |
| `--help`, `-h` | Print usage to the terminal and exit without starting the app. |

Pass them to a built binary directly, or through `flutter run`'s
`--dart-entrypoint-args` (comma-separated):

```bash
# Against a built binary:
build/linux/x64/debug/bundle/brainframe --engram /path/to/engram --ignore-config

# Through flutter run:
flutter run -d linux --dart-entrypoint-args=--engram=/path/to/engram,--ignore-config
```

Combining them — `--engram <fixture> --ignore-config` — opens a known engram in
a clean-slate session that leaves your real configuration untouched, which is
the intended testing setup.

## Development

Contributions flow through the worktree → branch → pull request workflow
described in `.claude/rules/git-workflow.md`. Run `scripts/install.sh` (Linux /
macOS) or `scripts/install.ps1` (Windows PowerShell) to set up the markdown lint
and pre-commit tooling. Add `--check` / `-Check` to validate without changing
anything.

On Windows, PowerShell's default execution policy blocks unsigned scripts. Run
the installer once with a bypass:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install.ps1
```

or allow local scripts for your user permanently (standard developer setting, no
admin needed) so `scripts\install.ps1` runs directly thereafter:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Translations

BrainFrame is built to be translated — the interface, the built-in names, and
the tutorial/help guides. No coding required, and partial translations are
welcome (anything untranslated falls back to English). See the step-by-step
guide in [`lib/l10n/README.md`](lib/l10n/README.md).
