# Visual Verification (Linux desktop)

Automated tests prove behavior, but some things only a running window reveals —
layout, overflow, hover/splash bleed, alignment, theme. On Linux, `tool/appshot.sh`
launches the real desktop app, drives it, and captures screenshots, so a change
can be *seen* and not just asserted.

This is developer tooling, not part of the app. It is Linux-only today; a macOS
or Windows equivalent would be a welcome addition, and this script is expected
to grow as more contributors lean on it.

## Why a script (and not raw commands)

This box runs **GNOME on Wayland (Mutter)** with XWayland alongside. Capturing
and controlling a window there has sharp edges:

- `grim` (the usual Wayland tool) is wlroots-only — it does **not** work on
  Mutter.
- Plain X11 tools (`maim`, `xdotool`) only see **XWayland** clients, so the app
  must be launched with `GDK_BACKEND=x11 flutter run -d linux`.
- The Flutter app exposes three X windows — two 10×10 helpers and the real one
  titled **`BrainFrame`**. `maim -i` on a helper fails with a RENDER
  `BadMatch`; you must pick the titled window.
- The debug build's windows carry a distinct `WM_CLASS` of
  `tech.brainframe.app.debug` (the release/profile ID is `tech.brainframe.app`;
  the `.debug` suffix is added in `linux/CMakeLists.txt`). The script selects on
  **that class *and* the `BrainFrame` title**, so it drives only the debug
  build. You can leave a release/profile build running all the time —
  dogfooding on your real notes — and the tool will never capture, click,
  resize, or quit it. (`quit` is likewise scoped: it only kills the debug
  bundle path and the `flutter run` supervisor, not a dogfood instance.)

The script encodes all of that so nobody re-derives it, and so the whole
launch → drive → capture → quit flow sits behind a **single command** you can
allowlist once (see Permissions).

## Requirements

- A running graphical session (`$DISPLAY` set).
- `maim` and `xdotool`: `sudo apt install maim xdotool`.
- The Flutter Linux desktop toolchain (already needed to build the app).

## Usage

Run from the repo root (or by absolute path from anywhere):

```bash
tool/appshot.sh run <project-dir> [OUT]  # launch (X11) + capture
tool/appshot.sh shot [OUT]               # capture the running app
tool/appshot.sh hover X Y [OUT]          # pointer to window px, then capture
tool/appshot.sh click X Y [OUT]          # move, left-click, then capture
tool/appshot.sh key NAME [OUT]           # send a key (e.g. Escape), capture
tool/appshot.sh status                   # print "running=<n> window=<n>"
tool/appshot.sh quit                     # terminate the app (loops until gone)
```

- Capturing subcommands print the PNG path on stdout.
- Window pixels map 1:1 to the coordinates you pass (the window sits at the
  screen origin).
- Give the app a few seconds after `launch` before capturing, or you will grab a
  loading spinner.
- Do launch / drive / verify / quit **only** through these subcommands — never a
  bare `pkill` / `pgrep` / `xdotool` — so nothing escapes the one allow rule.

## Permissions

So the tool runs without a prompt per invocation, allowlist it in your
**personal, git-ignored** `.claude/settings.local.json` (not the shared
`settings.json`):

```json
{ "permissions": { "allow": ["Bash(tool/appshot.sh *)"] } }
```

That single rule covers every subcommand, including the self-cleaning `quit`.

## Safety

The app opens whatever engram it last used — on a developer's machine that is
**real notes**. The script only screenshots and moves/clicks the pointer; it
never touches files. When driving, keep to non-destructive gestures — hover,
select, `Escape`. Do not click rename / delete / create against a real engram.
A dedicated throwaway testing engram is the right home for destructive-flow
verification; until one exists, drive read-only.
