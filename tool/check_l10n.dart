// The localization enforcement gate: fails when lib/ contains a hardcoded
// user-facing string, or when the generated pseudo-locale has drifted. Run by
// the pre-commit hook and in CI (.github/workflows/l10n.yml).
//
// It is written in Dart, not shell, so it runs identically on Windows, macOS,
// and Linux with no grep/bash dependency, and it parses the analyzer AST rather
// than matching text — so multi-line calls, adjacent-string concatenation, and
// interpolation are all handled. "What counts as a UI string" comes from the
// shared definition in package:brainframe_lints/text_slots.dart, which the
// Step 5 custom_lint rule reuses so the two layers never disagree.
//
// Escape hatch: a genuinely non-UI string literal in a flagged slot (e.g. a
// native window title) can be opted out with a `// l10n-ignore` comment on the
// same line.
//
// Run manually with: dart run tool/check_l10n.dart
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:brainframe_lints/text_slots.dart';

import 'gen_pseudo_arb.dart' as pseudo;

void main() {
  final findings = <_Finding>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll(r'\', '/');
    if (rel.startsWith('lib/l10n/')) continue; // ARBs + generated output
    final source = entity.readAsStringSync();
    if (source.contains('l10n-ignore-file')) continue;
    final parsed = parseString(content: source, throwIfDiagnostics: false);
    parsed.unit.accept(
      _RawStringVisitor(rel, source.split('\n'), findings),
    );
  }

  final pseudoStale = _pseudoLocaleIsStale();

  if (findings.isEmpty && !pseudoStale) {
    stdout.writeln(
      'check_l10n: OK — no hardcoded UI strings; pseudo-locale is fresh.',
    );
    return;
  }

  for (final f in findings) {
    stderr.writeln('${f.path}:${f.line}:${f.col}  hardcoded UI string');
    stderr.writeln('    ${f.snippet.trim()}');
  }
  if (pseudoStale) {
    stderr.writeln(
      'lib/l10n/app_en_XA.arb is stale — run: dart run tool/gen_pseudo_arb.dart',
    );
  }
  stderr
    ..writeln('')
    ..writeln(
      'Route user-facing text through AppLocalizations. If a flagged literal '
      'is genuinely not UI text, add "// ignore: no_raw_widget_strings" (or '
      '"// l10n-ignore") on its line.',
    );
  exit(1);
}

/// True when the checked-in pseudo-locale no longer matches what the generator
/// would produce from the current template.
bool _pseudoLocaleIsStale() {
  final template = File('lib/l10n/app_en.arb');
  final pseudoFile = File('lib/l10n/app_en_XA.arb');
  if (!template.existsSync() || !pseudoFile.existsSync()) return false;
  final expected = pseudo.buildPseudoArb(template.readAsStringSync());
  return pseudoFile.readAsStringSync() != expected;
}

class _Finding {
  _Finding(this.path, this.line, this.col, this.snippet);
  final String path;
  final int line;
  final int col;
  final String snippet;
}

class _RawStringVisitor extends RecursiveAstVisitor<void> {
  _RawStringVisitor(this.path, this.lines, this.findings);

  final String path;
  final List<String> lines;
  final List<_Finding> findings;

  @override
  void visitNamedExpression(NamedExpression node) {
    // A string in a named slot like label:/tooltip:/hintText: is user-facing.
    if (localizableSlotNames.contains(node.name.label.name)) {
      _check(node.expression);
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved parsing renders an unprefixed `Text(...)` as a method call.
    if (node.methodName.name == textWidgetName && node.realTarget == null) {
      _checkFirstPositional(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // `const`/`new Text(...)` parses as an instance creation instead.
    if (node.constructorName.type.toSource() == textWidgetName) {
      _checkFirstPositional(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  void _checkFirstPositional(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression) continue;
      _check(arg); // the first positional argument
      return;
    }
  }

  void _check(Expression expr) {
    if (expr is! StringLiteral || !_hasLetters(expr)) return;
    final lineNumber = _lineOf(expr.offset);
    final snippet = lines[lineNumber - 1];
    // Honor either marker: the custom_lint rule shares the same opt-out
    // (`// ignore: no_raw_widget_strings`), and `// l10n-ignore` opts out of the
    // gate alone.
    if (snippet.contains('l10n-ignore') ||
        snippet.contains('ignore: no_raw_widget_strings')) {
      return;
    }
    final column = expr.offset - _lineStartOffset(lineNumber) + 1;
    findings.add(_Finding(path, lineNumber, column, snippet));
  }

  bool _hasLetters(StringLiteral node) {
    if (node is SimpleStringLiteral) return isLocalizableText(node.value);
    if (node is AdjacentStrings) return node.strings.any(_hasLetters);
    if (node is StringInterpolation) {
      return node.elements
          .whereType<InterpolationString>()
          .any((e) => isLocalizableText(e.value));
    }
    return false;
  }

  int _lineOf(int offset) {
    var running = 0;
    for (var i = 0; i < lines.length; i++) {
      running += lines[i].length + 1; // +1 for the stripped newline
      if (offset < running) return i + 1;
    }
    return lines.length;
  }

  int _lineStartOffset(int lineNumber) {
    var offset = 0;
    for (var i = 0; i < lineNumber - 1; i++) {
      offset += lines[i].length + 1;
    }
    return offset;
  }
}
