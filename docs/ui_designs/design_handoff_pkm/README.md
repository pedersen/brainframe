# Handoff: Reading Notes — Responsive PKM (Obsidian-style)

## Overview
A personal knowledge management (PKM) app inspired by Obsidian, built around **reading notes**. It centers on a **live-preview Markdown editor** with a file tree, wikilinks, tags, highlights, and checkboxes. The design is **fully reactive**: a single layout adapts across three breakpoints — desktop, tablet, and phone — with the sidebar collapsing to an off-canvas drawer on phones. Two themes (dark / light) and two layout variants (classic two-pane / three-column with a note list) are supported.

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes showing the intended look and behavior. They are **not production code to copy directly**. The `.dc.html` files use a custom in-house rendering runtime (`support.js`) with a template + logic-class convention; do **not** try to ship or port that runtime.

Your task is to **recreate these designs in the target codebase's existing environment** (React, Vue, Svelte, SwiftUI, etc.), using its established component patterns, styling approach, and libraries. If no codebase exists yet, choose an appropriate stack — React + a Markdown editor library (e.g. CodeMirror 6 or ProseMirror) is a natural fit for the live-preview editor.

Open the `.dc.html` files in a browser to see the design in motion, or read this README — it is self-sufficient.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing, and interaction details are specified below and should be recreated closely, adapted to the target design system where one exists.

---

## Screens / Views

The app is **one responsive layout** that reflows by container width. There is a demo/showcase wrapper (`Reading Notes PKM.dc.html`) that renders the app at all three breakpoints with Theme + Layout toggles — that wrapper is a **presentation harness only** and should not be reproduced in the product. Build the app itself (`ReadingNotesApp.dc.html`).

### Breakpoint rules (by available width of the app container)
- **Desktop:** width ≥ 1080px
- **Tablet:** 720px ≤ width < 1080px
- **Phone:** width < 720px

Measured on the app's own container (a `ResizeObserver` on the root element), not the window — so it works embedded in a pane. Recreate with a container query or equivalent.

### Regions

**1. Top bar** (height 44px desktop/tablet, 56px phone)
- Desktop/tablet: row of open "tabs" (rounded 8px chips with a small file icon + title; active tab uses `editorBg` fill + `borderSoft` border; inactive is muted, no fill). Right side: search icon button + overflow (`⋯`) button, each 30×30px, radius 7px.
- Phone: hamburger button (three 17px bars) on the left, centered note title (ellipsized), search icon on the right. Each touch target 34×34px.
- Bottom border: `1px solid borderSoft`.

**2. Left sidebar — file tree**
- Desktop width **258px**, tablet **212px**. Phone: off-canvas drawer, width **288px**, slides in with `translateX` transition (`.27s cubic-bezier(.4,0,.2,1)`), over a scrim (`scrim` color, fades `.27s`). Opened via hamburger; tap scrim to close.
- Header row: "READING VAULT" label (11.5px, weight 700, uppercase, letter-spacing 0.07em, `muted`) + a "new note" plus-icon button (24×24, radius 6px).
- Search field: 30px tall, radius 7px, `appBg` fill, `borderSoft` border, search icon + "Search notes…" placeholder (`faint`), 12.5px.
- Tree rows: 13px, single line (`white-space:nowrap`, x-overflow hidden). Disclosure triangles `▾`/`▸` (9px, `faint`) in a 12px-wide slot. Indentation via left padding: top-level 8px, nested 22px, leaf files 38px. File rows have a small 12px doc icon.
  - Selected file row: `selBg` background + **inset 2px accent left-border** (`box-shadow: inset 2px 0 0 accent`), accent-colored icon.
  - Hover: `hover` background.
- Sample tree content (use verbatim for fidelity):
  - **Reading Notes** (open)
    - **Books** (open) → *The Beginning of Infinity* (selected), *Thinking, Fast and Slow*, *Same as Ever*, *Annihilation*
    - Articles (collapsed)
    - Map of Content
    - Reading Log 2026
  - Daily Notes (collapsed)
  - Templates (collapsed)

**3. Note list column** (only in **Columns** layout variant, and only on desktop)
- Width **300px**, `listBg` background, right border `borderSoft`.
- Header: "Books" (13.5px, weight 700) + "6 notes" (12px `faint`) + "Recent ▾" (11.5px `muted`) pushed right.
- List items: title (13.5px, weight 600, ellipsized) + date (11px `faint`) on one baseline row; a 2-line snippet (12.5px `muted`, line-height 1.45); optional tag row (`mono`, 10.5px, `tagText`). Each item has bottom border `borderSoft`, 11px/16px padding. Selected item: `selBg` + inset 2px accent left-border. Hover: `hover`.
- Sample items: *The Beginning of Infinity* (Apr 12, selected, tags `#epistemology` `#physics`), *Thinking, Fast and Slow* (Mar 30), *Same as Ever* (Mar 18), *Annihilation* (Feb 27) — with the snippet copy in the HTML.

**4. Editor / note pane** (main, flex:1, `editorBg` background)
- Scrollable content, centered column **max-width 744px**.
- Padding: phone `22px 20px 96px`, tablet `32px 40px 96px`, desktop `46px 64px 120px`.
- Note body uses the **serif** font (Newsreader). Content, in order:
  - **File path breadcrumb** (mono, 12px, `faint`): `books / the-beginning-of-infinity.md`
  - **H1 title** (serif, weight 600, 31px desktop / 26px phone, line-height 1.12, letter-spacing −0.012em): "The Beginning of Infinity"
  - **Meta row** (14px, `muted`, single line): "David Deutsch" · ★★★★☆ (star rating in `accentText`) · a "Finished" pill (`pillBg` bg, `tagText`, radius 20px).
  - **Tag row**: pills `#reading` `#epistemology` `#physics` `#explanation` — mono 12px, `tagBg` bg, `tagText`, radius 20px, gap 7px.
  - **Blockquote / highlight callout**: `highlight` bg, `3px solid highlightBorder` left border, radius `0 9px 9px 0`, italic, 18px (16.5 phone), with an attribution line in sans 12.5px `muted`. Text: "The growth of knowledge consists of correcting misconceptions in our theories. — Ch. 1, The Reach of Explanations".
  - **H2 headings** (serif, weight 600, 20px / 18px phone) each prefixed with a faint mono `## ` glyph at 0.74em to evoke live Markdown source. Sections: "Core thesis", "Highlights", "Open questions", "Connections".
  - **Body paragraphs**: 16.5px (15.5 phone), line-height 1.78, `text`. Include `<strong>` (weight 600), `<em>`, and **wikilinks** styled as `accent` color with a 1px `accentUnderline` bottom border (e.g. "Explanatory knowledge").
  - **Bulleted list** under Highlights, with an inline `highlight`-background mark on the word "inevitable".
  - **Checkbox list** under Open questions: a checked item (18px, radius 5px, `accent` fill, white check SVG) and unchecked items (18px, radius 5px, `1.6px solid faint` border). Each references a wikilink (Fallibilism, Popper, Map of Content).
  - **"Active line" treatment** under Connections: a block with `selBg` bg + 2px accent left border showing **raw Markdown tokens** — faint mono `**`, `[[`, `]]` around an accent-colored link label — ending with a **blinking caret** (2px × 1.05em `accent` bar, `pkmCaret` keyframe: 1.05s steps(1) infinite). This conveys the live-preview "source shows on the focused line" behavior.

**5. Status bar** (desktop/tablet only, height 27px, hidden on phone)
- `appBg` bg, top border `borderSoft`, `faint` text, 11.5px.
- Left: breadcrumb (mono) "Reading Notes › Books › The Beginning of Infinity". Right cluster: "Live preview", "1,204 words", "4 backlinks", and a "Synced" indicator (7px accent dot + label).

---

## Interactions & Behavior
- **Responsive reflow:** container-width-driven (ResizeObserver on the app root), thresholds 1080 / 720. On leaving phone, the drawer force-closes.
- **Sidebar drawer (phone):** hamburger toggles `sidebarOpen`; transform slide-in `.27s cubic-bezier(.4,0,.2,1)`; scrim fades `.27s`; scrim click closes.
- **Theme switch:** dark ↔ light; root transitions `background .22s ease, color .22s ease`.
- **Hover states:** tree rows, list items, tab chips, icon buttons all use the `hover` token as background on hover.
- **Wikilinks / tags / checkboxes** are visually styled and, in the product, should be interactive: wikilinks navigate to the linked note, tags filter, checkboxes toggle. (In the prototype they are static.)
- **Caret animation:** `@keyframes pkmCaret { 0%,48%{opacity:1} 49%,100%{opacity:0} }`.

## State Management
Minimal for the prototype; for the product you will need:
- `theme`: `'dark' | 'light'` (persist to localStorage / system preference).
- `layoutVariant`: `'classic' | 'columns'`.
- `device`/breakpoint: derived from container width (do not store user-set; compute).
- `sidebarOpen`: boolean, phone drawer.
- `activeNoteId`, `openTabs[]`, `expandedFolders{}`, `selectedFolderId` (for the note-list column).
- Note content model: markdown source + parsed AST for live preview; frontmatter (author, rating, status, tags); backlinks index.
- Data: a vault of notes (files + folders). Prototype data is hard-coded; real app reads from a store / filesystem / API.

## Design Tokens

### Colors — Dark theme
- appBg `#1b1b1f` · sidebarBg `#161619` · editorBg `#1e1e22` · listBg `#19191d`
- borderSoft `#26262c` · border `#2e2e35`
- text `#d8d8dc` · muted `#8b8b93` · faint `#5c5c64`
- accent `#a394f0` · accentText `#b7abf5` · accentUnderline `rgba(163,148,240,0.4)`
- selBg `rgba(163,148,240,0.16)` · hover `rgba(255,255,255,0.05)`
- tagBg `rgba(163,148,240,0.13)` · tagText `#b8aef5` · pillBg `rgba(163,148,240,0.16)`
- highlight `rgba(238,206,110,0.18)` · highlightBorder `rgba(238,206,110,0.55)`
- scrim `rgba(0,0,0,0.5)` · shadow `0 10px 38px rgba(0,0,0,0.5)`

### Colors — Light theme
- appBg `#f7f6f3` · sidebarBg `#efeee9` · editorBg `#ffffff` · listBg `#f3f2ed`
- borderSoft `#e8e6df` · border `#dddbd3`
- text `#37373c` · muted `#79797f` · faint `#a9a8a2`
- accent `#6a59cf` · accentText `#5b4bbf` · accentUnderline `rgba(106,89,207,0.35)`
- selBg `rgba(106,89,207,0.10)` · hover `rgba(0,0,0,0.04)`
- tagBg `rgba(106,89,207,0.10)` · tagText `#5b4bbf` · pillBg `rgba(106,89,207,0.12)`
- highlight `rgba(245,206,90,0.42)` · highlightBorder `rgba(214,160,30,0.55)`
- scrim `rgba(22,22,28,0.34)` · shadow `0 12px 40px rgba(60,55,90,0.2)`

### Typography
- **UI / chrome:** system sans — `-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif`
- **Note body:** serif — `"Newsreader", Georgia, "Times New Roman", serif`
- **Code / Markdown tokens / breadcrumbs / tags:** mono — `"JetBrains Mono", ui-monospace, "SFMono-Regular", monospace`
- Scale: H1 31/26px · H2 20/18px · body 16.5/15.5px · quote 18/16.5px · UI 11.5–14px (desktop/phone where two values given).
- Body line-height 1.78; lists 1.7; quote 1.55.

### Spacing / radius / dimensions
- Sidebar 258 (desktop) / 212 (tablet) / 288 (phone drawer) px. Note list 300px. Note column max-width 744px.
- Top bar 44px (desktop/tablet), 56px (phone). Status bar 27px.
- Radius: chips/buttons 7–8px, tree rows 6px, pills 20px, tag pills 20px, callout `0 9px 9px 0`, checkboxes 5px.
- Touch targets on phone ≥ 34px.

### Shadows
- Drawer: theme `shadow` token (see above).

## Assets
- **Fonts** from Google Fonts: Newsreader (opsz 6–72, weights 400/500/600, italics) and JetBrains Mono (400/500). Load equivalents in the target app.
- **Icons** are inline SVG (search, doc, plus, hamburger, checkmark) — replace with the codebase's icon library.
- No raster images. Star rating is a text glyph (★/☆).

## Screenshots
Reference renders in `screenshots/`:
- `01-desktop-dark.png` — desktop, dark theme, classic two-pane (file tree + editor). The primary reference.
- `02-tablet-phone-dark.png` — tablet breakpoint (narrower sidebar), dark.
- `03-desktop-light-columns.png` — desktop, **light theme**, **Columns** variant (three panes: tree + note list + editor).
- `04-phone-dark.png` — phone breakpoint: top bar collapses to hamburger + centered title + search; sidebar is hidden.
- `05-phone-drawer.png` — phone with the file-tree **drawer open** over a scrim (hamburger tapped).

Note: desktop/tablet shots are captured at the browser viewport, so the right edge of the very wide desktop frame may be clipped in the image — the token tables and per-region specs above are authoritative for exact values.

## Files
- `ReadingNotesApp.dc.html` — **the app**. This is the design to recreate. Props: `theme` (dark/light), `variation` (classic/columns), `device` (override; normally auto from width).
- `Reading Notes PKM.dc.html` — presentation harness (renders the app at 3 breakpoints with toggles). Reference only; do not reproduce.
- `support.js` — the prototype's rendering runtime. **Do not port.** Present only so the HTML opens in a browser.
