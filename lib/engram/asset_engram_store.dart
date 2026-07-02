import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

import 'engram_store.dart';

/// A read-only [EngramStore] over the Flutter asset bundle.
///
/// Backs the built-in tutorial and help engrams: they ship inside the app, have
/// no directory, and are uneditable and always pristine by construction. It is
/// the first non-filesystem backend, so it is the concrete proof that the rest
/// of the app can reach content through [EngramStore] without assuming a
/// `Directory`. Asset bundles exist on web too, so the built-ins render there
/// even though the filesystem store does not.
///
/// Files live under [assetPrefix], a slash-terminated asset path such as
/// `assets/engrams/tutorial/`. Engram-relative paths are that prefix stripped
/// off, so callers see `welcome.md` and `notes/first-note.md`, never the bundle
/// key.
class AssetEngramStore implements EngramStore {
  AssetEngramStore({required this.assetPrefix, AssetBundle? bundle})
      : assert(
          assetPrefix.endsWith('/'),
          'assetPrefix must end with a slash so it matches a directory cleanly',
        ),
        _bundle = bundle ?? rootBundle;

  /// The slash-terminated asset path this engram's files live under.
  final String assetPrefix;

  final AssetBundle _bundle;

  @override
  Future<List<String>> list() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return manifest
        .listAssets()
        .where((key) => key.startsWith(assetPrefix))
        .map((key) => key.substring(assetPrefix.length))
        .toList();
  }

  @override
  Future<String> readString(String path) =>
      _bundle.loadString('$assetPrefix$path');

  @override
  Future<void> writeString(String path, String contents) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot write "$path".',
    );
  }
}
