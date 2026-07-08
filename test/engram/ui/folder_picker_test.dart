import 'package:brainframe/engram/ui/folder_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

void main() {
  // AlertDialog.adaptive renders Cupertino on Apple platforms; force Material so
  // the ListTiles and TextButtons under test are plain Material widgets.
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  late String? result;
  late bool resolved;

  Future<void> openPicker(
    WidgetTester tester, {
    required List<String> folders,
    bool includeRoot = true,
  }) async {
    result = null;
    resolved = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showFolderPicker(
                context,
                folders: folders,
                includeRoot: includeRoot,
              );
              resolved = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    debugDefaultTargetPlatformOverride = null; // theme already baked Material
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // dialog transition
  }

  testWidgets('lists the folders and root; Move is disabled until a selection',
      (tester) async {
    await openPicker(tester, folders: ['archive', 'notes', 'notes/sub']);

    expect(find.text('Top level'), findsOneWidget);
    expect(find.text('archive'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('sub'), findsOneWidget); // shown by last segment

    final move = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Move'),
    );
    expect(move.onPressed, isNull); // nothing selected yet
  });

  testWidgets('returns the selected folder path', (tester) async {
    await openPicker(tester, folders: ['archive', 'notes']);

    await tester.tap(find.text('archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Move'));
    await tester.pumpAndSettle();

    expect(resolved, isTrue);
    expect(result, 'archive');
  });

  testWidgets('root selection returns the empty string', (tester) async {
    await openPicker(tester, folders: ['notes']);

    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Move'));
    await tester.pumpAndSettle();

    expect(result, '');
  });

  testWidgets('cancel returns null', (tester) async {
    await openPicker(tester, folders: ['notes']);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(resolved, isTrue);
    expect(result, isNull);
  });

  testWidgets('omits the root entry when includeRoot is false', (tester) async {
    await openPicker(tester, folders: ['notes'], includeRoot: false);

    expect(find.text('Top level'), findsNothing);
    expect(find.text('notes'), findsOneWidget);
  });

  testWidgets('shows an empty message when there is nowhere to move',
      (tester) async {
    await openPicker(tester, folders: const [], includeRoot: false);

    expect(find.text('No other folder to move to.'), findsOneWidget);
  });
}
