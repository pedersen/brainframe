import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/ui/help_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

void main() {
  // A button that opens the help overlay over the bundled help engram.
  Widget host() => localizedApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHelpOverlay(context, builtInHelpEngram()),
              child: const Text('open help'),
            ),
          ),
        ),
      );

  testWidgets('opens showing the help header and index content',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open help'));
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsOneWidget); // header
    expect(find.text('index.md'), findsOneWidget); // reader breadcrumb
    expect(
      find.textContaining('BrainFrame help', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('closes without leaving anything behind', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open help'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close help'));
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsNothing);
    expect(find.text('open help'), findsOneWidget); // back to the host
  });
}
