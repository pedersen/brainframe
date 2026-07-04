# Translating BrainFrame

Thank you for helping make BrainFrame friendlier in more languages! You do
**not** need to write any code, and you do **not** need to finish a whole
language at once — a **partial translation is genuinely welcome**, because
anything you leave untranslated automatically falls back to English.

There are two things you can translate, and they are independent — do either or
both:

1. **The interface** — buttons, labels, menus (and the built-in engram names
   "Tutorial" and "Help").
2. **The built-in guides** — the tutorial and help documents that ship with the
   app.

Everything lives in this folder (`lib/l10n/`) and in `assets/engrams/`. This
guide assumes no prior knowledge of Flutter or its localization tooling.

## Locale codes

A translation is named by a **locale code**: a lowercase language, optionally
plus an uppercase region after an underscore.

| Code | Language |
| --- | --- |
| `es` | Spanish |
| `pt_BR` | Portuguese (Brazil) |
| `fr` | French |
| `de` | German |
| `zh_TW` | Chinese (Taiwan) |

If you provide `es` (Spanish) and someone's device is set to `es_MX` (Mexico),
they get your `es` translation — you only need a region code when a region
genuinely differs. Full list of codes:
<https://www.unicode.org/cldr/charts/latest/summary/root.html>.

## 1. Translate the interface

The interface strings live in [`app_en.arb`](app_en.arb) — the English
**template**. An `.arb` file is just JSON: a list of `"key": "text"` pairs, some
with a companion `"@key"` block that describes what the text is for.

Steps:

1. **Copy** `app_en.arb` to `app_<locale>.arb` (e.g. `app_es.arb`).
2. Change the top line `"@@locale": "en"` to your locale (e.g. `"es"`).
3. **Translate the values** — the text on the right of each `":"`. You can
   delete the `"@key"` description blocks in your copy (only the English
   template needs them), or keep them as notes.
4. **Drop the file in this folder.** That is the whole wiring step — the build
   discovers `app_<locale>.arb` automatically and offers your language to any
   device set to it. No code changes.

```json
{
  "@@locale": "es",
  "appTitle": "BrainFrame",
  "switcherNewEngram": "Nuevo engrama",
  "tutorialTitle": "Tutorial",
  "helpTitle": "Ayuda"
}
```

### Leave these alone

- **The keys** — the text on the *left* (`"switcherNewEngram"`). Translate the
  right side only.
- **Anything in `{curly braces}`** — these are placeholders the app fills in at
  runtime. Keep them exactly, but move them to wherever the sentence needs
  them:

  ```json
  "switcherCurrentEngram": "Engrama actual {name}. Cambiar de engrama"
  ```

- **ICU keywords** like `plural`, `select`, `zero`, `one`, `other` — if a
  string contains `{count, plural, ...}`, translate the words *inside* each
  branch but keep the keywords and braces.
- **Proper nouns** such as "BrainFrame" (in `appTitle`) — normally left as-is.

Missing a key? No problem — the app shows the English text for anything you
haven't translated yet.

## 2. Translate the built-in guides

The tutorial and help documents live under `assets/engrams/`, one folder per
engram, with the English pages in an `en/` subfolder:

```text
assets/engrams/
  tutorial/en/welcome.md
  tutorial/en/notes/first-note.md
  help/en/index.md
  help/en/markdown-syntax.md
```

Steps:

1. **Copy** an engram's `en/` folder to a sibling named for your locale — e.g.
   `assets/engrams/help/en/` → `assets/engrams/help/es/`.
2. **Translate the Markdown** in your new folder. Keep the **file names** the
   same (`index.md` stays `index.md`) — links between pages rely on them.
   Translating only some pages is fine; the rest stay English.
3. **Register the new folders** in [`pubspec.yaml`](../../pubspec.yaml) under
   `flutter: assets:`. Flutter's asset list is **not** recursive, so add one
   line per folder (including each subfolder like `es/notes/`):

   ```yaml
   assets:
     - assets/engrams/help/en/
     - assets/engrams/help/es/        # ← your new folder
     - assets/engrams/tutorial/en/
     - assets/engrams/tutorial/en/notes/
   ```

The base `en/` folder defines which pages exist; your translation overrides the
pages you've done, page by page.

## 3. Preview your translation

If you have Flutter set up, run the app and set your device or emulator's
language to your locale:

```bash
flutter run
```

To sanity-check layouts without a real translation, BrainFrame also ships a
**pseudo-locale** — set your device language to `en_XA` (available in debug
builds) and every string becomes accénted and [bracketed~~~]. It exposes
text that's still hardcoded (it stays plain), truncated (its closing bracket
disappears), or too long to fit. It is a development aid only and never shown to
real users.

## What happens after you submit

Open a pull request with your files (see
[`.claude/rules/git-workflow.md`](../../.claude/rules/git-workflow.md)). Two
automated checks keep translations healthy, and neither should trip on a normal
translation:

- A **string gate** (`dart run tool/check_l10n.dart`) makes sure the app itself
  never hardcodes text that skipped this system.
- The **pseudo-locale** is generated from the template, so the interface key set
  stays in sync automatically.

Anything you didn't translate falls back to English — so a partial translation
never breaks the app. Thank you again! 💜
