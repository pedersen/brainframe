import 'package:brainframe/engram/ui/browser_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late BrowserPreferences prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = BrowserPreferences(SharedPreferencesAsync());
  });

  group('sidebar width', () {
    test('is null until set, then round-trips', () async {
      expect(await prefs.sidebarWidth(), isNull);
      await prefs.setSidebarWidth(312.5);
      expect(await prefs.sidebarWidth(), 312.5);
    });
  });

  group('collapsed folders', () {
    test('defaults to empty for an unknown engram', () async {
      expect(await prefs.collapsedFolders('engram-a'), isEmpty);
    });

    test('round-trips a set of folder paths', () async {
      await prefs.setCollapsedFolders('engram-a', {'notes', 'notes/drafts'});
      expect(
        await prefs.collapsedFolders('engram-a'),
        {'notes', 'notes/drafts'},
      );
    });

    test('is keyed per engram — one engram does not leak into another',
        () async {
      await prefs.setCollapsedFolders('engram-a', {'notes'});
      expect(await prefs.collapsedFolders('engram-b'), isEmpty);

      await prefs.setCollapsedFolders('engram-b', {'archive'});
      expect(await prefs.collapsedFolders('engram-a'), {'notes'});
      expect(await prefs.collapsedFolders('engram-b'), {'archive'});
    });

    test('an emptied set clears back to empty', () async {
      await prefs.setCollapsedFolders('engram-a', {'notes'});
      await prefs.setCollapsedFolders('engram-a', <String>{});
      expect(await prefs.collapsedFolders('engram-a'), isEmpty);
    });
  });
}
