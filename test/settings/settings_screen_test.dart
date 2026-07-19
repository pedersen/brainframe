import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/repository_scope.dart';
import 'package:brainframe/settings/app_settings_controller.dart';
import 'package:brainframe/settings/settings_scope.dart';
import 'package:brainframe/settings/settings_store.dart';
import 'package:brainframe/settings/settings_screen.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/localized_app.dart';

class _MapBackend implements SettingsBackend {
  final Map<String, Object?> values = {};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

/// A writable engram store with an in-memory settings blob.
class _FakeStore extends EngramStore {
  Map<String, Object?>? settings;
  @override
  Future<List<String>> list() async => const [];
  @override
  Future<Uint8List> readBytes(String path) => throw UnimplementedError();
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
  @override
  Future<Map<String, Object?>?> readSettings() async => settings;
  @override
  Future<void> writeSettings(Map<String, Object?> next) async => settings = next;
}

void main() {
  late AppSettingsController controller;
  late EngramRepository repository;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    controller = AppSettingsController(device: _MapBackend());
    // A writable active engram, so the per-engram theme override is enabled.
    await controller.setActiveEngram(
      Engram(id: 'e', displayName: 'E', readOnly: false, store: _FakeStore()),
    );
    repository = EngramRepository(
      preferences: SharedPreferencesAsync(),
      containerPathResolver: () async => throw StateError('no container'),
    );
  });

  Widget host(Widget child) => AppSettings(
        designOverride: DesignLanguage.material,
        controller: controller,
        child: SettingsScope(
          store: controller.store,
          child: RepositoryScope(
            repository: repository,
            child: localizedApp(home: child),
          ),
        ),
      );

  void setSize(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('wide layout renders the core categories and Appearance controls',
      (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Housekeeping'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    // Appearance detail: both theme rows + the reset section.
    expect(find.text('Default theme'), findsOneWidget);
    expect(find.text('This engram'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reset'), findsOneWidget);
  });

  testWidgets('changing the default theme updates the controller',
      (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    // "Dark" appears in both theme rows; the first is the Default theme control.
    await tester.tap(find.text('Dark').first);
    await tester.pumpAndSettle();
    expect(controller.defaultTheme, ThemeMode.dark);
  });

  testWidgets('overriding this engram updates the controller', (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    // "Light" only appears in the two theme rows; the last is the override.
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(controller.engramThemeChoice, EngramThemeChoice.light);
  });

  testWidgets('reset shows a confirmation snackbar', (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reset to their defaults'), findsOneWidget);
  });

  testWidgets('selecting Housekeeping shows its custom detail pane',
      (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Housekeeping'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing to forget'), findsOneWidget);
  });

  testWidgets('narrow layout drills into a category and back', (tester) async {
    setSize(tester, 420);
    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pumpAndSettle();

    // Master list first — no detail controls yet.
    expect(find.text('Default theme'), findsNothing);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Default theme'), findsOneWidget); // drilled into detail

    // The back bar (‹ Settings) returns to the master list.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Default theme'), findsNothing);
    expect(find.text('Housekeeping'), findsOneWidget);
  });

  testWidgets('Escape pops the settings route', (tester) async {
    setSize(tester, 1000);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openSettingsScreen(context),
                child: const Text('open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Default theme'), findsOneWidget); // settings is up

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open settings'), findsOneWidget); // back home
  });
}
