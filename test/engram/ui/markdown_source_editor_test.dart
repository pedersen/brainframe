import 'package:brainframe/engram/ui/markdown_source_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

Widget _host(Widget child) =>
    localizedApp(home: Scaffold(body: SizedBox(height: 400, child: child)));

void main() {
  testWidgets('shows the initial text', (tester) async {
    await tester
        .pumpWidget(_host(const MarkdownSourceEditor(initialText: '# Hello')));
    expect(find.text('# Hello'), findsOneWidget);
  });

  testWidgets('propagates edits through onChanged', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(_host(
      MarkdownSourceEditor(initialText: '', onChanged: changes.add),
    ));

    await tester.enterText(find.byType(TextField), '# Edited');

    expect(changes, ['# Edited']);
  });

  testWidgets('exposes an explicit, localized Markdown-editor label',
      (tester) async {
    await tester.pumpWidget(_host(const MarkdownSourceEditor(initialText: '')));

    // The label is sourced from AppLocalizations (English here), never a raw
    // string literal.
    expect(find.bySemanticsLabel('Markdown editor'), findsOneWidget);
  });

  testWidgets('adopts new initialText when a different file loads',
      (tester) async {
    await tester.pumpWidget(_host(
      const MarkdownSourceEditor(initialText: 'first', key: ValueKey('slot')),
    ));
    expect(find.text('first'), findsOneWidget);

    // Same widget slot (same key) — exercises didUpdateWidget, not a rebuild.
    await tester.pumpWidget(_host(
      const MarkdownSourceEditor(initialText: 'second', key: ValueKey('slot')),
    ));

    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('keeps an in-progress edit that already matches the new text',
      (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(_host(
      MarkdownSourceEditor(
        initialText: 'start',
        onChanged: changes.add,
        key: const ValueKey('slot'),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'typed');

    // A rebuild whose initialText matches the buffer must not reset the caret
    // or content.
    await tester.pumpWidget(_host(
      MarkdownSourceEditor(
        initialText: 'typed',
        onChanged: changes.add,
        key: const ValueKey('slot'),
      ),
    ));

    expect(find.text('typed'), findsOneWidget);
  });

  testWidgets('disables the animated cursor under Reduce Motion',
      (tester) async {
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const Scaffold(
            body: SizedBox(
              height: 400,
              child: MarkdownSourceEditor(initialText: ''),
            ),
          ),
        ),
      ),
    ));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorOpacityAnimates, isFalse);
  });

  testWidgets('animates the cursor when Reduce Motion is off', (tester) async {
    await tester.pumpWidget(_host(const MarkdownSourceEditor(initialText: '')));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorOpacityAnimates, isTrue);
  });
}
