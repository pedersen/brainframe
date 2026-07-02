# Engram storage design

- **Status:** accepted — all six decisions resolved (2026-06-30)
- **Author:** Claude
- **Date:** 2026-06-30

## TL;DR

An **engram** is BrainFrame's name for a self-contained set of markdown
files (plus assets and metadata) that the app reads, writes, and reasons
over — usually a directory on disk, and the equivalent of an Obsidian
"vault." This document
defines the term, the on-disk layout, the cross-platform storage strategy
(with iOS as the binding constraint), and a Dart abstraction that lets the
rest of the app treat "where the files live" as a solved, hidden detail.

Nothing called "vault" or "engram" exists in the code yet, so this is a
clean greenfield design rather than a rename of existing code. The name
`engram` is adopted from the start.

## Why "engram"

An engram is the physical trace a memory leaves in the brain. It fits the
second-brain framing better than the borrowed "vault," and it gives us a
clean, unloaded noun for the core unit of storage: *a brain holds many
engrams.* The vocabulary below builds on it.

| Term | Meaning |
| --- | --- |
| Engram | A set of markdown + assets BrainFrame manages as one unit (usually a directory). |
| Engram root | The top-level directory of a *filesystem* engram. |
| Engram marker | The `.brainframe/` folder at a root that identifies it. |
| Engram registry | The app-level list of known engram roots. |
| Engram repository | The `EngramRepository` service that discovers, opens, and tracks engrams. |

## The cross-platform reality

The hard requirement — "a set of markdown files in a directory, on every
platform" — is easy everywhere except iOS, so iOS drives the design. There
are two location kinds an engram can live in:

**Location A — inside the app's own container.** Every platform gives the
app a private documents directory (`path_provider`'s
`getApplicationDocumentsDirectory()`). A directory of `.md` files here works
identically on iOS, Android, desktop, and Pi. On iOS, two Info.plist keys —
`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` — promote
that directory into a real, user-visible, externally-editable folder in the
Files app. This is the day-one path.

**Location B — an external folder the user picks.** "Open my existing engram
that lives anywhere on disk, or in iCloud Drive / Dropbox." The cost of this
varies sharply by platform: on **desktop** it is trivial — a native folder
picker returns a plain path, which is all the access handle needs — so it
lands in v1. (Pi has no native file dialog, so its free-folder picking needs
an in-app browser and rides with the later Pi-usability work.) On **iOS** it
requires the document picker plus
**security-scoped bookmarks** (pick → persist a bookmark → resolve on next
launch → coordinate access), which no Flutter plugin covers cleanly and which
needs a small Swift platform channel; that piece is deferred to v2. The
abstraction is identical either way, so the deferral never touches screen
code.

The key design move: **Location A and Location B differ only in how you
obtain a directory handle.** Above the file layer, a *filesystem* engram is
just "a root directory plus an access handle," so the rest of the app never
branches on where it lives.

**The app container is a default, not a constraint.** Only iOS (and, more
loosely, Android) actually sandboxes the app. On desktop and Pi there is no
container to be confined to, so the app-private directory is merely a
sensible *default* place to put a first engram — never a restriction.
Desktop users can create or open an engram at any path they choose. The
layout below describes that default (and iOS-exposed) container; it is not a
limit on where engrams may live.

## On-disk layout

Within a single container, engrams are siblings; each is self-describing via
its marker folder. The tree below is the app-default (and iOS-exposed) case —
on desktop a single engram can equally live at any user-chosen path, picked
directly rather than discovered by scanning a parent:

```text
<app documents dir>/
  Personal/                 ← engram root
    .brainframe/            ← engram marker
      engram.json           ← id, name, schema version, timestamps
    daily/2026-06-29.md
    notes/flutter.md
    assets/diagram.png
  Research/                 ← another engram, a sibling
    .brainframe/
    papers/...
```

Rules:

- **Multiple engrams are supported** — they are simply multiple sibling
  folders, each with its own marker.
- **No nesting.** An engram root must not contain another engram root.
  Nested markers make discovery and "which engram owns this file"
  ambiguous; we forbid it rather than resolve it.
- **The marker makes a folder an engram.** A directory with a valid
  `.brainframe/engram.json` is an engram; a plain folder is not. This lets
  the user create engrams by gesture in BrainFrame, while ordinary folders
  they drop in Files are ignored until adopted.
- **App-level and derived state never goes in the documents directory.** That
  directory is exposed to the Files app and synced wholesale by
  iCloud/Dropbox, so anything inside it travels across devices and is
  user-visible clutter the user can delete. The registry, "last opened
  engram," and global preferences live in `Library/Application Support` (via
  `shared_preferences`, already a dependency). **Derived per-engram caches** —
  the search/graph index — live there too, keyed by engram id and never inside
  the engram, so each device rebuilds its own and nothing syncs or needs a
  `.gitignore`.

### `engram.json` (initial schema)

```json
{
  "schemaVersion": 1,
  "id": "01J9Z…",            // stable ULID, survives renames/moves
  "displayName": "Personal",
  "createdUtc": "2026-06-29T12:00:00Z"
}
```

The folder name is a display convenience; the stable `id` is what the
registry and cross-references key on, so renaming the folder in Files does
not orphan anything.

## The Dart abstraction

The layer mirrors two patterns already in the codebase: the
conditional-import platform seam from
[window_state.dart](../../lib/window/window_state.dart) and the app-wide
`InheritedWidget` settings from
[app_settings.dart](../../lib/theme/app_settings.dart).

Everything above the storage layer reaches an engram through one contract,
**`EngramStore`** — never a raw `dart:io` `Directory`. That puts the
asset-backed built-in engrams (which have no directory) and any future
backend on equal footing with on-disk engrams.

```dart
/// The content-access contract for every engram. Callers use engram-relative
/// paths and never see a Directory. Bytes are the primitive (engrams hold
/// images, PDFs, EPUBs as first-class content, not just markdown); readString /
/// writeString are UTF-8 conveniences implemented on top, so each backend
/// implements only the byte methods. Read-only stores (the asset bundle) throw
/// on writeBytes; read-write stores (the filesystem) implement it. Whether an
/// engram is read-only is carried by Engram.readOnly, not asked of the store.
abstract class EngramStore {
  Future<List<String>> list();                      // engram-relative paths
  Future<Uint8List> readBytes(String path);
  Future<void> writeBytes(String path, Uint8List b); // throws if read-only
  Future<String> readString(String path) async => …; // utf8 over readBytes
  Future<void> writeString(String path, String s);   // utf8 over writeBytes
}

/// One engram: its identity plus the store its content is reached through.
class Engram {
  final String id;
  final String displayName;
  final bool readOnly;
  final EngramStore store;
}

/// Discovers, opens, creates, and remembers engrams. Persists the registry
/// in shared_preferences; surfaces the built-ins from the asset store.
abstract class EngramRepository {
  Future<List<Engram>> discover();          // built-ins + container + roots
  Future<Engram> create(String displayName);
  Future<Engram> adopt(EngramLocation location); // wrap a picked folder
  Future<void> forget(String id);           // drop from registry, leave files
  Future<Engram?> get lastOpened;
  Future<void> setLastOpened(String id);
}
```

Two stores implement the contract in v1: a read-only `AssetEngramStore` over
the Flutter asset bundle (all platforms) and a read-write
`FileSystemEngramStore` behind the `dart:io` seam. `EngramLocation` is *not* a
top-level concept — it is an implementation detail of the filesystem store,
answering "which directory, and how do I get access to it" (container path
now; picked path and security-scoped bookmarks later). Only that store ever
touches a `Directory`. The concrete `lib/engram/` file layout lives in the
implementation plan.

The current engram is exposed to the widget tree by an `EngramScope`
`InheritedWidget`, so screens read `EngramScope.of(context).engram` the same
way they read `AppSettings.of(context)` today. Switching engrams swaps that
single value — engram-scoped subtrees rebuild and the previous engram's store
is released (closing any filesystem location handle) — while the app root is
untouched.

## Discovery

The two built-in engrams (tutorial, help) are always available, read from
the asset bundle — never discovered or registered. User engrams are found as
follows:

1. Enumerate the app documents directory one level deep; any child with a
   valid marker is an engram (Location A).
2. Add roots from the registry that live outside the container (Location B),
   resolving each from its stored token.
3. Drop entries that fail to resolve (deleted folder, stale bookmark,
   iCloud file not yet downloaded) into an "unavailable" state rather than
   crashing — surface them as reconnectable, not gone.

## Designed-for-external-mutation from day one

Because Location A folders are editable from the Files app, synced by
iCloud, and (when the same synced folder is opened on desktop) written by
another BrainFrame instance, **BrainFrame is never guaranteed to be the
sole writer.** This shapes the file layer even in v1:

- Treat reads as potentially-stale; re-scan an engram on app resume.
- Tolerate files appearing, vanishing, and changing under us; never cache
  the tree as authoritative without a revalidation path.
- On iOS, account for iCloud placeholder (`.icloud`) stubs — a listed file
  may not be materialized yet.
- Use OS file coordination when we add Location B (the picker world expects
  `NSFileCoordinator`); design the write path so coordination can wrap it.

Baking these assumptions in now is cheap; retrofitting them onto a
sole-writer design later is not.

## Platform plan

| Platform | Default engram | Pick any folder | Notes |
| --- | --- | --- | --- |
| macOS / Windows / Linux | Yes | v1 — native dir picker, plain path | No sandbox; the container is just a default. |
| Pi (flutter-pi) | Yes | later — in-app browser (no native dialog) | No sandbox; free-folder rides with Pi-usability work. |
| Android | Yes | v2 — SAF folder | App-specific storage by default. |
| iOS | Yes | v2 — security-scoped bookmarks | v1 ships the Files-exposed container (Info.plist keys). |
| Web | No | — | Deferred; future multi-user web is its own server backend (Decision 4). |

New dependency: `path_provider`. Desktop/Pi free folder choice is a native
directory picker plus a stored path — cheap, v1. The iOS work is two
Info.plist keys for v1; the Swift security-scoped-bookmark channel is a
separate, later piece.

## UI touchpoints (brief)

Storage is the focus, but the engram picker/switcher that rides on top must
follow the project conventions: rendered through the adaptive `AppScaffold`
design seam, and — per the accessibility rule — every interactive element
carrying explicit `Semantics` (`label`, `button: true`, `enabled:`). Called
out here only so it is not forgotten; full UI is out of scope for this doc.

## Suggested phasing

1. **v1 — multi-engram, with free folder choice where it's cheap.**
   `path_provider`, marker + `engram.json`, discovery, registry,
   create/open/switch, iOS Files keys — **plus pick-any-folder on desktop**
   (native picker, plain path). v1 also ships the two built-in read-only
   engrams (tutorial, help) from an asset-bundle store and opens the tutorial
   on first run. A real multi-engram markdown store on every platform except
   web, with full free placement on desktop.
2. **v2 — free folder choice on the sandboxed platforms.** iOS document-picker
   adoption + security-scoped bookmarks (Swift channel), plus optional
   iCloud-container storage; Android SAF folder picking. All Apple-side work
   awaits Mac + iPhone hardware to verify.
3. **v3 — sync awareness.** File watching, conflict surfacing, coordinated
   writes, iCloud placeholder handling hardened.

## Decisions

1. **Marker name → `.brainframe/`** (2026-06-30). One app-owned namespace per
   engram root. The interop alternative — a sibling `.engram/` holding
   engram-wide data for *other* tools to consume — is deferred: there is no
   concrete external consumer yet, and everything engram-wide already lives
   in `engram.json` or as ordinary content (e.g. a root `README.md`). A public
   namespace is a cheap additive change if a real external consumer ever
   appears.
2. **One engram open at a time** (2026-06-30). `EngramScope` holds a single
   active engram, never a collection; the picker lists all known engrams but
   only one is open. Switching tears down engram-scoped state (open note,
   in-memory index, file watchers) and releases the previous engram's store —
   for a filesystem engram in Location B, the old security-scoped handle must
   be `release()`d before the new one is `resolve()`d. Need two at once? On
   desktop, open another copy of the app and switch it to the other engram
   (each instance's current engram is in-memory; the shared "last opened"
   hint is last-writer-wins across instances, which is harmless). On
   iOS/Android it is not offered — no multi-window, and small screens make a
   single focused engram the right model regardless.
3. **iCloud container deferred to v2** (2026-06-30), with the rest of
   Location B. It cannot be built or tested without a Mac and an iPhone, so
   shipping it now would be unverifiable complexity. The same caveat applies
   to every iOS specific (the Files-app Info.plist keys, the security-scoped
   bookmark channel): treat them as designed-but-unverified until that
   hardware exists. The architecture already keeps iOS off the critical
   path: the cross-platform core is fully exercised on desktop, Android, and
   Pi, and iCloud, when built, is just another `EngramLocation` (resolve a
   ubiquity-container directory), so deferring it changes no interface.
4. **Web storage deferred; revisited post-Pi as its own backend**
   (2026-06-30). No browser storage backend is built now. The eventual web
   goal is a multi-user website with server-side storage and proper per-user
   security — a fundamentally different shape from the local-filesystem
   model, and explicitly late-stage (after the Pi build is usable). A
   browser-local backend (IndexedDB/OPFS) is *not* a stepping stone toward
   that goal — it is single-user and serverless — so building one now would
   be throwaway work. Two consequences for the design today: (a) the
   multi-user web backend will be a sibling `EngramStore` implementation,
   *not* another `EngramLocation`
   (which is filesystem-bound and won't "resolve to a directory" on a
   server); (b) as cheap insurance, keep `dart:io` / `File` / `Directory`
   confined behind the storage seam — code above `EngramStore` speaks in
   engram operations, never raw filesystem types — exactly as the existing
   window seam confines its platform code. For v1, web has no filesystem
   store, so it offers only the two built-in engrams (tutorial, help) from
   the asset store, and no user engrams.
5. **First run opens a bundled tutorial; two built-in read-only engrams ship
   with the app** (2026-06-30). BrainFrame bundles two engrams the user
   cannot edit or delete — a **tutorial** engram that walks them through the
   app, and a **help/documentation** engram for reference the tutorial can't
   or shouldn't carry. First launch opens the tutorial; from there the user
   creates a new engram or opens an existing one. This makes read-only a
   first-class engram property: `Engram` gains a `readOnly` flag,
   built-in engrams have fixed well-known ids (e.g. `builtin-tutorial`,
   `builtin-help`), are always present, never appear in the user-editable
   registry, cannot be forgotten or deleted, and disable note
   creation/editing in the UI. Recommended backing: load them read-only from
   the Flutter **asset bundle** (`rootBundle` + `AssetManifest`), not a disk
   copy — uneditable by construction, always pristine, and updated with the
   app, with no unpack step or migration. That makes the bundled engram the
   first one that is *not* a `dart:io` directory, so it is the concrete
   forcing case for Decision 4's discipline — content is reached through an
   abstract `EngramStore`, not by assuming `resolve() → Directory` —
   and it gives v1 a real, testable non-filesystem backend (asset bundles
   even exist on web, so tutorial/help can render on the web stub). The
   copy-to-container alternative is rejected: it makes "uneditable" a soft UI
   convention and adds update migration.
6. **Tutorial opens as a full engram switch; help is a read-only reader
   overlay** (2026-06-30). The tutorial uses resolution (a): on first run it
   is the active engram in `EngramScope`, and the user leaves it by creating
   or opening their own engram. The help engram uses resolution (b): a
   "Help" affordance opens it in a lightweight read-only reader overlay that
   floats over the current engram without displacing it, so it can be
   consulted while editing. This refines Decision 2 — `EngramScope` still
   holds exactly one active engram (an editable one, or the tutorial), while
   the help overlay is a non-exclusive reader on top, reading from the same
   asset-bundle store, and never becomes the active engram.
7. **`EngramStore` is bytes-first; binary content is first-class**
   (2026-07-02). Engrams hold images, PDFs, and EPUBs alongside markdown —
   document reading is a founding product pillar, not an edge case — so the
   store's primitives are `readBytes` / `writeBytes`, with `readString` /
   `writeString` as UTF-8 conveniences layered on top (each backend implements
   only the byte methods). This amends the text-only contract sketched above
   and was done as a small standalone change before the repository (Step 5)
   and any viewer are built on the seam, when there were two backends and no
   content consumers — the cheapest moment to widen it. The contract stays
   whole-file for now; streaming / random-access reads for very large
   documents are additive and deferred to the later binary-handling design,
   which also owns viewers, rendering, and import.
