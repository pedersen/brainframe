#!/usr/bin/env bash
#
# appshot.sh — launch, drive, and screenshot the BrainFrame Linux desktop app
# for visual verification, all behind one allowlistable command.
#
# Why this exists: on this GNOME/Wayland box, capturing and controlling the app
# needs it running under X11 (XWayland) so maim + xdotool can see it. Doing that
# by hand is a dozen separate shell commands (and a dozen permission prompts).
# This wraps them so a single `Bash(.../tool/appshot.sh *)` allow rule covers the
# whole workflow.
#
# Linux only (GNOME/Wayland + XWayland, or plain X11). Run from the repo root as
# `tool/appshot.sh …`, or by absolute path from anywhere. Requires `maim`,
# `xdotool`, and a running graphical session (`$DISPLAY`).
#
# Usage:
#   tool/appshot.sh launch [PROJECT_DIR]   # flutter run -d linux (X11) from DIR
#                                          #   (default: cwd); waits for the window
#   tool/appshot.sh shot [OUT]             # capture the app window (default OUT below)
#   tool/appshot.sh run PROJECT_DIR [OUT]  # launch (if needed) + shot
#   tool/appshot.sh hover X Y [OUT]        # move mouse to window px (X,Y), settle, shot
#   tool/appshot.sh click X Y [OUT]        # move to (X,Y), left-click, settle, shot
#   tool/appshot.sh key NAME [OUT]         # send a key (e.g. Escape), settle, shot
#   tool/appshot.sh status                 # print "running=<n> window=<n>"
#   tool/appshot.sh quit                   # terminate the app (loops until gone)
#
# Each capturing command prints the PNG path on stdout. Window pixels map 1:1 to
# the coordinates you pass (the app window sits at the screen origin).
#
# Safety note: the app opens whatever engram it last had — treat it as real data.
# This script only takes screenshots and moves/clicks the pointer; it never
# touches files. When driving, stick to hover / select / Escape — don't click
# destructive UI (rename/delete/create) against a real engram.

set -uo pipefail
export DISPLAY="${DISPLAY:-:0}"

readonly APP_TITLE='BrainFrame'   # the real window; helpers are "tech.brainframe.app" (10x10)
readonly APP_BUNDLE='build/linux/x64/debug/bundle/brainframe'
readonly PIDFILE='/tmp/brainframe-appshot.pid'
readonly RUNLOG='/tmp/brainframe-appshot-run.log'
readonly DEFAULT_OUT='/tmp/brainframe-shot.png'

log() { printf 'appshot: %s\n' "$*" >&2; }

find_window() { xdotool search --name "^${APP_TITLE}\$" 2>/dev/null | head -1; }
app_running() { pgrep -f "$APP_BUNDLE" >/dev/null 2>&1; }

launch() {
  local proj="${1:-$PWD}"
  if app_running; then log "already running"; find_window; return 0; fi
  [ -d "$proj" ] || { log "no such project dir: $proj"; return 1; }
  log "launching from $proj (GDK_BACKEND=x11 flutter run -d linux)…"
  ( cd "$proj" && GDK_BACKEND=x11 nohup flutter run -d linux >"$RUNLOG" 2>&1 &
    echo $! >"$PIDFILE" )
  local wid=''
  for _ in $(seq 1 120); do          # up to ~4 min for a cold build
    wid=$(find_window); [ -n "$wid" ] && break
    if grep -qE 'error:|Exception|Build failed|Failed to build|Oops' "$RUNLOG" 2>/dev/null; then
      log "build error — tail of $RUNLOG:"; tail -n 12 "$RUNLOG" >&2; return 1
    fi
    sleep 2
  done
  [ -n "$wid" ] || { log "window never appeared; see $RUNLOG"; return 1; }
  sleep 2                            # let first frame render
  log "window up ($wid)"
  echo "$wid"
}

capture() {
  local out="${1:-$DEFAULT_OUT}" wid
  wid=$(find_window)
  [ -n "$wid" ] || { log "no ${APP_TITLE} window — launch first"; return 1; }
  xdotool windowactivate "$wid" 2>/dev/null; xdotool windowraise "$wid" 2>/dev/null
  sleep 0.5
  if maim -i "$wid" "$out" 2>/tmp/appshot-maim.err; then
    echo "$out"; return 0
  fi
  # Fallback: some windows reject direct capture (RENDER BadMatch); grab the
  # screen region the window occupies instead.
  local X Y WIDTH HEIGHT WINDOW SCREEN
  eval "$(xdotool getwindowgeometry --shell "$wid")"
  if maim -g "${WIDTH}x${HEIGHT}+${X}+${Y}" "$out" 2>>/tmp/appshot-maim.err; then
    echo "$out"; return 0
  fi
  log "capture failed:"; cat /tmp/appshot-maim.err >&2; return 1
}

# Translate window-relative (x,y) to absolute screen coords (window origin + x,y).
to_screen() {
  local wid X Y WIDTH HEIGHT WINDOW SCREEN
  wid=$(find_window) || return 1
  eval "$(xdotool getwindowgeometry --shell "$wid")"
  printf '%s %s' "$((X + $1))" "$((Y + $2))"
}

# Terminate the app and its `flutter run` supervisor, escalating to SIGKILL, and
# loop until nothing is left — so no ad-hoc cleanup (bare pkill/pgrep) is ever
# needed outside this allowlisted script.
quit_app() {
  [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if [ "$attempt" -ge 3 ]; then
      pkill -9 -f 'flutter_tools.snapshot run -d linux' 2>/dev/null
      pkill -9 -f "$APP_BUNDLE" 2>/dev/null
    else
      pkill -f 'flutter_tools.snapshot run -d linux' 2>/dev/null
      pkill -f "$APP_BUNDLE" 2>/dev/null
    fi
    sleep 0.6
    pgrep -f "$APP_BUNDLE" >/dev/null 2>&1 || { log "quit (clean)"; return 0; }
  done
  log "warning: app still running after quit"
  return 1
}

require() { [ -n "${1:-}" ] || { log "missing argument"; exit 64; }; }

cmd="${1:-}"; shift || true
case "$cmd" in
  launch) launch "${1:-}" ;;
  shot)   capture "${1:-}" ;;
  run)    require "${1:-}"; launch "$1" >/dev/null || exit 1; capture "${2:-}" ;;
  hover)  require "${1:-}"; require "${2:-}"
          read -r sx sy < <(to_screen "$1" "$2")
          xdotool mousemove "$sx" "$sy"; sleep 1; capture "${3:-}" ;;
  click)  require "${1:-}"; require "${2:-}"
          read -r sx sy < <(to_screen "$1" "$2")
          xdotool mousemove "$sx" "$sy"; sleep 0.3; xdotool click 1; sleep 1
          capture "${3:-}" ;;
  key)    require "${1:-}"; xdotool key "$1"; sleep 0.6; capture "${2:-}" ;;
  quit)   quit_app ;;
  status) running=$(pgrep -cf "$APP_BUNDLE" 2>/dev/null || true)
          window=$(find_window | grep -c . || true)
          echo "running=${running:-0} window=${window:-0}" ;;
  *) log "usage: appshot.sh {launch [DIR]|shot [OUT]|run DIR [OUT]|hover X Y [OUT]|click X Y [OUT]|key NAME [OUT]|status|quit}"
     exit 64 ;;
esac
