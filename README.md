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

## Development

Contributions flow through the worktree → branch → pull request workflow
described in `.claude/rules/git-workflow.md`. Run `scripts/install.sh` to set up
the markdown lint and pre-commit tooling.

## Translations

BrainFrame is built to be translated — the interface, the built-in names, and
the tutorial/help guides. No coding required, and partial translations are
welcome (anything untranslated falls back to English). See the step-by-step
guide in [`lib/l10n/README.md`](lib/l10n/README.md).
