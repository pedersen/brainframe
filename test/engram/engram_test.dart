import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trivial in-memory store, standing in for the real backends that arrive in
/// later steps, so the [Engram] model can be exercised as pure Dart. It
/// implements only the byte primitives and inherits the UTF-8 text conveniences
/// from [EngramStore].
class _FakeStore extends EngramStore {
  final Map<String, Uint8List> files;

  _FakeStore(Map<String, String> initial)
      : files = {
          for (final entry in initial.entries)
            entry.key: Uint8List.fromList(utf8.encode(entry.value)),
        };

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<Uint8List> readBytes(String path) async => files[path]!;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      files[path] = bytes;
}

void main() {
  test('Engram carries identity and reaches content through its store', () async {
    final store = _FakeStore({'notes/a.md': '# A'});
    final engram = Engram(
      id: '01J9Z00000000000000000000Z',
      displayName: 'Personal',
      readOnly: false,
      store: store,
    );

    expect(engram.id, '01J9Z00000000000000000000Z');
    expect(engram.displayName, 'Personal');
    expect(engram.readOnly, isFalse);
    expect(await engram.store.list(), ['notes/a.md']);
    expect(await engram.store.readString('notes/a.md'), '# A');
  });

  test('readOnly is a property of the engram, independent of the store', () {
    final store = _FakeStore(const {});
    final builtin = Engram(
      id: 'builtin-help',
      displayName: 'Help',
      readOnly: true,
      store: store,
    );
    expect(builtin.readOnly, isTrue);
  });

  test('toString summarizes identity without leaking the store', () {
    final engram = Engram(
      id: 'abc',
      displayName: 'Personal',
      readOnly: true,
      store: _FakeStore(const {}),
    );
    expect(
      engram.toString(),
      'Engram(id: abc, displayName: Personal, readOnly: true)',
    );
  });
}
