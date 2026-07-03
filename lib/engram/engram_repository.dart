import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'built_in_engrams.dart';
import 'engram.dart';
import 'fs/fs_store.dart';

/// Discovers, creates, and remembers engrams.
///
/// It always surfaces the two built-in engrams (from the asset store), scans
/// the app container one level deep for markers (Location A), and resolves
/// registry roots that live outside the container (Location B) from
/// `shared_preferences`. Roots that fail to resolve degrade to a reconnectable
/// "unavailable" state rather than crashing discovery.
///
/// Only `dart:io` work happens behind the [fs/fs_store.dart] seam, so this class
/// is platform-agnostic. The container path is injected (via
/// [containerPathResolver]) rather than hard-wired, so desktop/mobile can use
/// `applicationEngramContainerPath` while the Pi supplies its own configured
/// mount and web can decline; a resolver that throws simply yields the built-ins.
class EngramRepository {
  EngramRepository({
    required SharedPreferences preferences,
    required Future<String> Function() containerPathResolver,
    AssetBundle? bundle,
  })  : _prefs = preferences,
        _resolveContainerPath = containerPathResolver,
        _assetBundle = bundle;

  final SharedPreferences _prefs;
  final Future<String> Function() _resolveContainerPath;
  final AssetBundle? _assetBundle;

  static const String _registryKey = 'engram.registry.v1';
  static const String _lastOpenedKey = 'engram.lastOpened';

  /// The engrams available now, plus known registry roots that could not be
  /// resolved this pass (surfaced as reconnectable, not dropped).
  Future<EngramDiscovery> discover() async {
    final available = <Engram>[...builtInEngrams(bundle: _assetBundle)];
    final unavailable = <UnavailableEngram>[];
    final seenIds = {for (final engram in available) engram.id};

    // Location A — engrams sitting directly in the app container.
    try {
      final containerPath = await _resolveContainerPath();
      for (final engram in await discoverContainerEngrams(containerPath)) {
        if (seenIds.add(engram.id)) available.add(engram);
      }
    } catch (_) {
      // No filesystem (web), or a missing/unreadable container — the built-ins
      // still stand. Discovery never crashes over a bad container.
    }

    // Location B — registry roots outside the container.
    for (final entry in _readRegistry()) {
      try {
        final engram = await openFileSystemEngram(EngramLocation(entry.path));
        if (seenIds.add(engram.id)) available.add(engram);
      } catch (_) {
        // Deleted folder, stale token, not-yet-synced file: keep it registered
        // and surface it as reconnectable rather than silently dropping it.
        unavailable.add(
          UnavailableEngram(
            id: entry.id,
            displayName: entry.displayName,
            location: EngramLocation(entry.path),
          ),
        );
      }
    }

    return EngramDiscovery(available: available, unavailable: unavailable);
  }

  /// Creates a new read-write engram in the app container.
  Future<Engram> create(String displayName) async {
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'must not be blank');
    }
    final containerPath = await _resolveContainerPath();
    return createContainerEngram(containerPath, displayName);
  }

  /// Adopts an existing engram at [location] (e.g. a folder picked on desktop)
  /// by validating its marker and adding it to the registry.
  Future<Engram> adopt(EngramLocation location) async {
    final engram = await openFileSystemEngram(location);
    final entries = _readRegistry()
      ..removeWhere((e) => e.id == engram.id || e.path == location.path);
    entries.add(
      _RegistryEntry(
        id: engram.id,
        displayName: engram.displayName,
        path: location.path,
      ),
    );
    await _writeRegistry(entries);
    return engram;
  }

  /// Drops a registered (Location B) engram from the registry, leaving its
  /// files on disk. Built-in engrams cannot be forgotten (Decision 5);
  /// container engrams are removed by deleting their folder, not through here.
  Future<void> forget(String id) async {
    if (isBuiltInEngramId(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'built-in engrams cannot be forgotten',
      );
    }
    final entries = _readRegistry()..removeWhere((e) => e.id == id);
    await _writeRegistry(entries);
  }

  /// The engram the app last opened, or null if none is set or it no longer
  /// resolves to an available engram.
  Future<Engram?> get lastOpened async {
    final id = _prefs.getString(_lastOpenedKey);
    if (id == null) return null;
    final discovery = await discover();
    for (final engram in discovery.available) {
      if (engram.id == id) return engram;
    }
    return null;
  }

  /// Records [id] as the last-opened engram.
  Future<void> setLastOpened(String id) =>
      _prefs.setString(_lastOpenedKey, id);

  List<_RegistryEntry> _readRegistry() {
    final raw = _prefs.getStringList(_registryKey) ?? const <String>[];
    final entries = <_RegistryEntry>[];
    for (final line in raw) {
      try {
        entries.add(
          _RegistryEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip a corrupt registry line rather than failing the whole app.
      }
    }
    return entries;
  }

  Future<void> _writeRegistry(List<_RegistryEntry> entries) =>
      _prefs.setStringList(
        _registryKey,
        [for (final entry in entries) jsonEncode(entry.toJson())],
      );
}

/// The result of a discovery pass.
class EngramDiscovery {
  const EngramDiscovery({required this.available, required this.unavailable});

  /// Engrams the app can open right now (built-ins first).
  final List<Engram> available;

  /// Known registry roots that did not resolve this pass; they remain
  /// registered and reconnect when their folder returns.
  final List<UnavailableEngram> unavailable;
}

/// A registered engram that could not be resolved this discovery pass, carried
/// with its last-known identity so the UI can offer to reconnect it.
class UnavailableEngram {
  const UnavailableEngram({
    required this.id,
    required this.displayName,
    required this.location,
  });

  final String id;
  final String displayName;
  final EngramLocation location;
}

/// A persisted registry row: an engram's last-known identity plus where it
/// lives, so a missing engram can still be shown and later reconnected.
class _RegistryEntry {
  const _RegistryEntry({
    required this.id,
    required this.displayName,
    required this.path,
  });

  final String id;
  final String displayName;
  final String path;

  Map<String, dynamic> toJson() =>
      {'id': id, 'displayName': displayName, 'path': path};

  factory _RegistryEntry.fromJson(Map<String, dynamic> json) => _RegistryEntry(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        path: json['path'] as String,
      );
}
