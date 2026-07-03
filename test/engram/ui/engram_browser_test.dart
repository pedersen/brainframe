import 'dart:io';

import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/engram_scope.dart';
import 'package:brainframe/engram/ui/engram_browser.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory tempRoot;

  EngramRepository repo() => EngramRepository(
        preferences: SharedPreferencesAsync(),
        containerPathResolver: () async => '${tempRoot.path}/container',
      );

  Engram tutorial() =>
      builtInEngrams().firstWhere((e) => e.id == builtinTutorialId);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('browser_test');
    await Directory('${tempRoot.path}/container').create(recursive: true);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() async {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  // Force the Material design language so the scaffold is deterministic.
  Widget harness(EngramRepository repository) => AppSettings(
        designOverride: DesignLanguage.material,
        child: MaterialApp(
          home: EngramScope(
            initialEngram: tutorial(),
            child: EngramBrowser(repository: repository),
          ),
        ),
      );

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('wide layout shows no menu button; narrow shows one',
      (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open file browser'), findsNothing);

    setWidth(tester, 400);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open file browser'), findsOneWidget);
  });

  testWidgets('the help action opens the peek overlay without switching engrams',
      (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    // The help overlay is up, reading the help engram's index…
    expect(find.text('index.md'), findsOneWidget);
    expect(
      find.textContaining('BrainFrame help', findRichText: true),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Close help'));
    await tester.pumpAndSettle();
    // …and the browser is still on the tutorial (footer unchanged).
    expect(find.text('Tutorial'), findsOneWidget);
  });

  testWidgets('on a phone, opening the drawer and picking a file reads it',
      (tester) async {
    setWidth(tester, 400);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open file browser'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('first-note.md'));
    await tester.pumpAndSettle();

    expect(find.text('notes/first-note.md'), findsOneWidget); // breadcrumb
  });
}
