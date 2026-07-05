import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;

import 'engram_store.dart';

/// The base locale: its subdirectory (`en/`) defines an engram's canonical page
/// set, and every read falls back to it when a translation is missing.
const String _baseLocale = 'en';

/// A read-only, locale-aware [EngramStore] over the Flutter asset bundle.
///
/// Backs the built-in tutorial and help engrams: they ship inside the app, have
/// no directory, and are uneditable and always pristine by construction. It is
/// the first non-filesystem backend, so it is the concrete proof that the rest
/// of the app can reach content through [EngramStore] without assuming a
/// `Directory`. Asset bundles exist on web too, so the built-ins render there
/// even though the filesystem store does not.
///
/// Content is **locale-partitioned** under [assetPrefix]: the pages live in
/// per-locale subdirectories (`assets/engrams/tutorial/en/welcome.md`,
/// `.../es/welcome.md`), and the base locale (`en`) defines the canonical set.
/// [list] returns the base-locale files; [readBytes] resolves the active
/// [locale] with **per-file fallback to `en`** (`es_MX` → `es` → `en`), so a
/// partial translation degrades into a mixed-but-whole document rather than a
/// broken one. Engram-relative paths stay locale-free (`welcome.md`,
/// `notes/first-note.md`) — the `<locale>/` segment is this store's private
/// detail. [assetPrefix]'s trailing slash is normalized on so callers need not
/// supply one; internally it pins prefix matching to a directory boundary (so
/// `tutorial` never captures a `tutorial-archive` sibling).
///
/// The active [locale] is bound where the engram is *opened* (in the widget
/// tree, via [forLocale] / [contentForLocale]) rather than passed into each
/// read, so the [EngramStore] contract stays locale-free — a filesystem engram
/// has no locale. It defaults to the base locale.
class AssetEngramStore extends EngramStore {
  AssetEngramStore({
    required String assetPrefix,
    String locale = _baseLocale,
    AssetBundle? bundle,
  })  : assetPrefix =
            assetPrefix.endsWith('/') ? assetPrefix : '$assetPrefix/',
        localeChain = _chainFor(locale),
        _bundle = bundle ?? rootBundle;

  /// The slash-terminated asset path this engram's `<locale>/` dirs live under.
  final String assetPrefix;

  /// Locales to try, most specific first, always ending at the base locale —
  /// e.g. `['es_MX', 'es', 'en']`, or `['en']` for the base.
  final List<String> localeChain;

  final AssetBundle _bundle;

  /// Cached manifest asset keys, loaded once — used to resolve which locale
  /// actually has a given page without exception-driven control flow.
  Set<String>? _assetKeys;

  /// This store bound to [locale] (same prefix and bundle). Returned by
  /// [contentForLocale] at the point a built-in engram is opened.
  AssetEngramStore forLocale(Locale locale) => AssetEngramStore(
        assetPrefix: assetPrefix,
        locale: _codeOf(locale),
        bundle: _bundle,
      );

  /// The base-locale directory that defines the canonical page set.
  String get _baseDir => '$assetPrefix$_baseLocale/';

  Future<Set<String>> _keys() async => _assetKeys ??=
      (await AssetManifest.loadFromAssetBundle(_bundle)).listAssets().toSet();

  @override
  Future<List<String>> list() async {
    final keys = await _keys();
    return keys
        .where((key) => key.startsWith(_baseDir))
        .map((key) => key.substring(_baseDir.length))
        .toList();
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final keys = await _keys();
    for (final locale in localeChain) {
      final key = '$assetPrefix$locale/$path';
      if (keys.contains(key)) return _load(key);
    }
    // No locale in the chain has it (including the base): surface a clear error
    // by loading the base key, which throws the bundle's own "not found".
    return _load('$_baseDir$path');
  }

  Future<Uint8List> _load(String key) async {
    final data = await _bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot write "$path".',
    );
  }

  @override
  Future<void> delete(String path) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot delete "$path".',
    );
  }

  @override
  Future<void> move(String from, String to) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot move "$from".',
    );
  }

  @override
  Future<void> createDirectory(String path) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot create directory "$path".',
    );
  }

  @override
  Future<void> deleteDirectory(String path) {
    throw UnsupportedError(
      'AssetEngramStore is read-only; cannot delete directory "$path".',
    );
  }

  // listDirectories() inherits the base "no directories" default: the asset
  // bundle exposes files by key and has no standalone empty-folder concept.

  /// BCP47-ish asset directory name for [locale]: `en`, `es_MX`, `en_XA`.
  static String _codeOf(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  /// The fallback chain for a locale code: itself, then its language, then the
  /// base — de-duplicated, order preserved. `'es_MX'` → `['es_MX', 'es', 'en']`.
  static List<String> _chainFor(String locale) {
    final chain = <String>[];
    void add(String code) {
      if (code.isNotEmpty && !chain.contains(code)) chain.add(code);
    }

    final normalized = locale.replaceAll('-', '_');
    add(normalized);
    final underscore = normalized.indexOf('_');
    if (underscore > 0) add(normalized.substring(0, underscore));
    add(_baseLocale);
    return chain;
  }
}

/// Binds [store] to [locale] when it is locale-aware (an [AssetEngramStore]);
/// other stores (the filesystem store) have no locale and are returned as-is.
///
/// Applied by the widget layer where a built-in engram is opened for reading,
/// so the [EngramStore] contract itself never carries a locale.
EngramStore contentForLocale(EngramStore store, Locale locale) =>
    store is AssetEngramStore ? store.forLocale(locale) : store;
