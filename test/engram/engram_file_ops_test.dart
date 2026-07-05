import 'dart:typed_data';

import 'package:brainframe/engram/engram_file_ops.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [EngramStore] modeling files and explicit directories, faithful
/// enough to exercise folder composition: writing or moving a file registers
/// its parent directories, and directories can also exist with no files at all
/// (empty folders), just like the filesystem backend.
class _MemoryStore extends EngramStore {
  final Map<String, Uint8List> _files = {};
  final Set<String> _dirs = {};

  @override
  Future<List<String>> list() async => _files.keys.toList();

  @override
  Future<List<String>> listDirectories() async => _dirs.toList();

  @override
  Future<Uint8List> readBytes(String path) async {
    final bytes = _files[path];
    if (bytes == null) throw StateError('no such file: $path');
    return bytes;
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _files[path] = bytes;
    _registerParents(path);
  }

  @override
  Future<void> delete(String path) async {
    if (_files.remove(path) == null) throw StateError('no such file: $path');
  }

  @override
  Future<void> move(String from, String to) async {
    final bytes = _files.remove(from);
    if (bytes == null) throw StateError('no such file: $from');
    _files[to] = bytes;
    _registerParents(to);
  }

  @override
  Future<void> createDirectory(String path) async {
    _dirs.add(path);
    _registerParents(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    if (!_dirs.remove(path)) throw StateError('no such directory: $path');
  }

  void _registerParents(String path) {
    final parts = path.split('/');
    for (var i = 1; i < parts.length; i++) {
      _dirs.add(parts.sublist(0, i).join('/'));
    }
  }
}

void main() {
  group('EngramFileOps.moveFolder / renameFolder', () {
    test('renames a folder, carrying nested content', () async {
      final store = _MemoryStore();
      await store.writeString('notes/a.md', 'A');
      await store.writeString('notes/sub/b.md', 'B');

      await EngramFileOps(store).renameFolder('notes', 'ideas');

      expect(
        await store.list(),
        unorderedEquals(['ideas/a.md', 'ideas/sub/b.md']),
      );
      expect(await store.readString('ideas/a.md'), 'A');
      expect(await store.readString('ideas/sub/b.md'), 'B');
      final dirs = await store.listDirectories();
      expect(dirs, containsAll(['ideas', 'ideas/sub']));
      expect(dirs, isNot(contains('notes')));
      expect(dirs, isNot(contains('notes/sub')));
    });

    test('preserves an empty subfolder across a move', () async {
      final store = _MemoryStore();
      await store.writeString('notes/a.md', 'A');
      await store.createDirectory('notes/empty');

      await EngramFileOps(store).moveFolder('notes', 'archive/notes');

      expect(await store.list(), ['archive/notes/a.md']);
      final dirs = await store.listDirectories();
      expect(dirs, contains('archive/notes/empty'));
      expect(dirs.where((d) => d == 'notes' || d.startsWith('notes/')), isEmpty);
    });

    test('moves into a nested destination, creating its parents', () async {
      final store = _MemoryStore();
      await store.writeString('notes/a.md', 'A');

      await EngramFileOps(store).moveFolder('notes', 'a/b/c');

      expect(await store.list(), ['a/b/c/a.md']);
      expect(await store.readString('a/b/c/a.md'), 'A');
    });
  });

  group('EngramFileOps.deleteFolder', () {
    test('deletes a folder with all descendants and its dir shells', () async {
      final store = _MemoryStore();
      await store.writeString('notes/a.md', 'A');
      await store.writeString('notes/sub/b.md', 'B');
      await store.createDirectory('notes/empty');
      await store.writeString('keep.md', 'K');

      await EngramFileOps(store).deleteFolder('notes');

      expect(await store.list(), ['keep.md']);
      final dirs = await store.listDirectories();
      expect(
        dirs.where((d) => d == 'notes' || d.startsWith('notes/')),
        isEmpty,
      );
    });

    test('leaves a sibling folder with a shared name prefix untouched',
        () async {
      final store = _MemoryStore();
      await store.writeString('notes/a.md', 'A');
      await store.writeString('notes-archive/b.md', 'B');

      await EngramFileOps(store).deleteFolder('notes');

      expect(await store.list(), ['notes-archive/b.md']);
      expect(await store.listDirectories(), contains('notes-archive'));
    });
  });

  group('EngramFileOps.freeName', () {
    test('returns the desired name when no sibling uses it', () {
      expect(EngramFileOps.freeName('Untitled', {'Other'}), 'Untitled');
    });

    test('suffixes with the first free number on collision', () {
      expect(EngramFileOps.freeName('Untitled', {'Untitled'}), 'Untitled 2');
      expect(
        EngramFileOps.freeName('Untitled', {'Untitled', 'Untitled 2'}),
        'Untitled 3',
      );
    });

    test('returns the base when only a higher-numbered sibling exists', () {
      expect(EngramFileOps.freeName('Untitled', {'Untitled 2'}), 'Untitled');
    });
  });
}
