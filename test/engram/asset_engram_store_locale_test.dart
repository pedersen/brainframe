import 'dart:typed_data';
import 'dart:ui';

import 'package:brainframe/engram/asset_engram_store.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_asset_bundle.dart';

/// A minimal non-asset store, to prove contentForLocale is a no-op for it.
class _FilesystemLikeStore extends EngramStore {
  @override
  Future<List<String>> list() async => const [];
  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}

void main() {
  // Base (en) defines the page set; es is a *partial* translation (only a.md).
  final bundle = FakeAssetBundle({
    'p/en/a.md': 'english a',
    'p/en/notes/b.md': 'english b',
    'p/es/a.md': 'spanish a',
  });
  AssetEngramStore store([String locale = 'en']) =>
      AssetEngramStore(assetPrefix: 'p/', locale: locale, bundle: bundle);

  test('list() returns the base-locale page set, whatever the active locale',
      () async {
    Future<void> expectBaseSet(AssetEngramStore s) async {
      expect((await s.list()).toSet(), {'a.md', 'notes/b.md'});
    }

    await expectBaseSet(store('en'));
    await expectBaseSet(store('es'));
    await expectBaseSet(store('es').forLocale(const Locale('es', 'MX')));
  });

  test('reads the active locale when that page is translated', () async {
    expect(await store('es').readString('a.md'), 'spanish a');
  });

  test('falls back to the base locale per untranslated page', () async {
    // b.md has no es/ translation, so the whole document stays whole in English.
    expect(await store('es').readString('notes/b.md'), 'english b');
  });

  test('resolves a region through its language to the base', () async {
    final mx = store().forLocale(const Locale('es', 'MX'));
    expect(await mx.readString('a.md'), 'spanish a'); // es_MX -> es
    expect(await mx.readString('notes/b.md'), 'english b'); // es_MX -> es -> en
  });

  test('forLocale keeps the prefix and bundle', () async {
    final es = store().forLocale(const Locale('es'));
    expect(es.assetPrefix, 'p/');
    expect(es.localeChain, ['es', 'en']);
    expect(await es.readString('a.md'), 'spanish a');
  });

  test('contentForLocale binds an AssetEngramStore and passes others through',
      () {
    final asset = store();
    final bound = contentForLocale(asset, const Locale('es'));
    expect(bound, isA<AssetEngramStore>());
    expect((bound as AssetEngramStore).localeChain, ['es', 'en']);

    final plain = _FilesystemLikeStore();
    expect(contentForLocale(plain, const Locale('es')), same(plain));
  });
}
