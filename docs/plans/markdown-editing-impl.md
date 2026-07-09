# Implementation plan: Markdown editing + saving

- **Status:** living — design accepted
  ([markdown-editing.md](../design/markdown-editing.md)); ready to build
- **Author:** Claude
- **Date:** 2026-07-04

## Scope of this plan

Turn the read-only browser into a read/write one: edit Markdown source, save
durably (autosave + manual), and manage files (new note, new folder, rename,
delete, move). Design and rationale live in
[docs/design/markdown-editing.md](../design/markdown-editing.md); this plan is
the build order. Live-preview, wikilinks, backlinks, graph, and syntax
highlighting are explicitly out of scope.

## What already exists (and is reused, not rebuilt)

- **Writes to disk** — `EngramStore.writeBytes`/`writeString` and
  `FileSystemEngramStore` ([lib/engram/fs/fs_store_io.dart](../../lib/engram/fs/fs_store_io.dart)).
- **The read-only gate** — `Engram.readOnly` ([lib/engram/engram.dart](../../lib/engram/engram.dart)).
- **The renderer** — `MarkdownReader` ([lib/engram/ui/markdown_reader.dart](../../lib/engram/ui/markdown_reader.dart)),
  reused verbatim for Preview.
- **The host** — `EngramBrowser` ([lib/engram/ui/engram_browser.dart](../../lib/engram/ui/engram_browser.dart)):
  file tree, selection, `_effectiveSelection`, per-engram `_data` listing.
- **Collision-safe naming** — `_safeFolderName` / `_freeChildLocation` patterns
  in [lib/engram/fs/fs_store_io.dart](../../lib/engram/fs/fs_store_io.dart).
- **The viewer dispatch seam** — `buildFileViewer`
  ([lib/engram/ui/file_viewer.dart](../../lib/engram/ui/file_viewer.dart)).

## Build order

Each step is an independently reviewable worktree → branch → PR, per
[.claude/rules/git-workflow.md](../../.claude/rules/git-workflow.md); `main` is
never committed to directly. Every PR keeps `flutter analyze` clean, holds
coverage ≥90% (honest), passes the i18n gate, and adds Semantics for any new
interactive widget. Steps 1+2 may fold together, and 3+4 may fold together, if
the diffs are small.

### Step 0 — Design docs (this PR)

`docs/design/markdown-editing.md` + `docs/plans/markdown-editing-impl.md`.
Consensus reached; design status moved draft → accepted (no
accept-then-amend).

### Step 1 — Store file-management primitives (io seam)

- Add `delete(path)`, `move(from, to)`, `createDirectory(path)` to
  `EngramStore` with doc comments matching the existing contract's tone.
- Implement in `FileSystemEngramStore`, reusing `_resolve` (absolute/`..`
  rejection) and the `.brainframe` marker refusal; `move` guards both paths.
- **Make `writeBytes` atomic** (Decision 5): write to a sibling temp file, then
  `rename` into place, so an interrupted write never truncates the target. The
  contract is unchanged — only durability improves.
- `AssetEngramStore` throws `UnsupportedError`, as `writeBytes` does.
- Tests: FS create/move/delete round-trips, parent auto-creation, marker
  refusal, path-escape rejection, asset `UnsupportedError`; atomic-write leaves
  no stray temp file on success and the original intact if the write is
  simulated to fail before rename.

### Step 2 — `EngramFileOps` folder-composition service

- **Extend the store contract to be directory-aware** (decided during the
  build): add `listDirectories()` (reveals empty folders; defaults to none) and
  `deleteDirectory(path)` (the removal counterpart to `createDirectory`). This
  resolves the "empty folder" question — a folder the user made but has not
  filled is now enumerable, showable, and cleanable, instead of invisible to a
  files-only `list()`. `FileSystemEngramStore` implements both; `AssetEngramStore`
  reports no directories and throws `UnsupportedError` from `deleteDirectory`.
- New `EngramFileOps` service composing folder rename/move/delete over the file
  and directory primitives: recreate the destination tree (empty subfolders
  included) with `createDirectory`, `move` descendant files, then
  `deleteDirectory` emptied shells deepest-first.
- Collision-safe name helper (`EngramFileOps.freeName`) shared with
  new-note/new-folder creation and move destinations.
- Pure-ish; tests use an in-memory `EngramStore` fake to cover folder rename
  with nested content, empty-subfolder preservation, delete-with-descendants,
  shared-prefix isolation, and name collisions.

### Step 3 — `MarkdownSourceEditor` (the swappable seam)

- `StatefulWidget` over a multiline monospace `TextField`: initial text +
  `onChanged` + focus/scroll controllers; explicit Semantics label; respects
  `textScaler`/`boldText`; caret blink off under `disableAnimations`.
- Widget tests: text edits propagate through `onChanged`; label present; no
  raw strings.

### Step 4 — `DocumentEditController` (save pipeline)

- `ChangeNotifier` owning path + buffer + `dirty` + status
  (`saved`/`saving`/`dirty`/`error`); ≈5s idle debounce with a ≈30s max-wait
  cap (both tunable) → `store.writeString` (atomic per Step 1).
- `flush()` on file switch, focus loss, lifecycle `paused`/`detached`
  (`WidgetsBindingObserver`), and manual save.
- Correctness: flush outgoing file before loading next; a stale-path debounce
  is discarded, never written.
- Tests with `fakeAsync` for the timer: idle debounce fires once; the max-wait
  cap forces a write during continuous typing; flush-on-switch;
  flush-on-lifecycle; error keeps buffer dirty; no cross-path write.

### Step 5 — Browser integration

- Introduce an editing-capable Markdown pane wired through `buildFileViewer`
  (or a sibling path it dispatches to), showing the **Edit/Preview toggle** +
  **save-status chip** only for Markdown and only when `!engram.readOnly`.
- Add the **invalidate/re-list seam** to `EngramBrowser` so mutations refresh
  `_data` and update selection.
- Tests: toggle switches modes; read-only engram shows no edit affordances;
  images/unsupported unchanged; list refreshes and selection updates after a
  simulated create/delete.

### Step 6 — File-management UI

- New note / new folder from the sidebar header; accessible per-row action menu
  (rename, delete-with-confirm, move, new note/folder in folder).
- **Reusable in-app folder-picker dialog** (shows the engram's folder tree,
  returns a destination folder) — drives "move"; built to be reused by the
  Pi / e-ink directory browser later.
- New note is seeded with a **minimal H1-from-filename stub**, then opens in
  Edit mode.
- Wire actions through `EngramFileOps` + the Step 5 re-list seam.
- Tests: each action mutates the store and refreshes the tree; delete confirms;
  rename/move update selection; folder picker returns the chosen path; new note
  contains the derived H1; Semantics on menu, picker, and dialogs.

### Step 7 — Polish

- **`Ctrl/Cmd+S` = save now** on the editor pane (both modifiers bound for
  cross-platform), the keyboard equivalent of the save-status chip. The optional
  Edit/Preview toggle shortcut is **deferred**: no strong convention, and the
  obvious keys (`Ctrl/Cmd+E`) collide with text-field editing shortcuts on some
  platforms — not worth a fragile binding.
- i18n sweep: `tool/check_l10n.dart` and the `no_raw_widget_strings` custom lint
  both clean.
- Coverage gate green; the e-ink **active-editor refresh** open item is written
  up in the design doc's "E-ink open item" section.

## Dependencies to add

None. Plain `TextField` (Decision 4). If a code-editor package is adopted
later, it enters behind the `MarkdownSourceEditor` seam as its own change.

## Testing and workflow

- `flutter analyze` clean (pre-commit hook), `flutter test` green, coverage
  ≥90% honest per the Step 0 gate that already exists.
- Markdown lint (`markdownlint-cli2`) to `0 error(s)` before each commit.
- End-to-end sanity per PR where there's runtime surface: launch on desktop,
  open a writable engram, edit → watch status dirty→saving→saved → confirm the
  on-disk file changed; switch files mid-edit and confirm the outgoing file
  flushed; create/rename/delete and confirm tree + disk agree; open a built-in
  (read-only) engram and confirm no edit affordances.

## Things to confirm during the build

- Debounce / max-wait feel (≈5s / ≈30s starting points).
- Whether the folder-picker component lands in Step 6 or is pulled earlier as
  shared infrastructure.
- Whether `move`/folder ops need any e-ink refresh consideration, or defer
  wholesale with the editor's e-ink open item.
