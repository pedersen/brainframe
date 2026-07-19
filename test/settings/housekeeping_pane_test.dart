import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/settings/housekeeping_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

RegisteredEngram _engram(
  String id, {
  String name = 'Field Notebook',
  String path = '/home/user/notes',
  bool available = true,
}) =>
    RegisteredEngram(
      id: id,
      displayName: name,
      path: path,
      available: available,
    );

void main() {
  /// A fake repository surface: [load] serves the current list; [forget] records
  /// the id and drops it, so a reload reflects the change — no filesystem.
  late List<RegisteredEngram> engrams;
  late List<String> forgotten;

  Future<List<RegisteredEngram>> load() async => List.of(engrams);
  Future<void> forget(String id) async {
    forgotten.add(id);
    engrams.removeWhere((e) => e.id == id);
  }

  setUp(() {
    engrams = [];
    forgotten = [];
  });

  Widget host() => localizedApp(
        home: Scaffold(body: HousekeepingPane(load: load, forget: forget)),
      );

  testWidgets('lists an engram with its path and a Forget button',
      (tester) async {
    engrams = [_engram('a', name: 'Field Notebook', path: '/home/user/notes')];

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Field Notebook'), findsOneWidget);
    expect(find.text('/home/user/notes'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Forget'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is registered',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing to forget'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Forget'), findsNothing);
  });

  testWidgets('a dangling entry (missing folder) is badged Missing',
      (tester) async {
    engrams = [_engram('a', available: false)];

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget); // badge, uppercased
  });

  testWidgets('confirming Forget calls forget and drops it from the list',
      (tester) async {
    engrams = [_engram('a', name: 'Field Notebook')];

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Forget'));
    await tester.pumpAndSettle();

    // Confirmation dialog; confirm via its TextButton.
    await tester.tap(find.widgetWithText(TextButton, 'Forget'));
    await tester.pumpAndSettle();

    expect(forgotten, ['a']);
    expect(find.text('Field Notebook'), findsNothing);
    expect(find.textContaining('Nothing to forget'), findsOneWidget);
  });

  testWidgets('cancelling Forget leaves it untouched', (tester) async {
    engrams = [_engram('a', name: 'Field Notebook')];

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Forget'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(forgotten, isEmpty);
    expect(find.text('Field Notebook'), findsOneWidget);
  });
}
