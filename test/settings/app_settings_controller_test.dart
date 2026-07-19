import 'dart:typed_data';

import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/settings/app_settings_controller.dart';
import 'package:brainframe/settings/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory device backend.
class _MapBackend implements SettingsBackend {
  final Map<String, Object?> values = {};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object? value) async => values[key] = value;
}

/// A writable engram store whose settings blob lives in memory.
class _FakeStore extends EngramStore {
  Map<String, Object?>? settings;
  @override
  Future<List<String>> list() async => const [];
  @override
  Future<Uint8List> readBytes(String path) => throw UnimplementedError();
  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      throw UnimplementedError();
  @override
  Future<Map<String, Object?>?> readSettings() async => settings;
  @override
  Future<void> writeSettings(Map<String, Object?> next) async => settings = next;
}

Engram _engram(String id, {required bool readOnly, required EngramStore store}) =>
    Engram(id: id, displayName: id, readOnly: readOnly, store: store);

void main() {
  test('with no active engram, theme is the device default', () async {
    final controller = AppSettingsController(device: _MapBackend());
    expect(controller.themeMode, ThemeMode.system);

    await controller.setDefaultTheme(ThemeMode.dark);
    expect(controller.defaultTheme, ThemeMode.dark);
    expect(controller.themeMode, ThemeMode.dark); // engram follows default
  });

  test('load restores the persisted device default', () async {
    final device = _MapBackend()..values['theme.default'] = 'dark';
    final controller = await AppSettingsController.load(device);
    expect(controller.defaultTheme, ThemeMode.dark);
  });

  test('a writable engram override wins over the device default', () async {
    final controller = AppSettingsController(device: _MapBackend());
    await controller.setDefaultTheme(ThemeMode.dark);

    final store = _FakeStore()..settings = {'theme.override': 'light'};
    await controller.setActiveEngram(
      _engram('e1', readOnly: false, store: store),
    );

    expect(controller.canOverridePerEngram, isTrue);
    expect(controller.engramThemeChoice, EngramThemeChoice.light);
    expect(controller.themeMode, ThemeMode.light);
  });

  test('setEngramThemeChoice persists the override into the engram', () async {
    final store = _FakeStore();
    final controller = AppSettingsController(device: _MapBackend());
    await controller.setActiveEngram(
      _engram('e', readOnly: false, store: store),
    );

    await controller.setEngramThemeChoice(EngramThemeChoice.dark);

    expect(store.settings, {'theme.override': 'dark'});
    expect(controller.themeMode, ThemeMode.dark);
  });

  test('read-only engrams cannot override and show the default', () async {
    final controller = AppSettingsController(device: _MapBackend());
    await controller.setDefaultTheme(ThemeMode.light);

    // Even a stored override is ignored: read-only binds to a null backend.
    final store = _FakeStore()..settings = {'theme.override': 'dark'};
    await controller.setActiveEngram(
      _engram('builtin', readOnly: true, store: store),
    );

    expect(controller.canOverridePerEngram, isFalse);
    expect(controller.themeMode, ThemeMode.light); // the device default

    await controller.setEngramThemeChoice(EngramThemeChoice.dark); // no-op
    expect(controller.engramThemeChoice, EngramThemeChoice.followDefault);
  });

  test('resetWindowAndLayout clears the device window + sidebar settings',
      () async {
    final device = _MapBackend()
      ..values['window.state'] = {'width': 900}
      ..values['ui.sidebarWidth'] = 300.0;
    final controller = AppSettingsController(device: device);

    await controller.resetWindowAndLayout();

    expect(device.values['window.state'], isNull);
    expect(device.values['ui.sidebarWidth'], isNull);
  });

  test('switching engrams reloads the override', () async {
    final controller = AppSettingsController(device: _MapBackend());
    final a = _FakeStore()..settings = {'theme.override': 'light'};
    final b = _FakeStore()..settings = {'theme.override': 'dark'};

    await controller.setActiveEngram(_engram('a', readOnly: false, store: a));
    expect(controller.themeMode, ThemeMode.light);

    await controller.setActiveEngram(_engram('b', readOnly: false, store: b));
    expect(controller.themeMode, ThemeMode.dark);
  });
}
