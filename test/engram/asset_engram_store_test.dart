import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/asset_engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The default rootBundle serves the pubspec-declared assets in the test
  // asset bundle once the binding is initialized.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetEngramStore over the bundled tutorial engram', () {
    final store = AssetEngramStore(assetPrefix: 'assets/engrams/tutorial/');

    test('lists engram-relative paths, prefix stripped, including subdirs', () async {
      expect(
        await store.list(),
        unorderedEquals(['welcome.md', 'notes/first-note.md']),
      );
    });

    test('relative paths use forward slashes and no leading slash', () async {
      for (final path in await store.list()) {
        expect(path.startsWith('/'), isFalse);
        expect(path.contains(r'\'), isFalse);
      }
    });

    test('reads a top-level file', () async {
      expect(await store.readString('welcome.md'), contains('Welcome to BrainFrame'));
    });

    test('reads a nested file by its engram-relative path', () async {
      expect(
        await store.readString('notes/first-note.md'),
        contains('# Taking notes'),
      );
    });

    test('readBytes returns the raw bytes behind readString', () async {
      final bytes = await store.readBytes('welcome.md');
      expect(bytes, isA<Uint8List>());
      expect(utf8.decode(bytes), contains('Welcome to BrainFrame'));
    });

    test('is read-only: writeBytes and writeString throw UnsupportedError', () {
      expect(
        () => store.writeBytes('welcome.md', Uint8List(0)),
        throwsUnsupportedError,
      );
      expect(
        () => store.writeString('welcome.md', 'nope'),
        throwsUnsupportedError,
      );
    });

    test('is read-only: delete, move, createDirectory throw UnsupportedError',
        () {
      expect(() => store.delete('welcome.md'), throwsUnsupportedError);
      expect(() => store.move('welcome.md', 'moved.md'), throwsUnsupportedError);
      expect(() => store.createDirectory('folder'), throwsUnsupportedError);
    });

    test('is read-only: deleteDirectory throws UnsupportedError', () {
      expect(() => store.deleteDirectory('notes'), throwsUnsupportedError);
    });

    test('has no standalone directories: listDirectories is empty', () async {
      expect(await store.listDirectories(), isEmpty);
    });
  });

  group('AssetEngramStore over the bundled help engram', () {
    final store = AssetEngramStore(assetPrefix: 'assets/engrams/help/');

    test('lists only this engram\'s files, isolated by prefix', () async {
      expect(
        await store.list(),
        unorderedEquals(['index.md', 'markdown-syntax.md']),
      );
    });

    test('reads help content', () async {
      expect(await store.readString('index.md'), contains('BrainFrame help'));
    });
  });

  test('a missing trailing slash is normalized on', () async {
    final withSlash = AssetEngramStore(assetPrefix: 'assets/engrams/tutorial/');
    final withoutSlash = AssetEngramStore(assetPrefix: 'assets/engrams/tutorial');

    expect(withoutSlash.assetPrefix, 'assets/engrams/tutorial/');
    // Both spellings list and read the same content.
    expect(await withoutSlash.list(), unorderedEquals(await withSlash.list()));
    expect(
      await withoutSlash.readString('welcome.md'),
      contains('Welcome to BrainFrame'),
    );
  });

  test('a slash-terminated prefix is left unchanged', () {
    expect(
      AssetEngramStore(assetPrefix: 'assets/engrams/help/').assetPrefix,
      'assets/engrams/help/',
    );
  });
}
