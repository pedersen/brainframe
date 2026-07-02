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

    test('is read-only: writeString throws UnsupportedError', () {
      expect(
        () => store.writeString('welcome.md', 'nope'),
        throwsUnsupportedError,
      );
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

  test('assetPrefix must end with a slash', () {
    expect(
      () => AssetEngramStore(assetPrefix: 'assets/engrams/tutorial'),
      throwsA(isA<AssertionError>()),
    );
  });
}
