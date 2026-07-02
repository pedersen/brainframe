import '../engram.dart';
import 'engram_location.dart';

/// Web (and any non-`dart:io`) build: there is no filesystem for user engrams.
///
/// The asset store still serves the two built-in engrams (tutorial, help), so
/// the app is usable; only creating, opening, and locating on-disk engrams is
/// unsupported. These mirror the signatures of the `dart:io` implementation so
/// the conditional export in `fs_store.dart` presents one API on every
/// platform.
const String _unsupported =
    'Filesystem engrams are not supported on this platform.';

Future<Engram> createFileSystemEngram({
  required EngramLocation location,
  required String displayName,
}) =>
    throw UnsupportedError(_unsupported);

Future<Engram> openFileSystemEngram(EngramLocation location) =>
    throw UnsupportedError(_unsupported);

Future<String> applicationEngramContainerPath() =>
    throw UnsupportedError(_unsupported);
