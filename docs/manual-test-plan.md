# BrainFrame manual UI test plan

Automated tests (`flutter test`) prove behavior against a fake canvas. This
plan covers what they cannot see: real pixels on a real panel, real input
devices, platform chrome, accessibility services, and the timing of frames.
Hand it to yourself cold and follow the numbered steps — no thinking required.

- **Derived from code, not aspiration.** Every case below maps to a
  user-facing interaction that ships in `lib/` today (as of the current
  `main`). Roadmap features that are designed but not yet coded live in
  [Not yet testable](#not-yet-testable-the-frontier), with the reason each is
  out of reach — the reasons matter as much as the tests.
- **Keep it current.** The maintenance rule lives in [CLAUDE.md](../CLAUDE.md)
  under "Manual test plan": update this file in the same change as any
  user-facing UI change, so it stays in lockstep with the widgets it describes.

## How to read the matrix

The **columns** are the seven target platforms plus the two layout modes:

| Column | Meaning |
| --- | --- |
| **Win / Mac / Lin** | Windows, macOS, Linux desktop builds |
| **Android** | Android phone (small screen, touch) |
| **PixelTab** | Pixel Tablet / any large-screen Android (touch, often no keyboard) |
| **iOS** | iPhone or iPad |
| **Pi/eink** | Raspberry Pi + Waveshare e-ink via flutter-pi |
| **Master-detail** | Wide layout: sidebar + reader side-by-side (window ≥ 720 px) |
| **Full-panel** | Narrow layout: reader fills the pane, sidebar is an off-canvas drawer (window < 720 px) |

**Modes are not a user toggle.** They are the same UI at two widths, chosen by
`_drawerBreakpoint = 720` in
[engram_browser.dart](../lib/engram/ui/engram_browser.dart#L26). A phone is
always full-panel; a desktop/tablet window is master-detail until you shrink it
past 720 px, then it becomes full-panel. So on desktop you test *both* modes by
resizing the window; on a phone only full-panel exists.

**Platform equivalence.** BrainFrame is one Flutter codebase; most interactions
are pixel-identical across platforms. Rather than copy the same recipe seven
times, each feature states the steps **once**, then a per-platform table gives a
verdict per column:

- **✓** — run the steps exactly as written.
- **✓ + note** — run the steps, but with the stated platform delta.
- **N/A — reason** — the feature does not apply here, and *why*. A surprising
  N/A (a feature that *should* work on a platform but is marked N/A) is a signal
  to investigate, not a finished answer.

**Cold-hands convention.** "Open a writable engram" means: launch the app, tap
the engram name in the sidebar footer (or the drawer footer on full-panel), and
pick a **non-read-only** engram (no lock icon). The recommended one for driving
this plan is the committed **Field Notebook** fixture (see Safety) — it is
varied enough to exercise every case. The two built-ins (tutorial, help) are
read-only and show no edit affordances — use them only where a case says
"read-only engram".

> **Safety (from `.claude/rules/visual-verification.md`).** The app reopens
> whatever engram it last used — which **may** be real notes, a throwaway, or a
> built-in. Don't assume; **check what's open** before you touch anything.
> For any destructive-flow case (rename, delete, move, new note), use the
> committed manual-testing fixture **Field Notebook** at
> [`test/fixtures/engram`](../test/fixtures/engram) — do **not** create a new
> engram for this, and never run these cases against real notes. Open it on
> desktop via the engram switcher → **Open folder…**, choosing that directory
> (it carries a `.brainframe` marker, so it adopts as-is). Reset it after any
> run with:
>
> ```bash
> git checkout -- test/fixtures/engram/ && git clean -fd test/fixtures/engram/
> ```
>
> Both halves are needed: `checkout` restores tracked files you edited or
> deleted, and `git clean -fd` removes **untracked** byproducts a test creates —
> folders you added, and the per-engram `.brainframe/settings.json` the app
> writes on the first settings change (e.g. a per-engram theme override, F19).
> `checkout` alone leaves those behind, so the next run starts from a poisoned
> state. (No `-x`, so nothing gitignored is touched.) On mobile / Pi, where
> **Open folder…** isn't offered, create a scratch engram with **New engram**
> instead.

---

## Bug classes this plan hunts

Your architecture produces a specific bug profile. These five classes are woven
into the cases below and also run as dedicated sweeps in
[Bug-class deep-dives](#bug-class-deep-dives):

1. **Declarative-model trap** — a new widget description was built but the
   pixels did not actually change (or changed when they should not have).
   Flutter can rebuild without repainting, and repaint without a visible delta.
2. **E-ink push timing** — does the panel refresh on the deliberate action
   (page turn, pen lift, file open) and *not* on internal-only rebuilds? (Mostly
   frontier today — see the deep-dive and Not yet testable.)
3. **RTL geometry** — the master-detail sidebar flips side via `Directionality`;
   any refresh region or hit-test that assumes a left-anchored sidebar breaks.
4. **Semantics / accessibility** — screen reader, text scaling, high contrast,
   reduced motion, and bold-text via `MediaQuery`, per
   [.claude/rules/accessibility.md](../.claude/rules/accessibility.md).
5. **State survival across rebuild** — nothing lost on a rebuild that should
   persist (scroll offset, edit buffer, selection, divider width, collapse set).

---

## Shipped feature matrix

### F1 — Cold start & desktop window restore

**Steps:**

1. On desktop, resize and move the app window; then quit it.
2. Relaunch the app.
3. Observe the first frame and the settle.

**Expected:** a brief centered progress spinner, then the last-opened engram's
browser. On desktop the window returns to the **size** and **maximized** state
it had at quit; on X11 sessions (Windows, macOS, Linux/X11) it also returns to
its **position**. No flash of a wrong-sized window before restore.

> **Linux/Wayland caveat:** under Wayland the compositor owns window placement —
> the app can restore size and maximized state but **cannot** set position
> (`setPosition` is a no-op). Do **not** flag "position didn't restore" as a bug
> on Wayland; verify size + maximized only. Run the full position check under an
> X11 session.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ + position restore only under **X11**; on **Wayland** size + maximized restore but position does **not** (compositor owns placement) — expected, not a bug | ✓ but **N/A** for window geometry — OS owns the window; only the spinner→engram start applies | same as Android | same as Android | ✓ for start-up; **N/A** for geometry — flutter-pi is single fullscreen surface |

- **Master-detail / Full-panel:** start-up restores whichever mode the current
  width implies; it does not persist a mode.
- **State survival:** the *active engram* survives a restart (persisted via
  `setLastOpened`). Verify the same engram reopens, not the default built-in.
- **Declarative-trap probe:** confirm the spinner is actually replaced by
  content, not painted over by it — shrink the window during launch and confirm
  no ghost spinner remains behind the browser.

### F2 — Master-detail layout & resizable divider

**Steps:**

1. Open any engram in a window **wider than 720 px**.
2. Confirm the sidebar (file tree + footer) sits left, reader right, a thin
   divider between.
3. Drag the divider left and right. Release.
4. Drag it as far right as it goes, then as far left.
5. Quit and relaunch (same window size).

**Expected:** the divider drags smoothly; the sidebar never shrinks below its
floor nor grows enough to starve the reader (reader keeps ≥ 320 px). The chosen
width **persists** across relaunch. The reader fills the full pane height (no
short, vertically-centered block).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | **N/A** — phone width is always < 720 px (full-panel only) | ✓ (drag by touch) | ✓ (iPad; N/A on iPhone < 720 px) | ✓ but discouraged — drag repaints continuously; see e-ink probe |

- **Full-panel:** N/A — there is no divider below 720 px.
- **Keyboard/AT operation (desktop, PixelTab-with-keyboard):** Tab to the
  divider, press **←/→**. Width nudges by 24 px per press and persists on
  release. A screen reader announces it as a slider with a width value.
- **State survival:** dragging the divider must **not** re-list the store —
  after a drag, the tree keeps its scroll offset and collapse state.
- **Declarative-trap probe:** while dragging, only the split should repaint —
  confirm the file tree above does not flicker/reload (it holds the engram's
  file list; a reload here is the bug).

### F3 — Full-panel layout, drawer & scrim

**Steps:**

1. Open an engram in a window **narrower than 720 px** (or on a phone).
2. Confirm the reader fills the pane and the app bar shows a **menu (☰)**
   button on the leading side.
3. Tap ☰. The sidebar slides in from the left over a dark scrim.
4. Tap a file in the drawer.
5. Reopen ☰, then tap the scrim (outside the drawer).

**Expected:** the drawer opens over a scrim; selecting a file opens it in the
reader **and closes the drawer**; tapping the scrim closes the drawer with no
selection change. With Reduce Motion on, the drawer appears/disappears
instantly (no slide/fade).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ (shrink window < 720) | ✓ (shrink window) | ✓ (shrink window) | ✓ | ✓ (portrait / small window) | ✓ | ✓ — but the slide animation is why it must respect Reduce Motion |

- **Master-detail:** N/A — no menu button, no drawer above 720 px.
- **RTL probe:** in an RTL locale the menu button and the drawer must move to
  the **right** edge, and the scrim/slide geometry flip with them (see RTL
  deep-dive; currently frontier — no RTL locale ships).
- **Reduced-motion (a11y):** enable OS Reduce Motion → drawer transition
  duration is zero. This is also the e-ink code path.
- **State survival:** open a file, open ☰ again — the tree still shows the
  correct selected-file highlight and the same collapse state.

### F4 — File tree: folders, selection, horizontal scroll

**Steps:**

1. Open an engram that has folders and long file names.
2. Click a folder's disclosure triangle to collapse it; click again to expand.
3. Collapse a folder, quit, relaunch → confirm it is still collapsed.
4. Select a file with a very long name; scroll the tree horizontally to the end
   of the name.
5. Scroll the tree vertically past many rows.

**Expected:** folders toggle in place (all expanded by default); the collapsed
set **persists per engram** across relaunch; long names are reachable via a
horizontal scrollbar pinned to the sidebar edge; the selected file is
highlighted; vertical scroll is smooth over large trees.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ (open drawer first) | ✓ | ✓ | ✓ |

- **Both modes:** identical tree; in full-panel it lives in the drawer.
- **Declarative-trap probe (ink bleed):** hover or tap a row **wider than the
  sidebar** on a pointer platform — the highlight/splash must stay clipped to
  the tree viewport and **not** bleed across the reader. This is the exact bug
  the local `Material` surface in `_treeView` guards against.
- **A11y:** each row exposes `button: true` with a "File: …" / "Folder: …"
  label and expanded/selected state; folder rows announce expanded/collapsed.
  Row height never drops below 48 px even at large text scale.
- **State survival:** collapsing a folder must not lose the current file
  selection or the reader's scroll position.

### F5 — File selection opens the reader

**Steps:**

1. Open an engram.
2. Tap several different files in the tree.
3. Tap a file, scroll the reader down, tap another file, then tap back.

**Expected:** each tap swaps the reader to that file (breadcrumb updates to the
new path); a freshly opened file starts scrolled at the top, not at the
previous file's offset.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ (drawer closes on select) | ✓ | ✓ | ✓ |

- **Declarative-trap probe:** because the reader is keyed on `path`, switching
  files must actually re-read and repaint — confirm content changes, not just
  the breadcrumb. Rapidly tap A→B→A and confirm the final pixels are A's.
- **E-ink:** file open is a *deliberate* action → the panel should refresh here
  (frontier; see deep-dive).

### F6 — Markdown reader & intra-engram links

**Steps:**

1. Open a `.md` file that contains headings, lists, code, and a relative link
   to another file in the engram (e.g. `[other](sub/other.md)`).
2. Read the rendered output under the muted file-path breadcrumb.
3. Tap the relative link.
4. Open a `.txt` file.
5. Tap an external link (`https://…`) if present.

**Expected:** Markdown renders in a centered readable column (max 720 px);
tapping a relative link that resolves to an existing engram file navigates the
reader to it; `.txt` renders as formatted text (single newlines reflow — known);
external links do nothing (no external opener in this milestone); a link to a
missing file does nothing.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- **A11y:** rendered text is screen-reader readable; text is intentionally
  **not** selectable (avoids unlabeled long-press tap targets) — verify a
  long-press does nothing rather than selecting.
- **Text scaling:** raise OS font scale to max → the column reflows, nothing
  clips, headings and body both scale.
- **Declarative-trap probe:** navigate A→B via a link, then Back-select A in the
  tree — confirm A's content re-renders (not a stale B frame).

### F7 — Image viewer (fit / actual size)

**Steps:**

1. Open an image file (`.png/.jpg/.jpeg/.gif/.webp/.bmp`) — small and large.
2. On a large image, tap the fullscreen/expand button in the header.
3. Scroll the image in both axes.
4. Tap the button again to return to fit.
5. Switch to a different image while in actual-size mode.

**Expected:** default **fit-to-window** shows the whole image centered;
**actual-size** shows natural pixels with an always-visible scrollbar on each
axis; switching files resets to fit (you never land mid-scroll on a new,
differently-sized image).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (color images render grayscale on the panel) |

- **A11y:** the image exposes a generated semantic label (the filename); a
  decode failure shows the unreadable-file message.
- **State survival:** the fit/actual toggle is per-open-image; confirm it resets
  on file switch (the `didUpdateWidget` reset), not carried over.
- **Scrollbars visible without hover:** on touch/e-ink both scrollbars must be
  visible at rest (`thumbVisibility: true`).

### F8 — Unsupported-file placeholder

**Steps:**

1. Open a file whose type has no viewer yet (e.g. `.pdf`, `.epub`, `.docx`).

**Expected:** the shared breadcrumb header, then a centered "can't display this
format" message naming the file. No crash, no blank pane.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- This is the seam PDF/EPUB viewers replace — see Not yet testable.

### F9 — Markdown editor: Edit / Preview toggle

**Steps:**

1. Open a **writable** engram; select a `.md` file. It opens in **Edit** mode.
2. Confirm the header shows a breadcrumb, a save-status chip, and an
   **Edit/Preview** segmented control.
3. Type a new heading in the source.
4. Switch to **Preview**.
5. Switch back to **Edit**.

**Expected:** Edit shows a monospace source field; Preview renders the current
content (including the just-typed heading, because toggling to Preview flushes
first); switching back to Edit shows the in-progress buffer, not the on-open
snapshot.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ (on-screen keyboard) | ✓ | ✓ | ✓ but see e-ink editor open item — live keystrokes are the unsolved panel case |

- **Read-only engram:** N/A — a built-in engram shows the reader with **no**
  toggle and no chip (verify the absence explicitly; F17 checks chrome).
- **Declarative-trap probe:** toggle Edit→Preview→Edit without typing — the
  editor must show the same text each time (buffer is source of truth), and
  Preview must reflect the last edit, not a cached render.
- **A11y:** the source field exposes `textField: true` with a label; text scale
  and bold-text apply; the caret does not blink-fade under Reduce Motion.

### F10 — Save pipeline: autosave, chip, Ctrl/Cmd+S, flush points

**Steps:**

1. In a writable `.md` file (Edit mode), type a character. Watch the chip.
2. Stop typing and wait ~5 s. Watch the chip.
3. Type continuously for > 30 s without pausing. Watch the chip.
4. Type, then immediately press **Ctrl+S** (Windows/Linux/Pi) or **Cmd+S**
   (macOS/iOS with a keyboard). Watch the chip.
5. Type, then **select a different file** without saving; reopen the first.
6. Type, then click **outside** the editor (focus loss).
7. Type, then background/quit the app; relaunch and reopen the file.
8. Edit text, then edit it **back** to the original.

**Expected:**

- Chip goes `unsaved` on first edit; after ~5 s idle it goes `saving`→`saved`.
- During a > 30 s unbroken burst it still checkpoints (`saving`→`saved`) at
  least once (the max-wait cap).
- Ctrl/Cmd+S writes immediately (`saving`→`saved`); the chip is itself a
  tappable "save now" when `unsaved`/`error`.
- Switching files flushes the outgoing file first — the edit is on disk when you
  return; nothing stranded.
- Focus loss and app pause/detach both flush.
- Editing back to the original returns the chip to `saved` and cancels any
  pending write.
- After each save, confirm the **on-disk** file changed (open it outside the
  app).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ (Cmd+S) | ✓ | ✓ + **N/A** for the keyboard save unless a HW keyboard is attached — tap the chip instead | ✓ (HW keyboard optional) | ✓ (Cmd+S with keyboard; else tap chip) | ✓ but keystroke feedback is the unsolved e-ink case |

- **Error path:** if a write fails, the chip shows `error` and the buffer stays
  dirty for retry — hard to force manually; note it as an inspection point.
- **State survival:** the edit buffer must survive Edit↔Preview and a divider
  drag without loss; a file switch must not cross-write content onto the wrong
  file (type in A, switch to B fast — B must never get A's text).
- **E-ink:** the save-status chip changes only on discrete state transitions
  (good for the panel); the *live editor* is the open item.

### F11 — New note / new folder (H1 seed)

> Field Notebook fixture only; reset afterward with checkout + clean (see Safety).

**Steps:**

1. In a writable engram, tap **new-note** (note-add icon) in the sidebar header.
2. Enter a name; confirm **Create**.
3. Tap **new-folder** (folder icon); enter a name; **Create**.
4. Open a folder row's **⋯** menu → **New note** (and **New folder**) *inside*
   that folder.
5. Create a second note with the **same name** as an existing one.

**Expected:** the new note opens in **Edit** mode, pre-seeded with an
`# H1` derived from the filename (`the-beginning` → `# The Beginning`); the new
folder appears in the tree even while empty; row-menu creation nests inside the
folder; a name collision is auto-resolved ("Name", "Name 2") rather than
overwriting; the tree refreshes to show the new item and selects the new note.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ (header/⋯ in drawer) | ✓ | ✓ | ✓ |

- **Read-only engram:** N/A — no header actions, no ⋯ column (F17).
- **A11y:** the name dialog is `AlertDialog.adaptive` (Cupertino on Apple);
  field autofocuses; keyboard "done"/submit creates.
- **State survival:** after creation the tree re-lists but must **keep** other
  folders' collapse state.

### F12 — Rename (file / folder)

> Field Notebook fixture only; reset afterward with checkout + clean (see Safety).

**Steps:**

1. Open a file so it is the current selection.
2. On that file's row, open **⋯ → Rename**; change the name; confirm.
3. Rename a **folder** that contains the currently-open file.
4. Rename a file to a name that already exists in the folder.

**Expected:** a file keeps its extension (you edit only the stem); the open
file stays selected under its **new** path (breadcrumb updates); renaming a
parent folder remaps the open file's path so it stays selected; a collision is
auto-numbered; renaming to the identical name is a no-op.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- **State survival:** the selection/breadcrumb must follow the rename; verify
  the reader still shows the same content, now at the new path.

### F13 — Delete with confirmation (file / folder)

> Field Notebook fixture only; reset afterward with checkout + clean (see Safety).

**Steps:**

1. On a file row, **⋯ → Delete**. Read the confirm dialog; **Cancel**.
2. Repeat and **Delete** for real.
3. Delete the folder that contains the currently-open file (confirm).

**Expected:** deletion always asks first (naming the item); Cancel changes
nothing; confirming removes the file (or the folder and everything in it); if
the open file was deleted (directly or inside a deleted folder), the reader
falls back to a sensible default (welcome/index/README, else first file), not a
broken/blank pane.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- **A11y:** the destructive action is colored as error; dialog is adaptive.
- **Declarative-trap probe:** after deleting the open file, confirm the reader
  actually repaints to the fallback file — not a stale frame of the deleted one.

### F14 — Move via folder picker

> Field Notebook fixture only; reset afterward with checkout + clean (see Safety).

**Steps:**

1. On a file row, **⋯ → Move**. A folder-picker dialog lists destination
   folders (and root, when the item is not already at root).
2. Tap a destination row (radio selects it); tap **Move**.
3. Move a **folder** into another folder — confirm the picker excludes that
   folder itself and its descendants (can't move into yourself).
4. Move an item into a folder that already has a same-named sibling.

**Expected:** select-then-confirm (a single mis-tap never moves anything); the
item moves, keeping its name (collision auto-numbered at the destination); an
open moved file stays selected under its new path; a folder move remaps the open
file if it lived inside.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (this in-app picker is the intended Pi directory browser) |

- **A11y:** picker rows are indented by depth; **Move** is disabled until a
  destination is selected; dialog is adaptive.

### F15 — Engram switcher (sheet, new engram, open folder)

**Steps:**

1. Tap the engram name in the sidebar footer (or drawer footer).
2. In the bottom sheet, confirm: available engrams listed (current one checked),
   read-only built-ins shown, any **unavailable** engrams shown as disabled
   rows with an "unavailable" subtitle.
3. Tap another engram → it becomes active and the browser rebuilds.
4. Tap **New engram**; name it; confirm it is created and switched to.
5. Tap **Open folder…** (desktop) and adopt an existing folder.

**Expected:** switching swaps the whole browser to the new engram (tree, reader,
title) while the app root does **not** rebuild; the switch persists across
relaunch; New engram creates and opens a writable engram; Open folder adopts a
directory as an engram.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ **N/A** for Open folder — hidden (no desktop dir dialog) | same as Android | same as Android | ✓ for switch/new; **N/A** for Open folder — flutter-pi has no native dialog (in-app browser is future) |

- **New engram** is hidden only on **web** (not a target platform here), so it
  is present on all seven columns.
- **State survival:** switching engrams must not leak the previous engram's
  collapse set or selection into the new one (each is keyed by engram id).
- **Declarative-trap probe:** switch A→B→A quickly; confirm the tree and reader
  show A's real content at the end, not a half-built B.

### F16 — Help overlay

**Steps:**

1. Tap the **?** (help) action in the app bar.
2. Read the floating help; tap an internal link to a sub-page.
3. Tap **Index** to return; tap **✕** (or outside) to close.

**Expected:** help opens as a floating peek **over** the current engram without
changing the active engram; navigating sub-pages works; closing returns you
exactly where you were (same engram, same file, same scroll).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

- **State survival:** this is the strongest "return exactly where you were"
  check — confirm the underlying reader scroll offset and selected file are
  untouched after closing help.

### F17 — Platform chrome & theming

**Steps:**

1. Compare the top bar on an **Apple** platform (iOS/macOS) vs a **Material**
   platform (Win/Lin/Android/Pi): note nav-bar vs app-bar styling.
2. Open a dialog (e.g. New note) on each — confirm adaptive (Cupertino alert on
   Apple, Material elsewhere).
3. Ensure the default theme is **System** (Settings → Appearance, F19), then
   toggle the **OS** dark mode; confirm the app follows.
4. Toggle **OS high-contrast**; confirm the high-contrast theme engages.
5. Open a **read-only** engram; confirm **no** new-note/new-folder header, **no**
   ⋯ action column, **no** Edit/Preview toggle, and a lock icon in the footer.

**Expected:** Apple platforms render `CupertinoPageScaffold` + nav bar; others
render Material `Scaffold` + app bar; dialogs and progress indicators are
`.adaptive`; with the default theme set to System, light/dark follows the OS;
high-contrast themes swap in when the OS asks; read-only engrams expose zero
edit affordances.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| Material chrome | **Cupertino** chrome | Material | Material | Material | **Cupertino** chrome | Material (high-contrast is the natural e-ink look) |

- **Theme is now in-app (F19).** As of the Settings screen, **light/dark is
  user-controllable** (Settings → Appearance), device-wide with an optional
  per-engram override; it follows the OS only while the default is left at
  "System". **High contrast** still has **no** control — OS-driven only.
  **Language/locale** and **design language** (Material vs Cupertino) still have
  no picker — platform/OS-driven only (see Not yet testable). Verify those two
  by looking for, and not finding, any such control.
- **Bold text (a11y):** enable OS bold-text → body and editor text thicken.

### F18 — Open Settings & the responsive shell

**Steps:**

1. In the browser footer (master-detail) or the drawer footer (full-panel),
   find the **gear** icon beside the engram switcher, past a short divider rule.
2. Tap it. Settings opens as a **full page** titled "Settings", with a back
   affordance.
3. Confirm a category master list grouped under **CORE**: Appearance,
   Housekeeping, About — and a detail pane showing the selected category.
4. Select each category; confirm the detail pane swaps.
5. On desktop, resize the window wide→narrow and watch the shell reflow: **≥860
   px** wide split (264 px sidebar); **540–859** medium split (212 px sidebar);
   **< 540** the list and detail **stack** — tapping a category drills into the
   detail with a back bar, and the back bar returns to the list.
6. Press **Escape** (or the app-bar back) to leave Settings.

**Expected:** a full-page settings surface; the shell reflows across three
widths driven by **its own** measured width (not the browser's mode); on the
narrow width it is a master↔detail drill-in with a back bar; Escape/back returns
to the browser exactly where you left it (same engram, file, scroll).

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ (gear in drawer footer; phone width → narrow drill-in shell) | ✓ (wide/medium by orientation) | ✓ (iPhone narrow drill-in; iPad wide/medium) | ✓ |

- **Modes:** the global Master-detail / Full-panel columns describe the
  *browser*; Settings is a pushed full-page route with its **own** breakpoints
  above, so it reflows correctly no matter how the browser was laid out.
- **Reachable from read-only engrams too:** the gear is always present (F19
  covers what's disabled there).
- **State survival:** category selection is **not** persisted across close/open
  — reopening Settings starts at the first category (Appearance). Confirm that's
  what happens (expected, not a bug).
- **RTL probe:** master list anchors right, detail left; the drill-in
  back-chevron mirrors (frontier — no RTL locale ships; see D3).
- **A11y:** category rows are buttons exposing selected state; the narrow-mode
  back bar is operable by screen reader and keyboard.

### F19 — Appearance: default theme & per-engram override

**Steps:**

1. Open a **writable** engram. Settings → **Appearance** → Theme.
2. Set **Default theme** = Dark. Leave Settings; confirm the **whole app** is
   dark. Set it to Light, then System.
3. Set **Engram theme** = Dark while Default = Light (or System). Confirm the app
   is dark for **this** engram.
4. Set **Engram theme** = Follow default; confirm it returns to the default.
5. Set an override on engram A, then switch to writable engram B (no override).
   Confirm B shows the **default**, not A's override.
6. Switch to a **read-only** built-in engram. Confirm the **Engram theme**
   control is **disabled** and the engram shows the device default.
7. Quit and relaunch. Confirm the **default** persists; reopen the engram that
   had an override and confirm the **override** persists.

**Expected:** the default theme is device-wide and applies live; a per-engram
override wins over the default for that engram only; Follow-default defers to the
device default; a read-only/built-in engram cannot override (disabled control)
and always shows the default. The default is stored per **device**
(`shared_preferences`); the override is stored **inside the engram**, so it
travels with the folder.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ but light/dark both render as high-contrast grayscale — the switch applies, the visual delta is subtle |

- **Declarative-trap probe:** changing the theme must repaint the **whole app**
  (surfaces, text, tree, reader), not just the visible settings pane — leave
  Settings and confirm the browser changed too.
- **State survival (D5):** device default in prefs; engram override in the
  engram folder. Advanced check — copy the engram folder to another machine (or
  clear this device's prefs) and confirm the override travels while the default
  does not.

### F20 — Reset window & layout

**Steps:**

1. On desktop, resize the window and drag the sidebar divider to a non-default
   width.
2. Settings → Appearance → **Window** → **Reset window & layout**.
3. Confirm a **snackbar** acknowledges the reset.
4. Quit and relaunch.

**Expected:** on next launch the window returns to its **default size** (and
position on X11 — not Wayland, per F1's caveat) and the sidebar returns to its
**default width**. The reset suspends geometry persistence so quitting does not
rewrite what was cleared.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ (size + maximized; position only under X11) | ✓ but window-geometry part **N/A** (OS owns the window); no persisted sidebar width on a phone → button is effectively a no-op, just confirm the snackbar shows without error | ✓ (sidebar-width reset applies when a split is shown) | same as PixelTab | ✓ for sidebar-width; window-geometry **N/A** (fullscreen surface) |

- **State survival (D5):** after reset + relaunch, geometry and width are
  actually the defaults — verify the clear took *and* the save-on-exit didn't
  quietly rewrite it.

### F21 — Housekeeping: forget an engram

> Non-destructive (forgetting never deletes files) — but still exercise it on a
> throwaway registry entry: adopt the **Field Notebook** fixture via
> **Open folder…** (F15), then forget that. Don't forget a real engram you want
> to keep listed.

**Steps:**

1. Ensure at least one **registry-backed** engram exists (adopt a folder such as
   the Field Notebook fixture via Open folder…).
2. Settings → **Housekeeping**. Confirm the list shows forgettable engrams with
   their on-disk path; built-in and container engrams do **not** appear.
3. Tap **Forget** on one; read the confirm dialog; **Cancel** — nothing changes.
4. Tap **Forget** again; confirm. The row disappears, the engram leaves the
   switcher too, and **its files on disk are untouched**.
5. If an engram's folder is missing on disk, confirm a **MISSING** badge and that
   it can still be forgotten. With nothing forgettable, confirm the empty state.

**Expected:** forgetting drops the engram from BrainFrame's registry (and the
switcher) without deleting files; a confirmation is required; missing entries are
badged and clearable; an empty state shows when nothing is forgettable.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ pane renders, but with no folder-adoption on mobile (F15) there may be **no forgettable engrams** — verify the empty state | same as Android | same as Android | same as Android (no native adoption yet) |

- **A11y:** the Forget button is labeled with the engram name; the confirm dialog
  is adaptive.
- **Declarative-trap probe:** after a confirmed forget, the list actually
  re-loads (the row is gone), not just visually dimmed.

### F22 — About

**Steps:**

1. Settings → **About**.
2. Confirm: logo tile, app name, tagline, a **version pill** reading
   `v<version> · build <n>`, a links card (**Website**, **Contact**), and a
   copyright footer.
3. Tap **Website** → opens `https://brainframe.tech/` in the external browser.
4. Tap **Contact** → opens a mail composer to `getbrainframe@gmail.com`.

**Expected:** identity plus the real version/build (from `package_info`); links
open externally via the platform handler; the footer shows the founding year, or
a `2026–<year>` range once the year advances.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ for display; links **N/A / degraded** — flutter-pi usually has no browser or mail client, so the launch may do nothing. Verify content renders; don't expect the links to open |

- **A11y:** the version pill carries a spoken label; link rows are buttons
  labeled "Website: …" / "Contact: …". Raise text scale → the card reflows.
- **By design:** the logo tile keeps a fixed near-black background in both
  themes (the PNG has a baked-in dark background) — not a high-contrast/theme
  bug.

### F23 — Desktop startup options (CLI flags)

Unlike every case above, this one is exercised **at launch from a terminal**,
not inside the running UI. Run the built desktop binary with the flag (e.g.
`./build/linux/x64/release/bundle/brainframe --help`), or in development
`flutter run -d <device> --dart-entrypoint-args "--engram=/path/to/folder"`.

**Steps:**

1. **`--help` (or `-h`):** run the binary with `--help`. Expected: usage text
   prints to the **terminal** — the app name, a `Usage:` line, the three options
   (generated from the parser, so they can't drift), and the "desktop builds
   only" note — and **no window opens**; the process exits.
2. **`--engram <path>`:** run `brainframe --engram=/path/to/folder` pointing at
   a folder that is **not yet** an engram (e.g. a copy of any folder). Expected:
   the app opens with that folder as the active engram, creating a `.brainframe`
   marker in place if absent. Then quit and relaunch **without** the flag:
   expected the app opens the previously-remembered engram, **not** the
   `--engram` one — it is transient (never registered, never recorded as
   last-opened).
3. **`--ignore-config`:** first, in a normal session, change something
   persistent (set a Dark default theme in F19, resize the window, adopt an
   engram). Relaunch with `--ignore-config`. Expected: **none** of that shows —
   default theme, default window geometry, and an empty registry falling back to
   the tutorial/normal resolution — and nothing you change this session is
   written back. Relaunch once more without the flag: your earlier config is
   **intact** (it was never overwritten).
4. **Bad argument:** run with an unknown flag such as `--nope`. Expected: the app
   still launches normally with defaults — a stray argument never aborts it.

**Expected:** summarized per step above — `--help` is terminal-only and never
starts the UI; `--engram` opens a folder transiently; `--ignore-config` is a
read-nothing/write-nothing clean-slate session; unparseable args degrade to
defaults.

| Win | Mac | Lin | Android | PixelTab | iOS | Pi/eink |
| --- | --- | --- | --- | --- | --- | --- |
| ✓ | ✓ | ✓ | **N/A** — the OS launches the app with no argv; no supported way to pass these flags | same as Android | same as Android | ✓ — flutter-pi forwards Dart entrypoint args (after the embedder's `--` separator); `--help` prints to the controlling terminal |

- **Modes / most probes N/A:** this is a launch-time behavior, so the global
  Master-detail / Full-panel columns and the in-UI bug-class probes don't apply.
- **`--ignore-config` is itself a testing aid:** it's the cleanest way to run the
  Settings / theme / layout cases (F19, F20, D5) without polluting — or being
  polluted by — your real saved config.
- **`--engram` transience is a state check:** confirm it does **not** become the
  last-opened engram, i.e. the override doesn't leak into normal resolution.

---

## Bug-class deep-dives

Run these as focused sweeps; they cut across features and are cheaper to do once
than to repeat per row.

### D1 — Declarative-model trap (built ≠ painted)

The trap: a `build()` ran and produced a new widget description, but the panel
did not actually change — or a repaint happened with no real delta. Probes:

1. **Rapid file A→B→A** (F5): the final on-screen content must be A's, not a
   stale B. Do it fast enough to overlap the keyed `FutureBuilder` reads.
2. **Delete-open-file** (F13): the reader must repaint to the fallback file, not
   hold the deleted file's last frame.
3. **Edit→Preview→Edit** (F9): the buffer text must be identical each Edit
   entry; Preview must show the latest edit (flush-before-preview).
4. **Divider drag** (F2): only the split repaints; the tree above must not
   reload/flicker (a reload is a spurious rebuild propagating too far).
5. **Ink bleed** (F4): a row wider than the sidebar must clip its highlight to
   the tree viewport — a bleed onto the reader is paint escaping its intended
   region.

### D2 — E-ink push timing (mostly frontier)

**Reality check:** there is **no e-ink frame-push logic in the repo yet.** The
flutter-pi embedder integration, the partial/full-refresh driver, and the
"editor is active" refresh-policy signal are all unbuilt (see
[docs/design/markdown-editing.md](design/markdown-editing.md)
"E-ink open item"). So the literal test — "does the panel refresh on the
deliberate action and not on internal rebuilds?" — cannot be executed today; it
belongs in [Not yet testable](#not-yet-testable-the-frontier).

What you **can** test today, as the standing proxy for the panel's discrete
model, is that the app already avoids continuous-rendering assumptions:

1. **Reduce Motion = the e-ink code path.** Enable OS Reduce Motion on any
   platform. Confirm: the drawer opens/closes instantly (F3); the editor caret
   does not blink-fade (F9). These are the exact branches
   (`MediaQuery.disableAnimations`) the e-ink target will set.
2. **Discrete-only state changes.** Confirm the save-status chip, folder
   collapse, and selection highlight change only on discrete user actions —
   nothing animates or ticks on its own (the caret blink is the one known timer,
   documented as unavoidable).
3. When the embedder lands, this section gains real cases: page/file open →
   refresh; pen lift → refresh; idle rebuild → **no** refresh.

### D3 — RTL geometry (currently unreachable through the UI)

**Reality check:** only `en` and the `en_XA` **pseudo-locale** ship
(`lib/l10n/app_en.arb`, `app_en_XA.arb`). `en_XA` accents and pads text (LTR) —
it is **not** a bidi/RTL locale, and there is **no in-app locale switcher**. So
today the app never resolves to RTL and the sidebar-flip cannot be exercised
through normal use. This is a silently-untestable dimension worth surfacing.

- **To make it testable:** add a real RTL locale (e.g. Arabic, or the `ar_XB`
  RTL pseudo-locale) *or*, for a dev-only spot check, temporarily wrap the app
  `home` in `Directionality(textDirection: TextDirection.rtl, …)`.
- **When RTL is reachable, verify:** the master-detail sidebar moves to the
  **right** and the reader to the left; the divider drag direction and its
  ←/→ keyboard nudge still map intuitively; the full-panel **menu button and
  drawer** anchor to the **right** with the scrim/slide flipped; breadcrumbs and
  tree indentation mirror; nothing assumes a left-origin refresh region.

Until a locale lands, keep this in Not yet testable and re-open it the moment the
first RTL translation is added.

### D4 — Accessibility sweep

Per [.claude/rules/accessibility.md](../.claude/rules/accessibility.md), run
each on at least one platform per family (one Material, one Cupertino):

1. **Screen reader** (VoiceOver iOS/macOS, TalkBack Android, NVDA Windows):
   swipe through the browser. Every interactive element announces a role and
   label — file/folder rows (with expanded/selected), the divider slider (with
   width), the save chip (as a button when saveable), the menu/help/new
   actions, engram switcher, dialogs, and the folder picker. No unlabeled tap
   targets (the reader is deliberately non-selectable to avoid them).
2. **Text scaling:** max OS font scale → tree rows keep ≥ 48 px, names don't
   clip (horizontal scroll reaches them), the reader column reflows, the editor
   text scales.
3. **High contrast:** OS high-contrast → the high-contrast theme engages
   (F17.4).
4. **Reduce Motion:** as D2.1.
5. **Bold text:** OS bold-text → body and monospace editor text thicken.

### D5 — State-survival sweep

Confirm nothing that should persist is lost across a rebuild:

| State | How to disturb it | Must survive |
| --- | --- | --- |
| Active engram | Quit & relaunch | Same engram reopens (F1) |
| Divider width | Quit & relaunch | Same width (F2) |
| Folder collapse set | Quit & relaunch; switch engram & back | Per-engram (F4, F15) |
| File selection / breadcrumb | Rename/move the open file | Follows to new path (F12, F14) |
| Edit buffer | Edit↔Preview, divider drag, file switch | Never lost / never cross-written (F9, F10) |
| Reader scroll | Open & close help overlay | Unchanged (F16) |
| Fit/actual image mode | Switch to another image | Resets to fit (F7) |
| Device default theme | Set in Settings; quit & relaunch | Persists device-wide (F19) |
| Per-engram theme override | Set it; switch engram & back; move the folder | Travels with the engram, not the device (F19) |
| Window + sidebar width | Reset via Settings; quit & relaunch | Both return to default (F20) |

---

## Not yet testable (the frontier)

Designed and/or named in the vision but **not in `lib/` today**. Listed so the
gap between "shipped" and "roadmap" is explicit. Do **not** write pass/fail
cases for these until the code exists.

| Feature | Why it's not testable yet |
| --- | --- |
| **E-ink panel refresh (full/partial), page-turn/pen-lift push** | No flutter-pi embedder integration or refresh driver in the repo; the app only *respects* `disableAnimations`. See design doc "E-ink open item". Use the D2 proxy meanwhile. |
| **Live editing on e-ink** | The keystroke-per-frame vs panel-push tension is an explicitly-recorded open item owned by the embedder work, not solved. |
| **RTL / right-to-left** | No RTL locale bundled and no in-app locale switcher — the sidebar-flip can't be reached through the UI (D3). |
| **Handwriting / stylus annotation** | Core to the Supernote-style vision (CLAUDE.md) but no capture/ink surface exists. Requires touch/stylus hardware too. |
| **PDF viewer** | Falls through to the unsupported placeholder (F8); no PDF renderer wired into `buildFileViewer`'s seam. |
| **EPUB reader** | As PDF — unsupported placeholder only. |
| **Wikilinks `[[…]]` & backlinks** | Explicitly out of scope in the markdown-editing plan; only relative-path Markdown links resolve (F6). |
| **Graph view** | Obsidian-style graph is vision-level; no widget exists. |
| **Tagging** | No tag parsing, tag UI, or tag index in code. |
| **Search / full-text find** | No search field or index in the browser. |
| **Live Markdown preview (side-by-side) & syntax highlighting** | Out of scope in the current plan; Edit/Preview is a discrete toggle (F9), source is plain monospace. |
| **Design-language & locale pickers** | Settings now drives **theme** (F19), but there is still no UI for `AppSettings.designOverride` (Material vs Cupertino) or the app locale — both stay platform/OS-driven (F17). |
| **Sync / multi-device** | No sync layer; engrams are local folders. |
| **In-app "Open folder" on Pi/mobile** | The reusable folder picker (F14) is earmarked as the future in-app directory browser for flutter-pi; native-dialog adoption is desktop-only today. |

When any of these lands, move its row up into the matrix with concrete steps and
per-platform verdicts, and delete it from this table.
