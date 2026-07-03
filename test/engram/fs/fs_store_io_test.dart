import 'dart:io';

import 'package:brainframe/engram/fs/engram_location.dart';
import 'package:brainframe/engram/fs/fs_store_io.dart';
import 'package:brainframe/engram/id.dart';
import 'package:brainframe/engram/metadata.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('engram_fs_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EngramLocation locFor(String sub) => EngramLocation('${tempDir.path}/$sub');

  group('createFileSystemEngram', () {
    test('writes only the marker + engram.json, nothing else', () async {
      final loc = locFor('Personal');
      final engram =
          await createFileSystemEngram(location: loc, displayName: 'Personal');

      expect(engram.displayName, 'Personal');
      expect(engram.readOnly, isFalse);
      expect(isCanonicalUlid(engram.id), isTrue);

      // The folder holds exactly .brainframe/engram.json and nothing more.
      final entries = Directory(loc.path)
          .listSync(recursive: true)
          .map((e) => e.path.substring(loc.path.length + 1))
          .toSet();
      expect(entries, {'.brainframe', '.brainframe/engram.json'});

      // The marker round-trips through EngramMetadata with the engram's id.
      final meta = EngramMetadata.decode(
        await File('${loc.path}/.brainframe/engram.json').readAsString(),
      );
      expect(meta.id, engram.id);
      expect(meta.displayName, 'Personal');
      expect(meta.schemaVersion, EngramMetadata.currentSchemaVersion);
    });

    test('rejects an empty displayName', () {
      expect(
        () => createFileSystemEngram(location: locFor('x'), displayName: ''),
        throwsArgumentError,
      );
    });

    test('refuses to create over an existing engram', () async {
      final loc = locFor('Personal');
      await createFileSystemEngram(location: loc, displayName: 'Personal');
      expect(
        () => createFileSystemEngram(location: loc, displayName: 'Again'),
        throwsStateError,
      );
    });
  });

  group('content round-trips through the store', () {
    test('write, list (marker excluded), then read', () async {
      final engram = await createFileSystemEngram(
        location: locFor('Personal'),
        displayName: 'Personal',
      );
      final store = engram.store;

      await store.writeString('welcome.md', '# Welcome');
      await store.writeString('notes/first.md', '# First');

      expect(
        await store.list(),
        unorderedEquals(['welcome.md', 'notes/first.md']),
      );
      expect(await store.readString('welcome.md'), '# Welcome');
      expect(await store.readString('notes/first.md'), '# First');
    });

    test('overwrites an existing file', () async {
      final store = FileSystemEngramStore(locFor('e'));
      await store.writeString('a.md', 'one');
      await store.writeString('a.md', 'two');
      expect(await store.readString('a.md'), 'two');
    });

    test('round-trips arbitrary binary bytes without corruption', () async {
      final store = FileSystemEngramStore(locFor('e'));
      // A PNG signature plus bytes that are not valid UTF-8.
      final bytes =
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF, 0xFE, 0x10]);
      await store.writeBytes('assets/diagram.png', bytes);
      expect(await store.readBytes('assets/diagram.png'), bytes);
    });

    test('list is empty for a directory that does not exist yet', () async {
      expect(await FileSystemEngramStore(locFor('missing')).list(), isEmpty);
    });
  });

  group('path safety', () {
    late FileSystemEngramStore store;
    setUp(() => store = FileSystemEngramStore(locFor('e')));

    test('rejects absolute paths', () {
      expect(() => store.readString('/etc/passwd'), throwsArgumentError);
    });

    test('rejects parent-directory escapes', () {
      expect(() => store.writeString('../escape.md', 'x'), throwsArgumentError);
    });

    test('refuses to write the app-owned marker', () {
      expect(
        () => store.writeString('.brainframe/engram.json', '{}'),
        throwsArgumentError,
      );
    });
  });

  group('openFileSystemEngram', () {
    test('reopens a created engram with the same identity', () async {
      final loc = locFor('Personal');
      final created =
          await createFileSystemEngram(location: loc, displayName: 'Personal');
      final opened = await openFileSystemEngram(loc);
      expect(opened.id, created.id);
      expect(opened.displayName, 'Personal');
      expect(opened.readOnly, isFalse);
    });

    test('throws when there is no marker', () {
      expect(() => openFileSystemEngram(locFor('nope')), throwsStateError);
    });

    test('propagates a metadata error for a malformed marker', () async {
      final loc = locFor('broken');
      final metaFile = File('${loc.path}/.brainframe/engram.json');
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString('{ not json');
      expect(
        () => openFileSystemEngram(loc),
        throwsA(isA<EngramMetadataException>()),
      );
    });
  });

  group('openOrCreateFileSystemEngram', () {
    test('creates a fresh engram when the folder has no marker', () async {
      final loc = locFor('Fresh');
      final engram = await openOrCreateFileSystemEngram(
        loc,
        displayName: 'Fresh',
      );
      expect(engram.displayName, 'Fresh');
      expect(engram.readOnly, isFalse);
      expect(
        File('${loc.path}/.brainframe/engram.json').existsSync(),
        isTrue,
      );
    });

    test('opens an existing engram and keeps its identity, ignoring displayName',
        () async {
      final loc = locFor('Existing');
      final created =
          await createFileSystemEngram(location: loc, displayName: 'Existing');
      final opened =
          await openOrCreateFileSystemEngram(loc, displayName: 'Ignored');
      expect(opened.id, created.id);
      expect(opened.displayName, 'Existing');
    });

    test('propagates a metadata error for a malformed existing marker',
        () async {
      final loc = locFor('broken');
      final metaFile = File('${loc.path}/.brainframe/engram.json');
      await metaFile.parent.create(recursive: true);
      await metaFile.writeAsString('{ not json');
      expect(
        () => openOrCreateFileSystemEngram(loc, displayName: 'x'),
        throwsA(isA<EngramMetadataException>()),
      );
    });
  });

  group('applicationEngramContainerPath', () {
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('returns the documents directory from path_provider', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'getApplicationDocumentsDirectory' ? '/fake/docs' : null,
      );
      expect(await applicationEngramContainerPath(), '/fake/docs');
    });
  });

  group('discoverContainerEngrams', () {
    test('opens children with valid markers, ignores plain folders', () async {
      await createFileSystemEngram(
        location: EngramLocation('${tempDir.path}/A'),
        displayName: 'A',
      );
      await Directory('${tempDir.path}/plain').create();

      final found = await discoverContainerEngrams(tempDir.path);
      expect(found.map((e) => e.displayName), ['A']);
    });

    test('skips a child with a malformed marker without crashing', () async {
      final bad = File('${tempDir.path}/B/.brainframe/engram.json');
      await bad.parent.create(recursive: true);
      await bad.writeAsString('{ not json');
      await createFileSystemEngram(
        location: EngramLocation('${tempDir.path}/A'),
        displayName: 'A',
      );

      final found = await discoverContainerEngrams(tempDir.path);
      expect(found.map((e) => e.displayName), ['A']);
    });

    test('returns empty for a non-existent container', () async {
      expect(
        await discoverContainerEngrams('${tempDir.path}/missing'),
        isEmpty,
      );
    });
  });

  group('createContainerEngram', () {
    test('derives a folder from the display name', () async {
      final engram = await createContainerEngram(tempDir.path, 'Personal');
      expect(
        Directory('${tempDir.path}/Personal/.brainframe').existsSync(),
        isTrue,
      );
      expect(engram.displayName, 'Personal');
    });

    test('avoids collisions with an existing sibling', () async {
      await createContainerEngram(tempDir.path, 'Personal');
      await createContainerEngram(tempDir.path, 'Personal');
      expect(
        Directory('${tempDir.path}/Personal 2/.brainframe').existsSync(),
        isTrue,
      );
    });

    test('sanitizes path separators and falls back for a blank name', () async {
      await createContainerEngram(tempDir.path, 'Notes/2024');
      expect(
        Directory('${tempDir.path}/Notes-2024/.brainframe').existsSync(),
        isTrue,
      );
      await createContainerEngram(tempDir.path, '   ');
      expect(
        Directory('${tempDir.path}/Engram/.brainframe').existsSync(),
        isTrue,
      );
    });
  });
}
