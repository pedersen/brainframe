# Field Notebook — manual-testing engram

This directory is a **hand-authored engram used for manual testing only**. It is
deliberately *not* a shipped asset: it is not listed under `flutter.assets` in
`pubspec.yaml`, so it never enters the app bundle. Open it at runtime with the
desktop "choose folder" flow.

## Why it exists

Automated tests cover behavior; this engram exists so a human (or the appshot
tool) can *drive the real app* against a realistic, varied set of notes — folder
nesting, backlinks, inline and standalone images, and a pile of deliberate
markdown edge cases the tutorial engram is too small and too pristine to show.

## Conventions to keep

- **Committed, fixed identity.** `.brainframe/engram.json` carries a hardcoded
  ULID so the engram's identity is stable across machines and CI. Do not
  regenerate it.
- **Self-restoring.** Because the whole tree is committed, destructive manual
  tests (delete / rename / create) are safe: run them, then `git checkout -- .`
  to reset the fixture. This is the throwaway engram the visual-verification
  rule asks for.
- **Not linted.** `test/fixtures/engram/**` is excluded from `markdownlint-cli2`
  (see `.markdownlint-cli2.jsonc`) precisely so the edge-case notes below can
  break the house style on purpose.

## What's deliberately weird (for testing)

- `reference/broken-links.md` — links that point nowhere, to test unresolved
  link handling.
- `reference/` also holds a unicode + very-long filename, to test the file tree
  and breadcrumb wrapping.
- `reference/markdown-kitchen-sink.md` — tables, code, task lists, blockquotes,
  deep nesting, over-long lines.
- `reference/wikilinks-and-transclusions.md` — Obsidian `[[wikilink]]` and
  `![[transclusion]]` syntax in every variant (bare name, path, alias, heading,
  block `^id`, image embed, and intentionally-unresolved ones). The app does
  **not** resolve these yet, so today they render as literal text — the file is
  a current-behavior surface and future-feature coverage. A few real notes carry
  the syntax in context too: `daily/2026-06-01.md` holds the `^heron-channel`
  block anchor plus an inline embed, and `species/birds/great-blue-heron.md` has
  a wikilink-form "See also".
- `assets/loose-photo.png` — an image with no referring note, to test opening an
  image directly from the file tree.
- `reading list/` — a folder *and* files whose names contain spaces, linked with
  percent-encoded destinations (`Reading%20List%20MoC.md`). Exercises intra-engram
  navigation to spaced filenames, which silently did nothing before the link
  resolver decoded `%20`.

## Not here yet

A PDF and an EPUB belong here eventually, but nothing renders them yet, so they
are deferred.
