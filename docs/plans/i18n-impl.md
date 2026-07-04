# Implementation plan: Internationalization & localization

- **Status:** living — approved for implementation
- **Author:** Claude
- **Date:** 2026-07-04
- **Companion to:** `../design/i18n.md` (the design and its seven decisions)

## Scope of this plan

This plan routes every user-facing surface through a localization layer and
stands up enforcement so a new hardcoded string fails fast. In scope:

- Flutter's official `gen-l10n` scaffold (ARB → `AppLocalizations`) and the
  `MaterialApp` wiring.
- Migrating the ~26 existing UI strings (three files) into `app_en.arb`,
  including `Semantics`/`tooltip` slots.
- A generated, **debug-only** `en_XA` pseudo-locale plus key-parity and
  runtime tests.
- **Two enforcement layers:** a cross-platform Dart CLI gate
  (`tool/check_l10n.dart`) and a `custom_lint` rule, sharing one slot
  definition.
- **Built-in content localization:** a locale-partitioned asset layout with
  per-file `en` fallback for the tutorial/help engrams (machinery + English
  content only).
- A beginner-oriented contributor guide covering both translation tracks.

Explicitly **out** (named so they don't creep in): any real second-language
translation (UI or content), an in-app language picker (the `AppSettings`
`localeOverride` seam is reserved, not built — design Decision 5), and
right-to-left / locale-specific formatting polish beyond what
`MaterialLocalizations` gives for free.

## Architecture and layout

The design fixes the model (see [the design doc](../design/i18n.md)):
first-party `gen-l10n`, `en` as the template locale, generated `en_XA` for
pseudo-localization, per-file `en` fallback for built-in content, and dual
enforcement. Concrete file layout this plan creates:

```text
l10n.yaml                       # gen-l10n config (repo root)
lib/l10n/
  app_en.arb                    # template: keys + @-descriptions
  app_en_XA.arb                 # generated pseudo-locale (committed, drift-gated)
  gen/                          # generated AppLocalizations (git-ignored)
  README.md                     # contributor guide (both tracks)
tool/
  gen_pseudo_arb.dart           # app_en.arb -> app_en_XA.arb
  check_l10n.dart               # CLI enforcement gate (Dart, no shell)
  lints/                        # local package: custom_lint plugin
    lib/brainframe_lints.dart   # plugin entry
    lib/src/text_slots.dart     # THE shared "widget text slot" definition
    lib/src/no_raw_widget_strings.dart
assets/engrams/
  tutorial/en/{welcome.md, notes/first-note.md}
  help/en/{index.md, markdown-syntax.md}
```

The one "widget text slot" definition (`tool/lints/lib/src/text_slots.dart`)
is imported by **both** the `custom_lint` rule and the CLI gate (the main
package takes a path dev-dependency on `tool/lints`), so the two enforcement
layers can never disagree about what counts. If that import proves awkward
across the package boundary, the fallback is a duplicated list with a test
asserting the two copies match.

## Build order

Each step is an independently reviewable worktree + PR per the git-workflow
rule, and builds on the previous. **Seven steps, seven PRs.** From Step 1 on,
every PR keeps total honest coverage at or above the 90% gate
([testing-coverage-standard]); generated l10n output is excluded from the
trace (below), and `tool/` code is already outside `lib/` coverage. Steps 1–5
are UI-string work; Step 6 is the content-localization chunk; Step 7 is docs.
Steps 1 and 7 are light — fold either into a neighbour if a tiny diff isn't
worth its own review.

### Step 1 — Scaffold gen-l10n

- `pubspec.yaml`: add `flutter_localizations` (`sdk: flutter`) and `intl`
  (let `flutter pub add intl` resolve the version `flutter_localizations`
  pins), and set `flutter: generate: true`.
- `l10n.yaml` at the repo root (the block in the design doc): `arb-dir:
  lib/l10n`, `template-arb-file: app_en.arb`, `output-dir: lib/l10n/gen`,
  `output-class: AppLocalizations`, `nullable-getter: false`.
- `lib/l10n/app_en.arb`: `@@locale: en` plus a single `appTitle` key.
- Wire `MaterialApp` in [app.dart](../../lib/app.dart): `localizationsDelegates`,
  `supportedLocales: AppLocalizations.supportedLocales`, and replace
  `title: 'BrainFrame'` with `onGenerateTitle: (c) =>
  AppLocalizations.of(c).appTitle`.
- `.gitignore`: add `lib/l10n/gen/`. Exclude it from coverage in **both**
  [tool/coverage.sh](../../tool/coverage.sh)'s `EXCLUSIONS` and the mirror in
  `.github/workflows/coverage.yml`, and skip it in the
  `tool/gen_coverage_helper.dart` import glob so the import-all helper doesn't
  pull in generated source.
- **Verify:** app runs; the title resolves via `onGenerateTitle`;
  `flutter analyze` clean; coverage still ≥90%.

### Step 2 — Migrate the ~26 UI strings

- Add every existing string to `app_en.arb` with a one-line `@key`
  description, keys named per the design's convention (`switcherNewEngram`,
  `browserUnreadable`, `helpTitle`, …).
- Replace the literals in [engram_browser.dart](../../lib/engram/ui/engram_browser.dart),
  [engram_switcher.dart](../../lib/engram/ui/engram_switcher.dart), and
  [help_overlay.dart](../../lib/engram/ui/help_overlay.dart) with
  `AppLocalizations.of(context).<key>` — **including** `Semantics(label:)`,
  `tooltip:`, and `hintText:` slots (accessibility rule: those are
  user-facing too).
- **Verify:** widget tests pump each screen with `AppLocalizations`'
  delegates and assert the localized text renders; nothing changes visually;
  coverage ≥90%.

### Step 3 — Pseudo-locale, parity, and the release filter

- `tool/gen_pseudo_arb.dart`: read `app_en.arb`, emit `app_en_XA.arb` —
  accent letters (`New engram → Ñéw éñgrám`), pad ~35%, bracket `[…]`, and
  leave `{placeholders}` and ICU keywords (`plural`/`select`) untouched. The
  transform is a pure function (unit-testable).
- Make `en_XA` **debug/profile-only**: in [app.dart](../../lib/app.dart) pass a
  `supportedLocales` that is `AppLocalizations.supportedLocales` with `en_XA`
  filtered out when `kReleaseMode`, so release users never resolve to it while
  tests/devs still can.
- **Tests:** (a) key-parity — every `app_*.arb` has exactly the template's key
  set; (b) pump under `en_XA` and assert pseudo markers appear where English
  did (the layer isn't bypassed); (c) the release filter drops `en_XA` from
  `supportedLocales`.
- **Verify:** device locale `en_XA` (debug) shows pseudo text across all three
  screens; a release build omits `en_XA`.

### Step 4 — CLI enforcement gate (Dart, cross-platform)

- `tool/check_l10n.dart`: parse `lib/**.dart` (excluding `lib/l10n/`) with the
  `analyzer` package and exit non-zero on any string literal in a widget text
  slot (the shared `text_slots.dart` set). Also regenerate the pseudo ARB
  in-memory and fail if `app_en_XA.arb` is stale — the drift gate.
- Add `analyzer` as a dev-dependency; introduce `tool/lints/lib/src/text_slots.dart`
  now (consumed by the gate; Step 5 adds the lint that also uses it).
- Wire it in: a `pre-commit` hook (`entry: dart run tool/check_l10n.dart`,
  `files: \.dart$`, `stages: [pre-commit]`) in `.pre-commit-config.yaml`, and
  a CI step. **No `bash`/`grep`** — runs identically on Windows/macOS/Linux.
- **Verify:** passes on the migrated tree; a deliberately re-hardcoded
  `Text('x')` fails it; a hand-broken `app_en_XA.arb` fails the drift check.

### Step 5 — `custom_lint` rule (edit-time layer)

- `tool/lints/` local package with `custom_lint_builder`; a
  `no_raw_widget_strings` rule that flags literals in the same slots via the
  shared `text_slots.dart`.
- Add `custom_lint` (+ the `tool/lints` path dep) to `dev_dependencies` and
  enable the plugin in [analysis_options.yaml](../../analysis_options.yaml).
- Decide the escape hatch: a narrowly-scoped `// ignore: no_raw_widget_strings`
  for the rare legitimate literal in a slot, reviewed like any suppression.
- **Verify:** `flutter analyze` / `dart run custom_lint` squiggles a hardcoded
  string in-IDE and in CI; clean on the migrated tree; the pre-commit
  `flutter analyze` hook now also carries the rule.

### Step 6 — Built-in content localization

- Move assets into `en/` subdirs: `assets/engrams/tutorial/en/…` and
  `assets/engrams/help/en/…`; update the (non-recursive) asset listing in
  `pubspec.yaml` accordingly.
- Make [asset_engram_store.dart](../../lib/engram/asset_engram_store.dart)
  locale-aware: keep engram-relative paths locale-free for callers
  (`welcome.md`), but resolve reads against `<prefix>/<locale>/…` with per-file
  fallback `es_MX → es → en`; `list()` returns the **base-locale (`en`) file
  set**. Do **not** add a `locale` param to the `EngramStore` contract.
- Inject the active locale where a built-in engram is opened
  ([built_in_engrams.dart](../../lib/engram/built_in_engrams.dart) construction,
  driven from `Localizations.localeOf(context)` at the switcher target / help
  overlay), so a locale change reconstructs the store and reloads.
- **Amend [engram-storage.md](../design/engram-storage.md)**: one-line pointer
  on its Decision 5 and status line — *"(Amended 2026-07-04 — built-in content
  is now locale-partitioned under `<locale>/` subdirs; see i18n.md Decision
  7.)"*
- **Tests** (extend the existing asset-store tests): only `en` present →
  non-`en` locale serves the full doc via fallback; a `<locale>/` page present
  → served instead of `en`; `list()` == base set regardless of locale; a
  locale change reloads.
- **Verify:** run under a test locale and confirm fallback vs. override; ships
  English content only.

### Step 7 — Contributor guide (both tracks)

- `lib/l10n/README.md`, beginner-oriented, assuming no ARB/`gen-l10n`
  knowledge, covering both tracks per the design: **UI strings** (copy
  `app_en.arb` → `app_<locale>.arb`, translate values only, preview, read the
  parity output) and **built-in content** (copy `…/en/` pages into a sibling
  `<locale>/`, partial is fine, register the asset dir in `pubspec.yaml`).
- Add a pointer from the top-level [README.md](../../README.md).
- **Verify by following it:** add a throwaway `app_xx.arb` and a throwaway
  `assets/engrams/help/xx/` page exactly as written; confirm each is picked up
  with no Dart change; then remove them. A wrong step means the guide is wrong.

## Dependencies to add

| Package | Why | When |
| --- | --- | --- |
| `flutter_localizations` (sdk) | Localizes Material/Cupertino; provides the delegates | Step 1 |
| `intl` | ARB/`gen-l10n` runtime (lookup, plurals) | Step 1 |
| `analyzer` (dev) | AST parse for the CLI gate | Step 4 |
| `custom_lint` (dev) + local `tool/lints` | in-IDE `no_raw_widget_strings` rule | Step 5 |

## Testing and workflow

- `flutter analyze` stays clean (pre-commit hook), now including the
  `custom_lint` rule from Step 5. The coverage pipeline enforces ≥90% on push
  and in CI, with `lib/l10n/gen/` filtered out.
- The new CLI gate runs on `pre-commit` and in CI on every PR; it is the
  authoritative "no hardcoded strings / pseudo-locale fresh" check.
- Pure tooling logic worth a test even though `tool/` is outside coverage: the
  pseudo transform (`gen_pseudo_arb.dart`) and slot detection (`text_slots.dart`).
- Markdown docs pass `markdownlint-cli2` before commit; each step is a single
  reviewed PR, no unrelated work bundled.

## Things to confirm during the build

- On Flutter 3.44, confirm `gen-l10n` with `output-dir: lib/l10n/gen` and no
  synthetic package emits an importable
  `package:brainframe/l10n/gen/app_localizations.dart`, and that `pub get`
  generates it before `flutter analyze` runs (else fall back to committing it,
  per design Decision 4).
- `intl` version resolves cleanly against the `flutter_localizations` pin.
- `gen_coverage_helper.dart` import glob and the coverde filter both exclude
  `lib/l10n/gen/`, so coverage stays honest.
- `custom_lint` / `analyzer` versions are compatible with the project's Dart
  SDK, and the main package can take a path dep on `tool/lints` (else use the
  duplicated-slot-list-with-sync-test fallback).
- Exact pseudo transform (accent table, padding %, bracket style) and that it
  provably leaves `{placeholders}` / ICU keywords intact.
- The locale-injection point for built-in engrams (Step 6) — where
  `Localizations.localeOf(context)` is read and how a locale change triggers
  the store rebuild + reader reload.
