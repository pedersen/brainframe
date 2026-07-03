import 'dart:io';

import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/fs/fs_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late String containerPath;
  late SharedPreferencesAsync prefs;

  EngramRepository repoWith({Future<String> Function()? container}) =>
      EngramRepository(
        preferences: prefs,
        containerPathResolver: container ?? () async => containerPath,
      );

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('engram_repo_test');
    containerPath = '${tempRoot.path}/container';
    await Directory(containerPath).create(recursive: true);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  tearDown(() async {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  group('built-ins', () {
    test('discovery always surfaces the two read-only built-ins', () async {
      final discovery = await repoWith().discover();
      expect(
        discovery.available.map((e) => e.id),
        containsAll([builtinTutorialId, builtinHelpId]),
      );
      expect(
        discovery.available
            .where((e) => isBuiltInEngramId(e.id))
            .every((e) => e.readOnly),
        isTrue,
      );
      expect(discovery.unavailable, isEmpty);
    });

    test('built-in stores read bundled content', () async {
      final discovery = await repoWith().discover();
      final tutorial =
          discovery.available.firstWhere((e) => e.id == builtinTutorialId);
      expect(
        await tutorial.store.readString('welcome.md'),
        contains('Welcome'),
      );
    });

    test('built-ins cannot be forgotten', () {
      expect(() => repoWith().forget(builtinHelpId), throwsArgumentError);
    });
  });

  group('create and container discovery', () {
    test('create places an engram in the container and discovery finds it',
        () async {
      final repo = repoWith();
      final created = await repo.create('Personal');
      expect(created.readOnly, isFalse);

      final discovery = await repo.discover();
      expect(
        discovery.available
            .any((e) => e.id == created.id && e.displayName == 'Personal'),
        isTrue,
      );
    });

    test('rejects a blank display name', () {
      expect(() => repoWith().create('   '), throwsArgumentError);
    });

    test('discovers an engram created directly in the container', () async {
      await createFileSystemEngram(
        location: EngramLocation('$containerPath/Manual'),
        displayName: 'Manual',
      );
      final discovery = await repoWith().discover();
      expect(discovery.available.any((e) => e.displayName == 'Manual'), isTrue);
    });

    test('a throwing container resolver degrades to built-ins only', () async {
      final repo = repoWith(container: () async => throw UnsupportedError('no fs'));
      final discovery = await repo.discover();
      expect(
        discovery.available.map((e) => e.id),
        unorderedEquals([builtinTutorialId, builtinHelpId]),
      );
    });
  });

  group('registry: adopt, forget, persistence', () {
    late String externalPath;

    setUp(() async {
      externalPath = '${tempRoot.path}/external';
      await createFileSystemEngram(
        location: EngramLocation(externalPath),
        displayName: 'External',
      );
    });

    test('adopt registers an out-of-container engram; discovery includes it',
        () async {
      final repo = repoWith();
      final adopted = await repo.adopt(EngramLocation(externalPath));
      final discovery = await repo.discover();
      expect(discovery.available.any((e) => e.id == adopted.id), isTrue);
    });

    test('the registry persists across repository instances', () async {
      await repoWith().adopt(EngramLocation(externalPath));
      final discovery = await repoWith().discover();
      expect(discovery.available.any((e) => e.displayName == 'External'), isTrue);
    });

    test('forget removes an adopted engram from discovery', () async {
      final repo = repoWith();
      final adopted = await repo.adopt(EngramLocation(externalPath));
      await repo.forget(adopted.id);
      final discovery = await repo.discover();
      expect(discovery.available.any((e) => e.id == adopted.id), isFalse);
    });

    test('a deleted root becomes reconnectable-unavailable, not gone', () async {
      final repo = repoWith();
      final adopted = await repo.adopt(EngramLocation(externalPath));
      Directory(externalPath).deleteSync(recursive: true);

      final gone = await repo.discover();
      expect(gone.available.any((e) => e.id == adopted.id), isFalse);
      expect(
        gone.unavailable
            .any((u) => u.id == adopted.id && u.displayName == 'External'),
        isTrue,
      );

      // Still registered — it reconnects when the folder returns.
      await createFileSystemEngram(
        location: EngramLocation(externalPath),
        displayName: 'External',
      );
      final back = await repo.discover();
      expect(back.available.any((e) => e.displayName == 'External'), isTrue);
    });

    test('adoptFolder turns a plain folder into a registered engram', () async {
      final plainPath = '${tempRoot.path}/Journal';
      await Directory(plainPath).create(recursive: true);

      final repo = repoWith();
      final adopted = await repo.adoptFolder(EngramLocation(plainPath));
      expect(adopted.readOnly, isFalse);
      expect(adopted.displayName, 'Journal'); // derived from the folder name
      expect(
        File('$plainPath/.brainframe/engram.json').existsSync(),
        isTrue,
      );

      final discovery = await repo.discover();
      expect(discovery.available.any((e) => e.id == adopted.id), isTrue);
    });

    test('adoptFolder honours an explicit display name', () async {
      final plainPath = '${tempRoot.path}/raw-folder';
      await Directory(plainPath).create(recursive: true);
      final adopted = await repoWith()
          .adoptFolder(EngramLocation(plainPath), displayName: 'My Notes');
      expect(adopted.displayName, 'My Notes');
    });

    test('adoptFolder opens an existing engram without a second registry row',
        () async {
      final repo = repoWith();
      final first = await repo.adoptFolder(EngramLocation(externalPath));
      // Re-adopting the same, now-marked folder keeps its identity and does not
      // duplicate the registry entry.
      final second = await repo.adoptFolder(EngramLocation(externalPath));
      expect(second.id, first.id);
      expect(second.displayName, 'External');

      final discovery = await repo.discover();
      expect(
        discovery.available.where((e) => e.id == first.id).length,
        1,
      );
    });

    test('a corrupt registry line is skipped, not fatal', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
        'engram.registry.v1': ['{ not json', '{"id":"x"}'],
      });
      prefs = SharedPreferencesAsync();
      final discovery = await repoWith().discover();
      expect(
        discovery.available.map((e) => e.id),
        containsAll([builtinTutorialId, builtinHelpId]),
      );
    });
  });

  group('lastOpened', () {
    test('is null before anything is set', () async {
      expect(await repoWith().lastOpened, isNull);
    });

    test('resolves a container engram by id', () async {
      final repo = repoWith();
      final created = await repo.create('Personal');
      await repo.setLastOpened(created.id);
      expect((await repo.lastOpened)?.id, created.id);
    });

    test('resolves a built-in and survives a new instance', () async {
      await repoWith().setLastOpened(builtinHelpId);
      expect((await repoWith().lastOpened)?.id, builtinHelpId);
    });

    test('returns null when the id no longer resolves', () async {
      await repoWith().setLastOpened('nonexistent-id');
      expect(await repoWith().lastOpened, isNull);
    });
  });

  group('openInitialEngram', () {
    test('opens the built-in tutorial on a true first run', () async {
      final engram = await repoWith().openInitialEngram();
      expect(engram.id, builtinTutorialId);
      expect(engram.readOnly, isTrue);
    });

    test('reopens the last-opened engram when one still resolves', () async {
      final repo = repoWith();
      final created = await repo.create('Personal');
      await repo.setLastOpened(created.id);
      expect((await repo.openInitialEngram()).id, created.id);
    });

    test('falls back to the tutorial when the last-opened id is gone',
        () async {
      await repoWith().setLastOpened('nonexistent-id');
      expect((await repoWith().openInitialEngram()).id, builtinTutorialId);
    });
  });
}
