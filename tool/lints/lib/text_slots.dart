/// The single, shared definition of which string literals count as hardcoded
/// user-facing text. Imported by the CLI gate (`tool/check_l10n.dart`) and the
/// `custom_lint` rule (`no_raw_widget_strings`), so the two enforcement layers
/// can never disagree about what counts.
library;

/// Named widget arguments that take user-facing text directly as a `String`
/// (not wrapped in a `Text`/`Widget`). A string literal passed to any of these
/// is a hardcoded UI string that skipped localization.
///
/// `title:` is deliberately absent: it is ambiguous (a widget in dialogs/app
/// bars, a plain `String` in data classes, the native window title in
/// `WindowOptions`), so a name-only heuristic false-positives on it. Widget
/// titles are written as `Text('…')` and caught by the [textWidgetName] rule.
const Set<String> localizableSlotNames = {
  'label', // Semantics
  'labelText', // InputDecoration
  'hintText', // InputDecoration
  'helpText', // InputDecoration, date/time pickers
  'semanticLabel', // Image, Icon, IconButton, ...
  'semanticsLabel', // Text, RichText (note the extra 's')
  'tooltip', // IconButton, Tooltip, ...
};

/// The `Text` widget: a string literal as its first positional argument is
/// user-facing text.
const String textWidgetName = 'Text';

/// Whether [value] is worth flagging: it contains a letter, so pure
/// punctuation, separators, or symbol-only strings (e.g. '•', ', ') don't trip
/// the check.
bool isLocalizableText(String value) => RegExp('[A-Za-z]').hasMatch(value);
