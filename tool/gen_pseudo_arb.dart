// Generates lib/l10n/app_en_XA.arb — a pseudo-locale — from the template
// lib/l10n/app_en.arb. Pseudo-localization accents every letter, expands the
// text ~40%, and brackets it, so during development a glance reveals strings
// that are still hardcoded (they stay plain ASCII), truncated (the closing
// bracket vanishes), or too tight to fit a longer translation.
//
// It is generated, never hand-edited: the enforcement gate (tool/check_l10n.dart)
// fails if the checked-in app_en_XA.arb drifts from this generator's output, so
// the pseudo-locale is always in perfect key-sync with the template. Placeholders
// ({name}) and ICU keywords are left untouched so substitution still works.
//
// Run manually with: dart run tool/gen_pseudo_arb.dart
import 'dart:convert';
import 'dart:io';

/// Latin look-alikes for pseudo-localization. Letters with no entry (e.g. q, x)
/// pass through unchanged — full coverage is unnecessary for the visual signal.
const Map<String, String> _accents = {
  'a': 'á', 'b': 'ƀ', 'c': 'ç', 'd': 'đ', 'e': 'é', 'f': 'ƒ', 'g': 'ǵ',
  'h': 'ħ', 'i': 'í', 'j': 'ĵ', 'k': 'ķ', 'l': 'ł', 'm': 'ɱ', 'n': 'ñ',
  'o': 'ó', 'p': 'þ', 'r': 'ŕ', 's': 'š', 't': 'ŧ', 'u': 'ú', 'w': 'ŵ',
  'y': 'ý', 'z': 'ž',
  'A': 'Á', 'B': 'Ɓ', 'C': 'Ç', 'D': 'Đ', 'E': 'É', 'F': 'Ƒ', 'G': 'Ǵ',
  'H': 'Ħ', 'I': 'Í', 'J': 'Ĵ', 'K': 'Ķ', 'L': 'Ł', 'M': 'Ḿ', 'N': 'Ñ',
  'O': 'Ó', 'P': 'Þ', 'R': 'Ŕ', 'S': 'Š', 'T': 'Ŧ', 'U': 'Ú', 'W': 'Ŵ',
  'Y': 'Ý', 'Z': 'Ž',
};

/// Matches an ICU placeholder such as `{name}` — copied through verbatim.
final RegExp _placeholder = RegExp(r'\{[^}]*\}');

String _accent(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString();
}

/// Pseudo-localizes one message: accents letters (outside `{placeholders}`),
/// pads ~40% to expose overflow, and brackets the whole so truncation shows.
String pseudoLocalize(String message) {
  final buffer = StringBuffer('[');
  var index = 0;
  var visibleLetters = 0;
  for (final match in _placeholder.allMatches(message)) {
    final segment = message.substring(index, match.start);
    buffer.write(_accent(segment));
    visibleLetters += segment.replaceAll(RegExp(r'\s'), '').length;
    buffer.write(match.group(0)); // placeholder, untouched
    index = match.end;
  }
  final tail = message.substring(index);
  buffer.write(_accent(tail));
  visibleLetters += tail.replaceAll(RegExp(r'\s'), '').length;

  buffer.write('~' * ((visibleLetters * 0.4).round()));
  buffer.write(']');
  return buffer.toString();
}

/// Builds the pseudo-locale ARB JSON from the template ARB [templateJson].
/// Keeps `@@locale` (rewritten to `en_XA`) and every message, drops the
/// `@`-metadata (only the template carries descriptions/placeholders). The
/// output is deterministic so a freshness check can compare it byte-for-byte.
String buildPseudoArb(String templateJson) {
  final template = jsonDecode(templateJson) as Map<String, dynamic>;
  final out = <String, dynamic>{'@@locale': 'en_XA'};
  for (final entry in template.entries) {
    if (entry.key.startsWith('@')) continue; // @@locale + @-metadata
    out[entry.key] = pseudoLocalize(entry.value as String);
  }
  return '${const JsonEncoder.withIndent('  ').convert(out)}\n';
}

void main() {
  final template = File('lib/l10n/app_en.arb');
  if (!template.existsSync()) {
    stderr.writeln('gen_pseudo_arb: template not found at ${template.path}');
    exit(1);
  }
  final output = File('lib/l10n/app_en_XA.arb');
  output.writeAsStringSync(buildPseudoArb(template.readAsStringSync()));
  stdout.writeln('gen_pseudo_arb: wrote ${output.path}');
}
