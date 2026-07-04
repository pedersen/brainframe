/// The BrainFrame custom_lint plugin. Its one rule, `no_raw_widget_strings`,
/// is the edit-time half of localization enforcement (design Decision 3): it
/// surfaces a hardcoded user-facing string as an IDE warning the moment it is
/// typed. The commit/CI half is the standalone gate `tool/check_l10n.dart`;
/// both decide "what counts" from the shared [text_slots] definition, so they
/// can never disagree.
///
/// custom_lint discovers this via the plugin's dependency on
/// `custom_lint_builder` plus `analyzer: plugins: [custom_lint]` in the host's
/// analysis_options.yaml. Opt a genuine non-UI literal out with
/// `// ignore: no_raw_widget_strings` (honored by the gate too).
library;

// custom_lint_builder 0.8.1's API (run()'s ErrorReporter, LintCode's
// errorSeverity/ErrorSeverity) predates analyzer 8.4's rename to
// Diagnostic{Reporter,Severity}. We must use the older types to match the
// framework's signatures, so the transitional deprecation is expected here.
// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
// Only ErrorSeverity: this library's LintCode/ErrorReporter come from
// custom_lint_builder, and analyzer also exports a (different) LintCode.
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'text_slots.dart';

PluginBase createPlugin() => _BrainframeLints();

class _BrainframeLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      [const NoRawWidgetStrings()];
}

/// Flags a string literal used as user-facing widget text — the first
/// positional argument of a `Text(...)`, or a named slot such as
/// `label:`/`tooltip:`/`hintText:` (see [localizableSlotNames]).
class NoRawWidgetStrings extends DartLintRule {
  const NoRawWidgetStrings() : super(code: _code);

  static const _code = LintCode(
    name: 'no_raw_widget_strings',
    problemMessage:
        'Hardcoded user-facing string. Route it through AppLocalizations '
        '(add a key to lib/l10n/app_en.arb).',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Scope to the app's own lib/ — the same surface the CLI gate scans. Tests
    // and tooling legitimately hardcode strings, and generated l10n is derived.
    final path = resolver.path.replaceAll(r'\', '/');
    if (!path.contains('/lib/') ||
        path.contains('/test/') ||
        path.contains('/lib/l10n/')) {
      return;
    }

    context.registry.addNamedExpression((node) {
      if (localizableSlotNames.contains(node.name.label.name)) {
        _report(node.expression, reporter);
      }
    });
    // With resolution, `Text('x')` is an instance creation; the method-call
    // form is kept for parity with the unresolved gate.
    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.toSource() == textWidgetName) {
        _reportFirstPositional(node.argumentList, reporter);
      }
    });
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name == textWidgetName && node.realTarget == null) {
        _reportFirstPositional(node.argumentList, reporter);
      }
    });
  }

  void _reportFirstPositional(ArgumentList args, ErrorReporter reporter) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression) continue;
      _report(arg, reporter);
      return;
    }
  }

  void _report(Expression expr, ErrorReporter reporter) {
    if (expr is StringLiteral && _hasLetters(expr)) {
      reporter.atNode(expr, _code);
    }
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
}
