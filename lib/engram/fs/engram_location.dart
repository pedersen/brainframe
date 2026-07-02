/// Where a filesystem engram lives on disk, and how to reach it.
///
/// This is the one *filesystem*-only concept the design keeps out of the
/// top-level model: `Engram` holds an [EngramStore], never an [EngramLocation].
/// For v1 a location is just an absolute directory path — the app-container
/// default (resolved via `path_provider`) or a folder the user picked on
/// desktop. Later access kinds (iOS security-scoped bookmarks, iCloud ubiquity
/// containers) slot in behind this same type without changing callers, so it is
/// deliberately a plain value with no `dart:io` dependency — it can be
/// constructed and compared on every platform, including web.
class EngramLocation {
  const EngramLocation(this.path);

  /// Absolute path to the engram's root directory.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is EngramLocation && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'EngramLocation($path)';
}
