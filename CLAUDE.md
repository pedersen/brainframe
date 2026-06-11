# BrainFrame

## Project Overview

BrainFrame is an open-source, cross-platform Second Brain / E-Reader app
combining:

- **Obsidian-style knowledge management** — markdown notes, graph view,
  backlinks, tagging
- **Supernote-style document reading & annotation** — PDF, EPUB,
  handwriting markup

## Platforms

| Platform | Notes |
| --- | --- |
| Windows, Mac, Linux | Standard Flutter desktop targets |
| Android, iOS | Standard Flutter mobile targets |
| Raspberry Pi + e-ink | via flutter-pi embedder, Waveshare displays |

## Tech Stack

- **Language:** Dart
- **Framework:** Flutter
- **Pi embedder:** flutter-pi (runs on Pi 4/5, no X11 or desktop environment
  needed)
- **Version control:** GitHub (github.com/pedersen/brainframe)

## E-Ink Architecture

Flutter renders normally at full speed. Frames are only pushed to the e-ink
panel on deliberate user actions (page turn, pen lift). This is a hardware
constraint, not a Flutter limitation — the same model used by Supernote and
reMarkable.

- Full refresh: ~2–4 seconds
- Partial refresh: ~0.3 seconds

UI interactions on e-ink must be designed around this — avoid animations,
hover states, or anything assuming continuous rendering.

## Project Context

- Open-source, solo-maintained; community contributions welcome.
- **A core goal is for every line in the repo to be written by Claude** — a
  deliberate experiment in AI-authored software. Human input is mainly
  direction, review, and decisions rather than hand-written code, with Claude
  Code as the primary development tool.
- Learning to collaborate well with Claude is itself a goal here; picking up
  Flutter and Dart happens along the way but isn't the main focus.
