import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../engram.dart';
import '../engram_store.dart';
import '../id.dart';
import '../metadata.dart';
import 'engram_location.dart';

/// The app-owned marker directory that identifies a folder as an engram.
const String markerDirectoryName = '.brainframe';

/// The metadata file inside the marker directory.
const String metadataFileName = 'engram.json';

/// A read-write [EngramStore] over an on-disk directory.
///
/// This is the only place in the app that touches a `dart:io` [Directory];
/// everything above it speaks in engram-relative paths. Content paths use
/// forward slashes on every platform and never begin with a slash. The marker
/// directory ([markerDirectoryName]) is app-owned metadata, not content, so it
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
      if (relative == markerDirectoryName ||
          relative.startsWith('$markerDirectoryName/')) {
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
    if (path == markerDirectoryName || path.startsWith('$markerDirectoryName/')) {
      throw ArgumentError.value(
        path,
        'path',
        'the $markerDirectoryName marker is app-owned and cannot be written',
      );
    }
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
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
/// `$markerDirectoryName/$metadataFileName` marker with a fresh ULID id, and
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
  final marker = Directory('${location.path}/$markerDirectoryName');
  final metaFile = File('${marker.path}/$metadataFileName');
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

/// Opens an existing engram at [location] by reading its marker.
///
/// Throws [StateError] if there is no marker there; propagates
/// [EngramMetadataException] if the marker is malformed.
Future<Engram> openFileSystemEngram(EngramLocation location) async {
  final metaFile =
      File('${location.path}/$markerDirectoryName/$metadataFileName');
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
