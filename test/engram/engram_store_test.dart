import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal read-only backend that implements only the abstract members and
/// inherits [EngramStore]'s default mutation behavior, so this exercises the
/// base-class defaults rather than any backend's overrides.
class _ReadOnlyStore extends EngramStore {
  _ReadOnlyStore(this._files);
  final Map<String, String> _files;

  @override
  Future<List<String>> list() async => _files.keys.toList();

  @override
  Future<Uint8List> readBytes(String path) async =>
      Uint8List.fromList(utf8.encode(_files[path]!));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      throw UnsupportedError('read-only');
}

void main() {
  group('EngramStore default mutations are read-only', () {
    final store = _ReadOnlyStore({'a.md': '# A'});

    test('delete throws UnsupportedError by default', () {
      expect(() => store.delete('a.md'), throwsUnsupportedError);
    });

    test('move throws UnsupportedError by default', () {
      expect(() => store.move('a.md', 'b.md'), throwsUnsupportedError);
    });

    test('createDirectory throws UnsupportedError by default', () {
      expect(() => store.createDirectory('folder'), throwsUnsupportedError);
    });

    test('deleteDirectory throws UnsupportedError by default', () {
      expect(() => store.deleteDirectory('folder'), throwsUnsupportedError);
    });
  });

  test('listDirectories defaults to none for backends without directories',
      () async {
    expect(await _ReadOnlyStore({'a.md': '# A'}).listDirectories(), isEmpty);
  });

  test('readString/writeString are conveniences over the byte methods',
      () async {
    final store = _ReadOnlyStore({'a.md': '# A'});
    expect(await store.readString('a.md'), '# A');
    // writeString funnels through the read-only writeBytes.
    expect(() => store.writeString('a.md', 'x'), throwsUnsupportedError);
  });
}
