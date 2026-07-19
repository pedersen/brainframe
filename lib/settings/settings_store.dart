import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engram/engram_store.dart';

/// Which store a preference lives in — the two tiers reserved by design so a
/// per-engram tier never has to be retrofitted onto a flat global store later.
///
///  - [device]: per-device, on this machine only (window geometry, theme,
///    restore-last-session). Backed by `shared_preferences`.
///  - [engram]: per-engram, stored **in** the active engram so it travels with
///    it and syncs wherever the folder goes (daily-note format, template
///    locations, engram-scoped preferences).
enum SettingTier { device, engram }

/// A single declared preference: a stable [key], which [tier] it lives in, a
/// [defaultValue], and a JSON codec. Core and plugins declare these; the
/// [SettingsStore] reads/writes them without knowing what they mean.
///
/// [encode] must return a JSON-compatible value (bool, num, String, or a
/// List/Map of the same); [decode] turns a stored value back into [T], falling
/// back to [defaultValue] on anything unexpected. The typed constructors
/// ([boolean], [string], [integer], [number], [enumerated]) cover the common
/// cases; use the primary constructor for anything else.
class Setting<T> {
  const Setting({
    required this.key,
    required this.tier,
    required this.defaultValue,
    required this.encode,
    required this.decode,
  });

  final String key;
  final SettingTier tier;
  final T defaultValue;
  final Object? Function(T value) encode;
  final T Function(Object? raw) decode;

  static Setting<bool> boolean({
    required String key,
    required SettingTier tier,
    bool defaultValue = false,
  }) => Setting<bool>(
    key: key,
    tier: tier,
    defaultValue: defaultValue,
    encode: (v) => v,
    decode: (raw) => raw is bool ? raw : defaultValue,
  );

  static Setting<String> string({
    required String key,
    required SettingTier tier,
    String defaultValue = '',
  }) => Setting<String>(
    key: key,
    tier: tier,
    defaultValue: defaultValue,
    encode: (v) => v,
    decode: (raw) => raw is String ? raw : defaultValue,
  );

  static Setting<int> integer({
    required String key,
    required SettingTier tier,
    int defaultValue = 0,
  }) => Setting<int>(
    key: key,
    tier: tier,
    defaultValue: defaultValue,
    encode: (v) => v,
    // JSON numbers may decode as double; coerce to int.
    decode: (raw) => raw is num ? raw.toInt() : defaultValue,
  );

  static Setting<double> number({
    required String key,
    required SettingTier tier,
    double defaultValue = 0,
  }) => Setting<double>(
    key: key,
    tier: tier,
    defaultValue: defaultValue,
    encode: (v) => v,
    decode: (raw) => raw is num ? raw.toDouble() : defaultValue,
  );

  /// A setting over an enum, persisted by its [Enum.name] so reordering or
  /// adding cases never corrupts stored values.
  static Setting<E> enumerated<E extends Enum>({
    required String key,
    required SettingTier tier,
    required E defaultValue,
    required List<E> values,
  }) => Setting<E>(
    key: key,
    tier: tier,
    defaultValue: defaultValue,
    encode: (v) => v.name,
    decode: (raw) {
      if (raw is String) {
        for (final value in values) {
          if (value.name == raw) return value;
        }
      }
      return defaultValue;
    },
  );
}

/// A key→JSON-value store for one tier. Reads return the stored value or null
/// when absent; writes persist a JSON-compatible value.
abstract class SettingsBackend {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? value);
}

/// The per-device tier, backed by `shared_preferences`. Each setting is one
/// `settings.<key>` entry holding its JSON-encoded value, so it sits alongside
/// the app's other local preferences without a schema migration.
class DeviceSettingsBackend implements SettingsBackend {
  DeviceSettingsBackend(this._prefs);

  final SharedPreferencesAsync _prefs;

  static String _namespaced(String key) => 'settings.$key';

  @override
  Future<Object?> read(String key) async {
    final raw = await _prefs.getString(_namespaced(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null; // a corrupt value degrades to the setting's default
    }
  }

  @override
  Future<void> write(String key, Object? value) =>
      _prefs.setString(_namespaced(key), jsonEncode(value));
}

/// The per-engram tier for a single engram, reading and writing its app-owned
/// settings blob through the engram's [EngramStore] (which persists it inside
/// the engram, so it travels with the folder).
class EngramSettingsBackend implements SettingsBackend {
  EngramSettingsBackend(this._store);

  final EngramStore _store;

  @override
  Future<Object?> read(String key) async => (await _store.readSettings())?[key];

  @override
  Future<void> write(String key, Object? value) async {
    final settings = {...?await _store.readSettings()};
    settings[key] = value;
    await _store.writeSettings(settings);
  }
}

/// A tier that cannot persist: reads return null (so settings fall back to their
/// defaults) and writes are silently dropped. Used for the per-engram tier of a
/// read-only built-in engram, or on web where there is no filesystem engram.
class NullSettingsBackend implements SettingsBackend {
  const NullSettingsBackend();

  @override
  Future<Object?> read(String key) async => null;

  @override
  Future<void> write(String key, Object? value) async {}
}

/// The unified settings store: one place every feature and plugin reads and
/// writes preferences, routed to the right tier by each [Setting.tier].
///
/// The per-device backend is fixed for the app's life; the per-engram backend
/// is resolved fresh on each access via [engram], so it always targets the
/// *currently active* engram (which changes as the user switches engrams).
class SettingsStore {
  const SettingsStore({required this.device, required this.engram});

  /// The per-device backend (`shared_preferences`).
  final SettingsBackend device;

  /// Resolves the per-engram backend for the active engram. Returns a
  /// [NullSettingsBackend] when the active engram can't persist (read-only or
  /// web).
  final SettingsBackend Function() engram;

  SettingsBackend _backend(SettingTier tier) =>
      tier == SettingTier.device ? device : engram();

  /// Reads [setting], returning its stored value or [Setting.defaultValue] when
  /// absent or unreadable.
  Future<T> read<T>(Setting<T> setting) async {
    final raw = await _backend(setting.tier).read(setting.key);
    if (raw == null) return setting.defaultValue;
    try {
      return setting.decode(raw);
    } catch (_) {
      return setting.defaultValue;
    }
  }

  /// Persists [value] for [setting] in its tier.
  Future<void> write<T>(Setting<T> setting, T value) =>
      _backend(setting.tier).write(setting.key, setting.encode(value));
}
