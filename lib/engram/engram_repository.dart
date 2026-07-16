import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show AssetBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'built_in_engrams.dart';
import 'engram.dart';
import 'fs/fs_store.dart';

/// Logger name for discovery/registry diagnostics (see `dart:developer`).
const String _logName = 'brainframe.engram.repository';

/// Severity aligned with `package:logging`'s `Level.WARNING`.
const int _warning = 900;

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
    required SharedPreferencesAsync preferences,
    required Future<String> Function() containerPathResolver,
    AssetBundle? bundle,
  })  : _prefs = preferences,
        _resolveContainerPath = containerPathResolver,
        _assetBundle = bundle;

  final SharedPreferencesAsync _prefs;
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
    } catch (error, stackTrace) {
      // No filesystem (web), or a missing/unreadable container — the built-ins
      // still stand. Discovery never crashes over a bad container, but the skip
      // is logged rather than swallowed silently.
      developer.log(
        'Container scan skipped; surfacing built-ins only.',
        name: _logName,
        level: _warning,
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Location B — registry roots outside the container.
    for (final entry in await _readRegistry()) {
      try {
        final engram = await openFileSystemEngram(EngramLocation(entry.path));
        if (seenIds.add(engram.id)) available.add(engram);
      } catch (error, stackTrace) {
        // Deleted folder, stale token, not-yet-synced file: keep it registered
        // and surface it as reconnectable rather than silently dropping it.
        developer.log(
          'Registry root "${entry.path}" (${entry.displayName}) is '
          'unavailable; surfacing as reconnectable.',
          name: _logName,
          level: _warning,
          error: error,
          stackTrace: stackTrace,
        );
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

  /// Adopts an existing engram at [location] by validating its marker and
  /// adding it to the registry. The folder must already be an engram; to adopt
  /// a plain folder the user picked, use [adoptFolder] instead.
  Future<Engram> adopt(EngramLocation location) async {
    final engram = await openFileSystemEngram(location);
    return _register(engram, location);
  }

  /// Adopts the folder at [location] as a registry root, turning it into an
  /// engram if it is not one already (the desktop "choose any folder" flow).
  ///
  /// A folder that already carries a marker is opened and keeps its identity; a
  /// plain folder gets a fresh marker whose display name comes from
  /// [displayName], defaulting to the folder's own name. Either way the result
  /// is persisted as a plain-path registry root.
  Future<Engram> adoptFolder(
    EngramLocation location, {
    String? displayName,
  }) async {
    final engram = await openOrCreateFileSystemEngram(
      location,
      displayName: displayName ?? _folderDisplayName(location.path),
    );
    return _register(engram, location);
  }

  /// Persists [engram] at [location] as a registry root, replacing any prior
  /// entry with the same id or path so re-adopting never duplicates a row.
  Future<Engram> _register(Engram engram, EngramLocation location) async {
    final entries = (await _readRegistry())
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
    final entries = (await _readRegistry())..removeWhere((e) => e.id == id);
    await _writeRegistry(entries);
  }

  /// The engram the app last opened, or null if none is set or it no longer
  /// resolves to an available engram.
  Future<Engram?> get lastOpened async {
    final id = await _prefs.getString(_lastOpenedKey);
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

  /// The engram to open at startup: the last-opened one if it still resolves,
  /// otherwise the built-in tutorial on a true first run (Decision 5). Always
  /// succeeds — the tutorial is a bundled built-in that is always present.
  Future<Engram> openInitialEngram() async =>
      await lastOpened ?? _builtInTutorial();

  /// Opens the engram at [path] directly for this session — the
  /// `--engram <path>` startup override — without consulting or modifying the
  /// registry or the last-opened record. If the folder is not yet an engram, a
  /// marker is created in place (named from the folder), mirroring the "adopt a
  /// folder" flow. Because nothing is persisted, a later ordinary launch
  /// resolves the usual way.
  Future<Engram> openEngramAtPath(String path) => openOrCreateFileSystemEngram(
        EngramLocation(path),
        displayName: _folderDisplayName(path),
      );

  Engram _builtInTutorial() => builtInEngrams(bundle: _assetBundle)
      .firstWhere((engram) => engram.id == builtinTutorialId);

  Future<List<_RegistryEntry>> _readRegistry() async {
    final raw = await _prefs.getStringList(_registryKey) ?? const <String>[];
    final entries = <_RegistryEntry>[];
    for (final line in raw) {
      try {
        entries.add(
          _RegistryEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (error, stackTrace) {
        // Skip a corrupt registry line rather than failing the whole app.
        developer.log(
          'Skipped a corrupt registry entry.',
          name: _logName,
          level: _warning,
          error: error,
          stackTrace: stackTrace,
        );
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

/// Derives a display name from an absolute folder [path] — its final segment,
/// tolerating either separator and any trailing slashes, falling back to
/// `Engram` for a root or otherwise nameless path. Kept as plain string work so
/// the repository stays platform-agnostic (no `dart:io`, usable on web).
String _folderDisplayName(String path) {
  var normalized = path.replaceAll('\\', '/');
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final name = normalized.split('/').last;
  return name.isEmpty ? 'Engram' : name;
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
