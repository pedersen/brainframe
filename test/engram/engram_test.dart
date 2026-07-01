import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trivial in-memory store, standing in for the real backends that arrive in
/// later steps, so the [Engram] model can be exercised as pure Dart.
class _FakeStore implements EngramStore {
  final Map<String, String> files;

  _FakeStore(this.files);

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<String> readString(String path) async => files[path]!;

  @override
  Future<void> writeString(String path, String contents) async =>
      files[path] = contents;
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
