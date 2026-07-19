import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../engram.dart';
import '../engram_store.dart';
import '../id.dart';
import '../metadata.dart';
import 'engram_location.dart';

/// The app-owned marker directory that identifies a folder as an engram.
const String _markerDirectoryName = '.brainframe';

/// The metadata file inside the marker directory.
const String _metadataFileName = 'engram.json';

/// The per-engram settings file inside the marker directory (the settings
/// store's per-engram tier; see [EngramStore.readSettings]).
const String _settingsFileName = 'settings.json';

/// A read-write [EngramStore] over an on-disk directory.
///
/// This is the only place in the app that touches a `dart:io` [Directory];
/// everything above it speaks in engram-relative paths. Content paths use
/// forward slashes on every platform and never begin with a slash. The marker
/// directory ([_markerDirectoryName]) is app-owned metadata, not content, so it
/// is excluded from [list] and refused by [writeBytes].
class FileSystemEngramStore extends EngramStore {
  FileSystemEngramStore(this.location);

  /// Where this engram's root directory lives.
  final EngramLocation location;

  String get _rootPath => location.path;

  @override
  Future<List<String>> list() async {
    final root = Directory(_rootPath);
    if (!await root.exists()) return const [];
    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = _relativeOf(entity.path);
      if (relative == _markerDirectoryName ||
          relative.startsWith('$_markerDirectoryName/')) {
        continue; // the marker is app-owned metadata, not engram content
      }
      paths.add(relative);
    }
    return paths;
  }

  @override
  Future<List<String>> listDirectories() async {
    final root = Directory(_rootPath);
    if (!await root.exists()) return const [];
    final paths = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! Directory) continue;
      final relative = _relativeOf(entity.path);
      if (relative == _markerDirectoryName ||
          relative.startsWith('$_markerDirectoryName/')) {
        continue; // the marker is app-owned metadata, not engram content
      }
      paths.add(relative);
    }
    return paths;
  }

  @override
  Future<Uint8List> readBytes(String path) =>
      File(_resolve(path)).readAsBytes();

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _refuseMarker(path);
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await _atomicWrite(file, bytes);
  }

  @override
  Future<void> delete(String path) async {
    _refuseMarker(path);
    await File(_resolve(path)).delete();
  }

  @override
  Future<void> move(String from, String to) async {
    _refuseMarker(from);
    _refuseMarker(to);
    final target = File(_resolve(to));
    await target.parent.create(recursive: true);
    await File(_resolve(from)).rename(target.path);
  }

  @override
  Future<void> createDirectory(String path) async {
    _refuseMarker(path);
    await Directory(_resolve(path)).create(recursive: true);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    _refuseMarker(path);
    // Non-recursive: throws if the directory is missing or not empty, matching
    // the contract. EngramFileOps empties a folder's files and deeper shells
    // before removing it.
    await Directory(_resolve(path)).delete();
  }

  /// The per-engram settings file, inside the app-owned marker directory so it
  /// travels with the engram and stays out of the content listing.
  File get _settingsFile =>
      File('$_rootPath/$_markerDirectoryName/$_settingsFileName');

  @override
  Future<Map<String, Object?>?> readSettings() async {
    final file = _settingsFile;
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.of(decoded);
      }
    } catch (error, stackTrace) {
      // A corrupt settings file degrades to defaults, never crashes the app.
      developer.log(
        'Ignoring malformed $_markerDirectoryName/$_settingsFileName at $_rootPath.',
        name: 'brainframe.engram.fs',
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  @override
  Future<void> writeSettings(Map<String, Object?> settings) async {
    final file = _settingsFile;
    await file.parent.create(recursive: true); // ensure .brainframe/ exists
    final text = '${const JsonEncoder.withIndent('  ').convert(settings)}\n';
    await _atomicWrite(file, Uint8List.fromList(utf8.encode(text)));
  }

  /// Writes [bytes] to [file] atomically (Decision 5): write a sibling temp
  /// file with the data flushed to disk, then `rename` it over [file]. Rename
  /// is atomic within a filesystem, so an interrupted write (crash, power loss)
  /// leaves a reader with either the intact old file or the complete new one,
  /// never a half-written one. The temp file is a sibling so the rename stays
  /// on one filesystem; on failure before the rename it is cleaned up and
  /// [file] is left untouched. Writes to the same [file] must not run
  /// concurrently — the save pipeline serializes them per path.
  Future<void> _atomicWrite(File file, Uint8List bytes) async {
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // Best-effort cleanup; surface the original failure below.
        }
      }
      rethrow;
    }
  }

  /// Refuses any operation targeting the app-owned [_markerDirectoryName] tree,
  /// which is metadata, not engram content.
  void _refuseMarker(String path) {
    if (path == _markerDirectoryName ||
        path.startsWith('$_markerDirectoryName/')) {
      throw ArgumentError.value(
        path,
        'path',
        'the $_markerDirectoryName marker is app-owned and cannot be modified',
      );
    }
  }

  /// Resolves an engram-relative [path] to an absolute filesystem path, after
  /// rejecting absolute paths and `..` escapes. `dart:io` accepts forward
  /// slashes on every platform, so no separator translation is needed here.
  String _resolve(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.split('/').contains('..')) {
      throw ArgumentError.value(
        path,
        'path',
        'must be a non-escaping engram-relative path',
      );
    }
    return '$_rootPath/$path';
  }

  String _relativeOf(String absolutePath) {
    var relative = absolutePath;
    if (relative.startsWith(_rootPath)) {
      relative = relative.substring(_rootPath.length);
    }
    relative = relative.replaceAll('\\', '/');
    if (relative.startsWith('/')) relative = relative.substring(1);
    return relative;
  }
}

/// Creates a new engram at [location]: makes the directory, writes the
/// `$_markerDirectoryName/$_metadataFileName` marker with a fresh ULID id, and
/// nothing else in the folder (derived caches live in Application Support keyed
/// by id, never inside the engram — Decision 1).
///
/// Throws [ArgumentError] on an empty [displayName], and [StateError] if an
/// engram already exists at [location].
Future<Engram> createFileSystemEngram({
  required EngramLocation location,
  required String displayName,
}) async {
  if (displayName.isEmpty) {
    throw ArgumentError.value(displayName, 'displayName', 'must not be empty');
  }
  final marker = Directory('${location.path}/$_markerDirectoryName');
  final metaFile = File('${marker.path}/$_metadataFileName');
  if (await metaFile.exists()) {
    throw StateError('An engram already exists at ${location.path}');
  }
  await marker.create(recursive: true); // also creates the root directory
  final metadata = EngramMetadata.create(
    id: newUlid(),
    displayName: displayName,
  );
  await metaFile.writeAsString(metadata.encode());
  return Engram(
    id: metadata.id,
    displayName: metadata.displayName,
    readOnly: false,
    store: FileSystemEngramStore(location),
  );
}

/// Adopts the folder at [location]: opens it if it already carries a marker,
/// otherwise creates a fresh engram there with [displayName].
///
/// This is the "adopt a folder the user picked" primitive. An existing engram
/// is reused as-is — its stored id and display name win, and [displayName] is
/// ignored — so re-picking a known folder never rewrites its marker. A plain
/// folder (or one that does not exist yet) is turned into an engram in place.
///
/// Propagates [EngramMetadataException] if an existing marker is malformed.
Future<Engram> openOrCreateFileSystemEngram(
  EngramLocation location, {
  required String displayName,
}) async {
  final metaFile = File(
    '${location.path}/$_markerDirectoryName/$_metadataFileName',
  );
  if (await metaFile.exists()) {
    return openFileSystemEngram(location);
  }
  return createFileSystemEngram(location: location, displayName: displayName);
}

/// Opens an existing engram at [location] by reading its marker.
///
/// Throws [StateError] if there is no marker there; propagates
/// [EngramMetadataException] if the marker is malformed.
Future<Engram> openFileSystemEngram(EngramLocation location) async {
  final metaFile = File(
    '${location.path}/$_markerDirectoryName/$_metadataFileName',
  );
  if (!await metaFile.exists()) {
    throw StateError('No engram marker at ${location.path}');
  }
  final metadata = EngramMetadata.decode(await metaFile.readAsString());
  return Engram(
    id: metadata.id,
    displayName: metadata.displayName,
    readOnly: false,
    store: FileSystemEngramStore(location),
  );
}

/// The app documents directory (`path_provider`) — the *default* container
/// that holds engrams as sibling folders on desktop, iOS, and Android.
///
/// This is one container source, not the authority: the repository (Step 5)
/// takes the container as an injected value so it can be overridden per
/// platform. The Raspberry Pi in particular does not use this — its library is
/// expected to live on a separate mounted volume (a secondary SD card) whose
/// path comes from configuration, which `path_provider` cannot report. On a
/// headless Linux box without XDG user-dirs configured, `path_provider` throws
/// [MissingPlatformDirectoryException] rather than returning a path; the
/// container resolver, not this thin wrapper, is where that case is handled.
Future<String> applicationEngramContainerPath() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

/// Scans [containerPath] one level deep and opens every child directory that
/// carries a valid marker.
///
/// Children without a marker are ignored (ordinary folders the user may have
/// dropped in), and a child whose marker is unreadable or malformed is skipped
/// rather than crashing the whole scan. Nesting is not followed — the design
/// forbids an engram root inside another — so only direct children are checked.
Future<List<Engram>> discoverContainerEngrams(String containerPath) async {
  final container = Directory(containerPath);
  if (!await container.exists()) return const [];
  final engrams = <Engram>[];
  await for (final entity in container.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final marker = File(
      '${entity.path}/$_markerDirectoryName/$_metadataFileName',
    );
    if (!await marker.exists()) continue;
    try {
      engrams.add(await openFileSystemEngram(EngramLocation(entity.path)));
    } catch (error, stackTrace) {
      // Malformed/unreadable marker — skip, never crash the scan, but log it
      // rather than dropping the child silently.
      developer.log(
        'Skipped "${entity.path}": unreadable engram marker.',
        name: 'brainframe.engram.fs',
        level: 900, // WARNING, per package:logging's Level.WARNING
        error: error,
        stackTrace: stackTrace,
      );
      continue;
    }
  }
  return engrams;
}

/// Creates a new engram inside [containerPath], deriving a filesystem-safe
/// folder name from [displayName] and avoiding collisions with existing
/// siblings (`Personal`, then `Personal 2`, …).
Future<Engram> createContainerEngram(
  String containerPath,
  String displayName,
) async {
  final location = await _freeChildLocation(
    containerPath,
    _safeFolderName(displayName),
  );
  return createFileSystemEngram(location: location, displayName: displayName);
}

String _safeFolderName(String displayName) {
  final cleaned = displayName.replaceAll(RegExp(r'[\\/]+'), '-').trim();
  return cleaned.isEmpty ? 'Engram' : cleaned;
}

Future<EngramLocation> _freeChildLocation(
  String containerPath,
  String baseName,
) async {
  var candidate = '$containerPath/$baseName';
  var suffix = 2;
  while (await Directory(candidate).exists()) {
    candidate = '$containerPath/$baseName $suffix';
    suffix++;
  }
  return EngramLocation(candidate);
}
