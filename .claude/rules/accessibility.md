# Accessibility Requirements

BrainFrame targets real users, including those with visual impairments.
Accessibility is not a post-launch concern — it is built in from the first
widget.

## Rules for every custom widget

- Wrap interactive custom-painted widgets in `Semantics(...)` explicitly.
  Never assume Flutter infers role, label, or state from visual appearance
  alone.
- Buttons, toggles, and tappable areas must have `label:`, `button: true`
  (or the appropriate role), and `enabled:` state.
- Custom text rendering (e.g. e-ink optimized) must still expose its content
  via `Semantics(label: ...)` or `excludeSemantics: false`.

## Platform accessibility signals to detect and respect

- `MediaQuery.of(context).textScaler` — never hard-clamp font sizes; let text
  scale.
- `MediaQuery.of(context).highContrast` — the e-ink theme should already be
  high contrast, but other themes must adapt.
- `MediaQuery.of(context).disableAnimations` — respect Reduce Motion; no
  mandatory animations anywhere.
- `MediaQuery.of(context).boldText` — respect the system bold-text preference.

## Screen reader targets

- VoiceOver (macOS, iOS), TalkBack (Android), and NVDA/JAWS (Windows) must all
  be considered when adding Semantics annotations.
- Use `flutter test --accessibility` and the Flutter Accessibility Inspector
  during development, not only before release.

## E-ink platform note

- The e-ink display has no screen reader attached. Semantics annotations for
  the e-ink build target the companion mobile/desktop interfaces, not the
  e-ink panel itself.

## Conventions

- Every new widget must include Semantics coverage for all interactive
  elements before it is considered complete.
