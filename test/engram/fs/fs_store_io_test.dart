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
}
