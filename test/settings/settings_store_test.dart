import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/settings/device_settings.dart';
import 'package:brainframe/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// An in-memory backend that records values, for routing/behaviour assertions.
class _MapBackend implements SettingsBackend {
  final Map<String, Object?> values = {};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object? value) async {
    values[key] = value;
  }
}

/// A fake [EngramStore] whose per-engram settings blob lives in memory.
class _FakeEngramStore extends EngramStore {
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
  Future<void> writeSettings(Map<String, Object?> next) async {
    settings = next;
  }
}

enum _Mode { source, live, reading }

void main() {
  group('Setting codecs', () {
    test('primitive settings round-trip and fall back on the wrong type', () {
      final flag = Setting.boolean(
        key: 'flag',
        tier: SettingTier.device,
        defaultValue: true,
      );
      expect(flag.decode(flag.encode(false)), isFalse);
      expect(flag.decode('nope'), isTrue); // wrong type → default

      final count = Setting.integer(
        key: 'count',
        tier: SettingTier.device,
        defaultValue: 4,
      );
      expect(count.decode(count.encode(7)), 7);
      expect(count.decode(3.0), 3); // a JSON number decoded as double → int
      expect(count.decode(null), 4);

      final size = Setting.number(key: 'size', tier: SettingTier.device);
      expect(size.decode(size.encode(1.5)), 1.5);
    });

    test('enumerated persists by name and tolerates unknown values', () {
      final mode = Setting.enumerated(
        key: 'mode',
        tier: SettingTier.engram,
        defaultValue: _Mode.live,
        values: _Mode.values,
      );
      expect(mode.encode(_Mode.reading), 'reading');
      expect(mode.decode('source'), _Mode.source);
      expect(mode.decode('gone'), _Mode.live); // unknown → default
      expect(mode.decode(123), _Mode.live); // wrong type → default
    });
  });

  group('SettingsStore', () {
    late _MapBackend device;
    late _MapBackend engram;
    late SettingsStore store;

    setUp(() {
      device = _MapBackend();
      engram = _MapBackend();
      store = SettingsStore(device: device, engram: () => engram);
    });

    test('returns the default when nothing is stored', () async {
      final s = Setting.integer(
        key: 'x',
        tier: SettingTier.device,
        defaultValue: 9,
      );
      expect(await store.read(s), 9);
    });

    test('routes each setting to its tier', () async {
      final dev = Setting.string(key: 'name', tier: SettingTier.device);
      final eng = Setting.string(key: 'fmt', tier: SettingTier.engram);

      await store.write(dev, 'on-device');
      await store.write(eng, 'in-engram');

      expect(device.values['name'], 'on-device');
      expect(engram.values['fmt'], 'in-engram');
      expect(device.values.containsKey('fmt'), isFalse);
      expect(await store.read(dev), 'on-device');
      expect(await store.read(eng), 'in-engram');
    });

    test('resolves the per-engram backend fresh on each access', () async {
      final s = Setting.string(key: 'k', tier: SettingTier.engram);
      final first = _MapBackend()..values['k'] = 'one';
      final second = _MapBackend()..values['k'] = 'two';
      var active = first;
      final s2 = SettingsStore(device: _MapBackend(), engram: () => active);

      expect(await s2.read(s), 'one');
      active = second; // the user switched engrams
      expect(await s2.read(s), 'two');
    });
  });

  group('DeviceSettingsBackend', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('round-trips under the settings. namespace as JSON', () async {
      final prefs = SharedPreferencesAsync();
      final backend = DeviceSettingsBackend(prefs);

      expect(await backend.read('theme'), isNull);
      await backend.write('theme', 'dark');

      expect(await backend.read('theme'), 'dark');
      expect(await prefs.getString('settings.theme'), '"dark"');
    });
  });

  group('EngramSettingsBackend', () {
    test('merges writes, preserving other keys', () async {
      final fake = _FakeEngramStore();
      final backend = EngramSettingsBackend(fake);

      await backend.write('a', 1);
      await backend.write('b', 2);

      expect(fake.settings, {'a': 1, 'b': 2});
      expect(await backend.read('a'), 1);
      expect(await backend.read('missing'), isNull);
    });
  });

  test('NullSettingsBackend reads null and drops writes', () async {
    const backend = NullSettingsBackend();
    await backend.write('a', 1);
    expect(await backend.read('a'), isNull);
  });

  group('device settings codecs', () {
    test('windowStateSetting round-trips a map and defaults to null', () {
      expect(
        windowStateSetting.decode(windowStateSetting.encode({'width': 900})),
        {'width': 900},
      );
      expect(windowStateSetting.decode(null), isNull);
      expect(windowStateSetting.decode('garbage'), isNull);
    });

    test('sidebarWidthSetting round-trips a double and defaults to null', () {
      expect(sidebarWidthSetting.decode(sidebarWidthSetting.encode(312.5)), 312.5);
      expect(sidebarWidthSetting.decode(null), isNull);
      expect(sidebarWidthSetting.decode('x'), isNull);
    });
  });
}
