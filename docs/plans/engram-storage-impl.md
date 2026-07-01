# Implementation plan: Engram storage (v1)

- **Status:** living — approved for implementation
- **Author:** Claude
- **Date:** 2026-06-30
- **Companion to:** `../design/engram-storage.md` (the design and its six
  decisions)

## Scope of this plan

This plan builds the **v1 storage layer** and just enough UI to exercise it.
In scope:

- A **test-coverage gate** (≥90%, honest) stood up before any feature work.
- The `lib/engram/` storage seam and its two backends (filesystem,
  asset-bundle).
- Engram model, `.brainframe/` marker + `engram.json`, discovery, registry.
- Create / open / switch engrams; one active engram at a time.
- The two bundled read-only engrams (tutorial, help); first run opens the
  tutorial.
- Desktop free folder choice; iOS Files-app keys (unverified — no hardware).
- A **minimal read-only engram browser** (list files, view one markdown
  file) plus the help reader overlay — only enough to prove the flow.

Explicitly **out** of v1 (named so they don't creep in): a real markdown
editor, backlinks/graph, search indexing, file watching / sync (v3),
sandboxed-platform folder picking and iCloud (v2), and web user-engrams.

## Architecture refinement

Decisions 4 and 5 force one change to the design's original sketch. It
gave `Engram` an `EngramLocation` that always `resolve()`s to a `Directory`.
But a bundled engram is read from the asset bundle, not a directory, so that
contract cannot be universal. The refinement:

- **`EngramStore`** becomes the content-access contract every engram is read
  through (list files, read string/bytes; read-write stores add write /
  delete). The app never touches `dart:io` types directly.
- **`EngramLocation`** is demoted to an implementation detail of the
  *filesystem* store only — it answers "which directory, and how do I get
  access to it" (container path now; picked path and security-scoped
  bookmarks later).
- **`Engram`** holds a `store`, not a `location`, plus `id`, `displayName`,
  and a `readOnly` / `builtIn` flag.

Two stores ship in v1: `AssetEngramStore` (read-only, all platforms) and the
`dart:io` `FileSystemEngramStore` (read-write, behind the platform seam).

Proposed file layout, mirroring the existing `window_state` export seam:

```text
lib/engram/
  engram.dart            // model: id, displayName, readOnly, store
  engram_store.dart      // abstract EngramStore contract
  metadata.dart          // EngramMetadata: engram.json (schemaVersion, id, …)
  id.dart                // ULID helper (or a tiny dependency)
  asset_engram_store.dart   // read-only AssetBundle store (all platforms)
  fs_store.dart          // export seam: stub unless dart.library.io
  fs_store_io.dart       // FileSystemEngramStore (dart:io, read-write)
  fs_store_stub.dart     // web: throws UnsupportedError
  engram_location.dart   // filesystem location: container / picked path
  engram_repository.dart // discovery, registry, create/open, lastOpened
  engram_scope.dart      // InheritedWidget: the single active engram
```

## Build order

Each step is independently testable and builds on the previous one. Step 0
stands up the coverage gate; steps 2–5 are pure logic and run in plain
`flutter test`; platform and UI come after. Per the git-workflow rule,
**each step lands as its own worktree + PR** that you review before it merges
— eleven steps (0–10), eleven reviewable PRs. Two are near-trivial (Step 1
adds dependencies; Step 9 is two `Info.plist` lines); fold either into its
neighbour if you'd rather not review a tiny diff. From Step 1 on, every PR
must keep total coverage at or above the 90% gate.

### Step 0 — Test coverage gate (≥90%, honest)

Stand up coverage measurement and a **≥90% enforced minimum that counts
unreferenced files**, then bring the *current* codebase up to that bar — all
before any feature work begins.

- **Measure:** `flutter test --coverage` writes `coverage/lcov.info`.
- **Count unreferenced files (the honest part):** `flutter test --coverage`
  omits `lib/` files that no test imports, which silently inflates the
  percentage. Fix it with a generated aggregate helper test
  (`test/coverage/all_files_test.dart`) that imports every `lib/**.dart`
  (with `// ignore_for_file: unused_import`), so untested files show as 0%
  instead of vanishing. A `tool/gen_coverage_helper.dart` script regenerates
  it, and the pipeline regenerates before each run so it can never go stale
  as later steps add files.
- **Enforce with coverde:** `coverde filter` strips the excluded files, then
  `coverde check 90` on the filtered trace exits non-zero below 90 — the
  `--fail-under` analog Dart lacks. coverde is chosen over `very_good_cli`
  for its purpose-built `filter` (clean, explicit exclusions) and native HTML
  reports that need no `lcov`/Perl toolchain.
- **Exclusions, explicit and documented:** generated files (`*.g.dart`,
  `*.freezed.dart`) and the untestable bootstrap `main.dart` are filtered in
  one named place, so nothing is hidden silently. `window_state_io.dart`
  (desktop-only, drives a real OS window) is the likely hard case — either a
  focused test or a justified, listed exclusion.
- **Wire the gates:** the pre-push hook runs the shared pipeline below for
  fast local feedback; a GitHub Actions job runs the same on every PR, posts
  the coverage result as a PR comment, then enforces the floor — the
  authoritative gate.
- **Backfill:** write tests for the existing `lib/` until honest coverage is
  ≥ 90%.
- **Verify:** removing a test drops the number and fails the gate; restoring
  it passes; CI blocks a sub-90% PR.

The shared pipeline (the hook and CI run it identically):

```bash
# Regenerate the import-all helper, measure, filter exclusions, gate.
dart run tool/gen_coverage_helper.dart       # import-all test (0% honesty)
flutter test --coverage                       # write coverage/lcov.info
coverde filter -i coverage/lcov.info \
  -o coverage/filtered.info \
  -f 'main.dart' -f '.g.dart'                 # drop documented exclusions
coverde check -i coverage/filtered.info 90    # fail under 90%
```

The PR workflow comments coverage first, then gates (so the comment posts
even when the gate fails):

```yaml
# .github/workflows/coverage.yml
name: coverage
on: pull_request
permissions:
  contents: read
  pull-requests: write          # required to post the PR comment
jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart pub global activate coverde
      - run: dart run tool/gen_coverage_helper.dart
      - run: flutter test --coverage
      - run: |
          coverde filter -i coverage/lcov.info -o coverage/filtered.info \
            -f 'main.dart' -f '.g.dart'
      - name: Comment coverage on the PR
        uses: romeovs/lcov-reporter-action@v0.3.1
        with:
          lcov-file: coverage/filtered.info
          github-token: ${{ secrets.GITHUB_TOKEN }}
          delete-old-comments: true
      - run: coverde check -i coverage/filtered.info 90   # gate, after comment
```

No external service or token: the comment uses the built-in `GITHUB_TOKEN`,
and `romeovs/lcov-reporter-action` updates a single sticky comment per PR
rather than piling up. (Swap in Codecov later if you want hosted trend
graphs.)

### Step 1 — Dependencies and scaffolding

- Add `path_provider` (container directories) and `file_picker` (desktop
  directory dialog) to `pubspec.yaml`.
- Decide ULID: a ~30-line Crockford-base32 helper (no dependency) or the
  `ulid` package. Lean toward the helper to keep the dependency surface
  small.
- Create the `lib/engram/` directory and empty seam files.

### Step 2 — Models and the store contract (pure Dart)

- `EngramStore` abstract interface; `Engram` model; `EngramMetadata` with
  `schemaVersion`, parse/serialize for `engram.json`; `id.dart`.
- **Verify:** unit tests for metadata round-trip and schema-version handling.
  No platform dependencies, so these run fast everywhere.

### Step 3 — Asset-bundle store and built-in engrams

- `AssetEngramStore`: enumerate bundled files via `AssetManifest`, read them
  read-only from `rootBundle`, filtered by an asset path prefix per engram.
- Add skeleton content under `assets/engrams/tutorial/` and
  `assets/engrams/help/` (placeholder markdown to start) and register the
  two directories in `pubspec.yaml` assets.
- **Verify:** unit tests load list/read the built-in content through a test
  bundle. This is the first real non-filesystem backend — doing it early
  proves the `EngramStore` abstraction holds.

### Step 4 — Filesystem store and location (the io seam)

- `fs_store.dart` conditional export (stub vs `_io`), mirroring
  `window_state.dart`. `FileSystemEngramStore` (read-write) over a resolved
  `Directory`. `EngramLocation` for the container path via `path_provider`.
- Create-engram writes the `.brainframe/` marker + `engram.json`, and a
  root `.gitignore` excluding `.brainframe/index/` (Decision 1).
- **Verify:** unit tests create an engram in a temp directory and round-trip
  files; the stub throws on web.

### Step 5 — Repository, registry, discovery

- `EngramRepository`: surface the two built-ins (asset) always; scan the
  container one level deep for markers; resolve registry roots from
  `shared_preferences`; `create` / `forget` / `lastOpened` /
  `setLastOpened`. Unavailable roots degrade to a reconnectable state, never
  a crash.
- **Verify:** tests over a temp container and the `shared_preferences` mock
  for discovery and registry persistence.

### Step 6 — Desktop free folder choice

- Desktop: `file_picker` directory dialog → adopt the folder (create a
  marker if absent, else open) → persist as a registry root (plain-path
  token). Guarded to desktop platforms.
- **Pi caveat:** flutter-pi has no native file dialog, so Pi's
  pick-any-folder needs a small in-app directory browser instead. Defer that
  to the Pi-usability work; the container-default engram already works on Pi.

### Step 7 — EngramScope and app startup

- `EngramScope` `InheritedWidget` holds the single active engram; switching
  releases the previous location before resolving the next (Decision 2).
- Startup: open `lastOpened`, or on true first run open the built-in
  tutorial (Decision 5). Wire into the app shell alongside `AppSettings`.
- **Verify:** widget test that first run lands on the tutorial and that
  switching swaps the scope without rebuilding the app root.

### Step 8 — Minimal UI: picker, first-run, help overlay

- Engram picker/switcher and a minimal read-only file browser + single-file
  markdown viewer (likely `flutter_markdown`), through the adaptive
  `AppScaffold`. Read-only engrams hide create/edit/delete affordances.
- Tutorial opens as a full switch (A); help opens as a read-only reader
  overlay over the current engram (B) (Decision 6).
- **Accessibility (required by rule):** every interactive element gets
  explicit `Semantics` (`label`, `button: true`, `enabled:`) before the step
  is considered done; run `flutter test --accessibility`.

### Step 9 — iOS Files keys (designed, unverified)

- Add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to
  `ios/Runner/Info.plist`. Cannot be built or verified without a Mac +
  iPhone — landed as designed-but-unverified (Decision 3).

### Step 10 — Web stub

- `fs_store_stub.dart` makes user-engram filesystem ops unsupported, but the
  asset store is platform-agnostic, so the repository still returns the two
  built-ins. On web, creating/opening user engrams is disabled; tutorial and
  help render.

## Dependencies to add

| Package | Why | When |
| --- | --- | --- |
| `coverde` | Coverage filter + threshold check (global tool) | Step 0 |
| `path_provider` | Container directories on every platform | Step 1 |
| `file_picker` | Desktop directory dialog | Step 6 |
| `flutter_markdown` | Minimal read-only markdown viewer | Step 8 |
| ULID helper or `ulid` | Stable engram ids | Step 1/2 |

## Testing and workflow

- `flutter analyze` stays clean (enforced by the pre-commit hook); the Step 0
  pipeline runs `flutter test --coverage` and enforces ≥90% on push and in
  CI, and the CI job comments the coverage result on each PR. Steps 2–5 give
  broad logic coverage cheaply; steps 7–8 add widget and accessibility tests.
- Markdown docs pass `markdownlint-cli2` before commit.
- Each step is a single PR you review before it merges; none bundles
  unrelated work into one large diff. If eleven reviews feels like too many,
  the only natural folds are Step 1 into Step 2 and Step 9 into Step 10.

## Things to confirm during the build

- Coverage exclusions: confirm the final filtered set (`main.dart`, generated
  code, possibly `window_state_io.dart`) so the 90% stays honest, and pin the
  action/tool versions (`coverde`, `subosito/flutter-action`,
  `romeovs/lcov-reporter-action`) when wiring CI.
- `AssetManifest` enumeration API and whether listing an asset *directory*
  in `pubspec.yaml` bundles its whole tree (expected: yes, with a trailing
  slash).
- ULID helper vs the `ulid` dependency.
- The minimal-viewer / no-editor boundary in Step 8 — keep it read-only so
  the storage milestone doesn't turn into the note editor.
- Pi's in-app directory browser (Step 6 caveat) — confirm it rides with the
  Pi-usability work rather than v1.
