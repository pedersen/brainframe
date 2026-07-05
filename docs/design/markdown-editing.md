# Markdown editing design

- **Status:** accepted (2026-07-05)
- **Author:** Claude
- **Date:** 2026-07-04

## TL;DR

BrainFrame can read an engram but not change it. This document defines how a
user **edits Markdown and how those edits reach disk durably**, plus the
**file-management** operations (new note, new folder, rename, delete, move)
that make an engram a place you *keep* notes rather than only view them.

The store layer already writes — `EngramStore.writeBytes`/`writeString` exist
and `FileSystemEngramStore` implements them, with `Engram.readOnly` already
carried as the gate for edit affordances. Everything missing is above the
store: file-management primitives on the store contract, an editing surface, a
save controller, and the browser wiring that turns the read-only viewer into a
read/write one. This is the last major *foundation*; the harder items
(live-preview rendering, wikilinks/backlinks, graph, annotation) iterate on top
of it later.

## Scope

### In scope

- Editing Markdown source and saving it durably.
- Full file management: new note, new folder, rename, delete, move.
- An Edit/Preview toggle; Preview reuses the existing read-only reader.

### Out of scope (deliberately deferred)

- **Live-preview / WYSIWYG** editing (rendered text with raw Markdown revealed
  only on the focused line — the design-handoff vision). This is one of the
  "challenging items" and rides on the source editor built here.
- **Wikilinks, tags, backlinks, graph, annotation** — later features.
- **Drag-and-drop** tree reordering — e-ink-hostile; `move` is an explicit
  relocate action, not a drag.
- **Syntax highlighting** in the source view — see Decision 4 below.

## The editing model

**A source editor with an Edit/Preview toggle**, not live-preview. Editing is
raw Markdown in a plain text pane; a header toggle flips to a rendered preview
that reuses the existing `MarkdownReader`
([lib/engram/ui/markdown_reader.dart](../../lib/engram/ui/markdown_reader.dart)).
One mode at a time — no split pane.

Why this and not live-preview now:

- **It is a genuine foundation, not a throwaway.** Live-preview is a rendering
  layer *over* a source buffer + save pipeline. Building the buffer + save
  pipeline first is on the critical path either way.
- **It is testable and honest.** A plain text buffer has unambiguous behavior;
  ≥90% honest coverage is reachable without simulating a WYSIWYG caret model.
- **It respects the constraints.** One-mode-at-a-time is friendlier to phone
  width and the e-ink refresh model than a live split.

Preview is read-only and identical to today's reader, so what you see in
Preview is exactly what the reader shows elsewhere — no second renderer to keep
in sync.

## The save model

**Debounced autosave is primary; manual save is also available.** There is no
mode where the user must remember to save, and no mode where the user is denied
the ability to force a save.

- **Autosave:** after an idle pause of ≈5s the buffer is written to the store.
  A **max-wait cap** (≈30s) bounds continuous typing: because each keystroke
  resets the idle timer, an uninterrupted burst would otherwise never checkpoint
  until the typist pauses, so the buffer is also written at least once per cap
  interval while editing continues. Both values are tunable.
- **Flush points:** the buffer is always written immediately on **file
  switch**, **focus loss**, and **app lifecycle pause/detach** — so leaving,
  backgrounding, or closing never strands edits.
- **Manual save:** `Ctrl/Cmd+S`, and a tap on the save-status chip, flush the
  same buffer immediately. This is the "on disk *now*" affordance and pairs
  with the status indicator.
- **Status:** a small indicator reports `saved` / `saving` / `dirty` /
  `error`, echoing the design handoff's "Synced" cue.
- **Durability (crash safety):** every write is **atomic** — the store writes
  to a sibling temp file and `rename`s it into place, which is atomic on POSIX
  within one filesystem. A crash or power loss mid-write can never leave a
  truncated or half-written note: the reader sees either the intact previous
  file or the complete new one. This lives in the store's `writeBytes` (see
  [Decision 5](#decision-5--writes-are-atomic)), so it protects every writer,
  not only the editor.
- **Failure:** a failed write sets status `error`, keeps the buffer `dirty` for
  retry, and surfaces non-blocking. Edits are never silently dropped.

Two correctness rules the implementation must honor:

1. **Switching files flushes the outgoing file before loading the next.**
2. **A pending debounce never writes to a stale path** — each scheduled write
   captures the path it targets, so a debounce that fires after a switch is
   discarded rather than writing new content over the wrong file.

## Store: file-management primitives

The `EngramStore` contract
([lib/engram/engram_store.dart](../../lib/engram/engram_store.dart)) gains the
minimum needed for full file management, all over engram-relative,
forward-slashed paths, consistent with the existing `list`/`readBytes`/
`writeBytes`:

| Method | Meaning |
| --- | --- |
| `delete(path)` | Remove the file at `path`. |
| `move(from, to)` | Move/rename a file. |
| `createDirectory(path)` | Create an (empty) directory shell. |

- **Read-only stores throw `UnsupportedError`**, exactly as `writeBytes` does
  today; callers gate on `Engram.readOnly` and never catch. The asset-backed
  built-in engrams (`AssetEngramStore`) stay unwritable.
- **`FileSystemEngramStore`** implements them with `dart:io`, reusing its
  `_resolve` guard (rejects absolute paths and `..` escapes) and its refusal to
  touch the `.brainframe` marker
  ([lib/engram/fs/fs_store_io.dart](../../lib/engram/fs/fs_store_io.dart)).
- **`createDirectory` earns its place** because folders are otherwise implicit
  in the filesystem (a file write creates its parents), but "new empty folder"
  and the destination shell of a folder rename need an explicit directory.

Alongside these, **`writeBytes` becomes atomic** in `FileSystemEngramStore` —
write to a sibling temp file, then `rename` into place — so every write, not
just the editor's, is crash-safe (see
[Decision 5](#decision-5--writes-are-atomic)). The contract is unchanged; only
the FS implementation's durability improves.

### Folders compose over file primitives

Folder rename/move/delete are **not** new store methods. A small service,
`EngramFileOps`, enumerates a folder's descendants via `store.list()` and
applies per-file `move`/`delete`, plus `createDirectory` for the destination.
Keeping the store contract at the file level keeps every backend (asset,
filesystem, future) small, and keeps folder semantics in one tested place.

Collision-safe naming ("Untitled", then "Untitled 2", …) reuses the existing
`_safeFolderName` / `_freeChildLocation` pattern already in
[lib/engram/fs/fs_store_io.dart](../../lib/engram/fs/fs_store_io.dart) rather
than inventing a second scheme.

## The editing surface (a swappable seam)

`MarkdownSourceEditor` is a `StatefulWidget` wrapping a multiline `TextField`
(monospace, expands to fill its pane, its own scroll controller). Its contract
is deliberately narrow — initial text plus `onChanged` plus focus/scroll
controllers in, nothing else — so **nothing above it knows it is a
`TextField`**.

That narrowness is the point: swapping the internals for a code-editor package
(`re_editor`, `flutter_code_editor`) later, once syntax highlighting earns its
dependency, is a change confined to this one widget. The save controller, the
toggle, and the browser all talk to the seam, not the text field. (See
Decision 4.)

## Browser integration

In `EngramBrowser`
([lib/engram/ui/engram_browser.dart](../../lib/engram/ui/engram_browser.dart)):

- The Markdown pane gains an **Edit / Preview** toggle and a **save-status
  indicator** in its header, shown **only for Markdown files** and **only when
  `!engram.readOnly`**. Built-in tutorial/help engrams stay view-only — no
  toggle, no editor. Images and unsupported files stay read-only.
- Preview mode renders through the existing `MarkdownReader`; Edit mode hosts
  `MarkdownSourceEditor` bound to a `DocumentEditController`.
- The file list (today loaded once per engram into `_data` in
  `didChangeDependencies`) needs an **invalidate/re-list seam** so create /
  rename / delete refresh the tree and update the selection — selecting a new
  note after creation, and falling back through the existing
  `_effectiveSelection` after a delete.

## File-management UI

- **New note** / **new folder** from the sidebar header (the design's `+`
  action): name prompt → create → open the new note in Edit mode. A new note
  is seeded with a **minimal stub — a single H1 derived from the filename**
  (e.g. `the-beginning-of-infinity.md` → `# The Beginning of Infinity`), not an
  empty file.
- **Per-row actions** (rename, delete, move, new note/folder within a folder)
  via an **accessible row action menu button** — not hover or right-click
  alone, since e-ink and touch have no hover. Delete asks for confirmation.
- **Move** is a relocate action driven by an **in-app folder-picker dialog**
  that shows the engram's folder tree and lets the user choose a destination —
  not drag-and-drop. This picker is built as a **reusable component**: the
  Raspberry Pi / e-ink target needs an in-app directory browser anyway (it has
  no native file dialog — see `engram-storage.md`), so standardizing on one
  in-app folder chooser here avoids building a second one later.

## Accessibility

Per [.claude/rules/accessibility.md](../../.claude/rules/accessibility.md),
every new interactive element ships with Semantics coverage: the Edit/Preview
toggle, the save-status chip, the row action menu, and every dialog. The editor
itself is a `TextField`, already a semantic text field, but gets an explicit
label and respects `textScaler` and `boldText`. The caret blink is disabled
under `MediaQuery.disableAnimations` (Reduce Motion, and the e-ink target).

## E-ink note (flagged, not solved here)

Live text editing — a blinking caret, per-keystroke feedback — is in tension
with the e-ink model of pushing frames only on deliberate user action. Like the
screen-reader note in the accessibility rules, **the editor primarily targets
the companion desktop/mobile interfaces**. The refresh strategy for an *active*
editor on the e-ink panel (partial refresh cadence while typing) is a real
problem that belongs with the flutter-pi embedder work, not this chunk. It is
recorded here as an open item so it is not silently assumed solved.

## i18n

Every new user-facing string routes through `AppLocalizations`
(`lib/l10n/app_en.arb`), enforced by `tool/check_l10n.dart` and the
`no_raw_widget_strings` custom lint. No hardcoded UI strings — this is a gate,
not a preference.

## Decisions

### Decision 1 — Source editor with a toggle, not live-preview

Editing is raw Markdown with an Edit/Preview toggle; Preview reuses the
existing reader. Live-preview/WYSIWYG is deferred. It sits *on top of* the
source buffer + save pipeline built here, so nothing is thrown away.

### Decision 2 — Autosave primary, manual save also available

Debounced autosave with mandatory flush on switch/blur/lifecycle, **plus**
`Ctrl/Cmd+S` and a save-chip tap that flush immediately. No lost-work mode, no
save-denied mode.

### Decision 3 — File-level store primitives; folders compose above

`delete` / `move` / `createDirectory` join the store contract at the file
level; folder operations live in `EngramFileOps`, composed over them, so every
backend stays small and folder semantics are tested in one place.

### Decision 4 — Plain `TextField` now, behind a swappable seam

The editing surface is a plain Flutter `TextField` — no new dependency — behind
the narrow `MarkdownSourceEditor` contract. We are **not** locked in: a later
swap to a code-editor package for syntax highlighting is a localized change to
that one widget. We go plain now and revisit when highlighting earns its keep.

### Decision 5 — Writes are atomic

`FileSystemEngramStore.writeBytes` writes to a sibling temp file and `rename`s
it into place rather than truncating and rewriting the target. Rename is atomic
on POSIX within a single filesystem, so an interrupted write (crash, power
loss) never leaves a truncated or half-written file — a reader sees either the
intact old file or the complete new one. This is why the ≈5s / ≈30s save cadence
is safe: the exposure of a crash is at most the un-flushed buffer, never a
corrupted file on disk. The atomicity lives in the store so it protects every
writer, not just the editor.

## Resolved during refinement

- **Debounce cadence:** ≈5s idle with a ≈30s max-wait cap (both tunable), over
  atomic writes — see the save model and Decision 5.
- **"Move" UX:** an in-app folder-picker dialog, built reusable for the Pi /
  e-ink directory browser — see file-management UI.
- **New-file template:** a minimal H1-from-filename stub — see file-management
  UI.

## Open questions

- Exact debounce / max-wait values (≈5s / ≈30s) — tune against feel and, later,
  e-ink refresh cost.
- Whether the folder-picker component lands in Step 6 or is pulled earlier as
  shared infrastructure — decided at implementation time.
