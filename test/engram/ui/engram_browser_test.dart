import 'dart:convert';
import 'dart:io';

import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:brainframe/engram/engram_scope.dart';
import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/ui/browser_preferences.dart';
import 'package:brainframe/engram/ui/engram_browser.dart';
import 'package:brainframe/engram/ui/markdown_editor_pane.dart';
import 'package:brainframe/engram/ui/markdown_reader.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/localized_app.dart';

void main() {
  late Directory tempRoot;

  EngramRepository repo() => EngramRepository(
        preferences: SharedPreferencesAsync(),
        containerPathResolver: () async => '${tempRoot.path}/container',
      );

  Engram tutorial() =>
      builtInEngrams().firstWhere((e) => e.id == builtinTutorialId);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('browser_test');
    await Directory('${tempRoot.path}/container').create(recursive: true);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() async {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  // Force the Material design language so the scaffold is deterministic.
  Widget harnessFor(
    EngramRepository repository,
    Engram engram, {
    EngramBrowserController? controller,
  }) =>
      AppSettings(
        designOverride: DesignLanguage.material,
        child: localizedApp(
          home: EngramScope(
            initialEngram: engram,
            child: EngramBrowser(repository: repository, controller: controller),
          ),
        ),
      );

  Widget harness(EngramRepository repository) =>
      harnessFor(repository, tutorial());

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('wide layout shows no menu button; narrow shows one',
      (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open file browser'), findsNothing);

    setWidth(tester, 400);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open file browser'), findsOneWidget);
  });

  testWidgets('the help action opens the peek overlay without switching engrams',
      (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    // The help overlay is up, reading the help engram's index…
    expect(find.text('index.md'), findsOneWidget);
    expect(
      find.textContaining('BrainFrame help', findRichText: true),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Close help'));
    await tester.pumpAndSettle();
    // …and the browser is still on the tutorial (footer unchanged).
    expect(find.text('Tutorial'), findsOneWidget);
  });

  testWidgets('on a phone, opening the drawer and picking a file reads it',
      (tester) async {
    setWidth(tester, 400);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open file browser'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('first-note.md'));
    await tester.pumpAndSettle();

    expect(find.text('notes/first-note.md'), findsOneWidget); // breadcrumb
  });

  testWidgets('wide layout renders the reader content top-aligned',
      (tester) async {
    // A tall window makes vertical centering obvious if it regresses.
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    // The breadcrumb lives inside the reader (the app-bar title and the
    // sidebar file row are the other "welcome.md"s). Scope to the reader, then
    // check it sits near the top, not centered.
    final breadcrumb = find.descendant(
      of: find.byType(MarkdownReader),
      matching: find.text('welcome.md'),
    );
    expect(breadcrumb, findsOneWidget);
    expect(tester.getTopLeft(breadcrumb).dy, lessThan(200),
        reason: 'reader content should be top-aligned, not vertically centered');
  });

  testWidgets('hides dotfiles and dot-directories from the tree',
      (tester) async {
    setWidth(tester, 1000);
    final engram = Engram(
      id: 'dotty',
      displayName: 'Dotty',
      readOnly: false,
      store: _DotStore(),
    );
    await tester.pumpWidget(harnessFor(repo(), engram));
    await tester.pumpAndSettle();

    expect(find.text('welcome.md'), findsWidgets); // visible file
    expect(find.text('notes'), findsOneWidget); // visible folder
    expect(find.text('.hidden.md'), findsNothing);
    expect(find.text('.git'), findsNothing);
  });

  // The resize handle sits at the sidebar's right edge, so its left x-offset
  // equals the current sidebar width.
  Finder resizeHandle() => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Resize file browser',
        description: 'sidebar resize handle',
      );

  testWidgets('the resize divider appears only in the side-by-side layout',
      (tester) async {
    setWidth(tester, 1000); // wide
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(resizeHandle(), findsOneWidget);

    setWidth(tester, 400); // drawer
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();
    expect(resizeHandle(), findsNothing);
  });

  testWidgets('dragging the divider resizes the sidebar and saves the width',
      (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    // Default width before any drag.
    expect(tester.getTopLeft(resizeHandle()).dx, closeTo(260, 1));

    // Drag the divider right; the sidebar widens (minus the recognizer's touch
    // slop, so we assert direction, not an exact pixel count).
    await tester.drag(resizeHandle(), const Offset(120, 0));
    await tester.pumpAndSettle();
    final widthAfter = tester.getTopLeft(resizeHandle()).dx;
    expect(widthAfter, greaterThan(300));

    // The width persisted on drag-end matches exactly what is shown.
    final prefs = BrowserPreferences(SharedPreferencesAsync());
    expect(await prefs.sidebarWidth(), closeTo(widthAfter, 1));
  });

  testWidgets('a saved sidebar width is restored on launch', (tester) async {
    await BrowserPreferences(SharedPreferencesAsync()).setSidebarWidth(420);

    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(resizeHandle()).dx, closeTo(420, 1));
  });

  testWidgets(
      'collapsing a folder persists to device state and restores on relaunch',
      (tester) async {
    setWidth(tester, 1000);
    final engram = Engram(
      id: 'dotty',
      displayName: 'Dotty',
      readOnly: false,
      store: _DotStore(),
    );

    await tester.pumpWidget(harnessFor(repo(), engram));
    await tester.pumpAndSettle();
    expect(find.text('first.md'), findsOneWidget); // starts expanded

    await tester.tap(find.text('notes'));
    await tester.pumpAndSettle();
    expect(find.text('first.md'), findsNothing); // collapsed live

    // Saved to device-local preferences, keyed by engram id — not to the store.
    final prefs = BrowserPreferences(SharedPreferencesAsync());
    expect(await prefs.collapsedFolders('dotty'), {'notes'});

    // Tear the tree down, then rebuild fresh so state must come from prefs.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harnessFor(repo(), engram));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('first.md'), findsNothing); // restored collapsed
  });

  testWidgets('the resize handle is an operable slider for assistive tech',
      (tester) async {
    final semantics = tester.ensureSemantics();
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(resizeHandle());
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.label, 'Resize file browser');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);

    // Increase then decrease adjust the sidebar in opposite directions.
    final start = tester.getTopLeft(resizeHandle()).dx;
    // ignore: deprecated_member_use
    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    owner.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();
    final widened = tester.getTopLeft(resizeHandle()).dx;
    expect(widened, greaterThan(start));

    owner.performAction(node.id, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(resizeHandle()).dx, lessThan(widened));

    // The last adjustment was saved to device-local preferences.
    expect(
      await BrowserPreferences(SharedPreferencesAsync()).sidebarWidth(),
      isNotNull,
    );

    semantics.dispose();
  });

  testWidgets('the divider can be resized from the keyboard', (tester) async {
    setWidth(tester, 1000);
    await tester.pumpWidget(harness(repo()));
    await tester.pumpAndSettle();

    // Focus the handle, then nudge it wider with the right arrow key. The
    // handle's FocusNode is reachable via Focus.of from a context beneath it.
    final gestureContext = tester.element(
      find.descendant(of: resizeHandle(), matching: find.byType(GestureDetector)),
    );
    final before = tester.getTopLeft(resizeHandle()).dx;
    Focus.of(gestureContext).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(resizeHandle()).dx, greaterThan(before));
  });

  group('editing gate', () {
    testWidgets('a read-only engram shows the reader with no edit affordances',
        (tester) async {
      setWidth(tester, 1000);
      await tester.pumpWidget(harness(repo())); // tutorial: read-only asset engram
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownReader), findsOneWidget);
      expect(find.byType(MarkdownEditorPane), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a writable engram opens the editor and saves edits',
        (tester) async {
      setWidth(tester, 1000);
      final store = _RwStore({'welcome.md': '# Welcome'});
      final engram = Engram(
        id: 'writable',
        displayName: 'My Notes',
        readOnly: false,
        store: store,
      );
      await tester.pumpWidget(harnessFor(repo(), engram));
      await tester.pumpAndSettle();

      // The editor pane (not the plain reader) is shown for a writable file.
      expect(find.byType(MarkdownEditorPane), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      // Edit → status goes to unsaved → manual save → back to saved.
      await tester.enterText(find.byType(TextField), '# Welcome edited');
      await tester.pump();
      expect(find.text('Unsaved changes'), findsOneWidget);

      await tester.tap(find.text('Unsaved changes'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);

      // …and the change reached the store the whole way through the browser.
      expect(store.files['welcome.md'], '# Welcome edited');
    });
  });

  group('re-list seam (EngramBrowserController)', () {
    Engram engramFor(EngramStore store) => Engram(
          id: 'w',
          displayName: 'W',
          readOnly: false,
          store: store,
        );

    testWidgets('refresh re-lists the engram and selects a new file',
        (tester) async {
      setWidth(tester, 1000);
      final store = _RwStore({'welcome.md': '# Welcome'});
      final controller = EngramBrowserController();
      await tester.pumpWidget(
        harnessFor(repo(), engramFor(store), controller: controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('new.md'), findsNothing); // not there yet

      // Simulate a "new note" mutation on the store, then invalidate.
      store.files['notes/new.md'] = '# New note';
      controller.refresh(selectPath: 'notes/new.md');
      await tester.pumpAndSettle();

      // The new file is listed in the tree and is now the open selection.
      expect(find.text('new.md'), findsWidgets); // tree row
      final pane =
          tester.widget<MarkdownEditorPane>(find.byType(MarkdownEditorPane));
      expect(pane.path, 'notes/new.md');
    });

    testWidgets('refresh after a delete falls back to a default selection',
        (tester) async {
      setWidth(tester, 1000);
      final store = _RwStore({'welcome.md': '# Welcome', 'note.md': '# Note'});
      final controller = EngramBrowserController();
      await tester.pumpWidget(
        harnessFor(repo(), engramFor(store), controller: controller),
      );
      await tester.pumpAndSettle();

      // Open note.md, then delete it out from under the browser.
      await tester.tap(find.text('note.md'));
      await tester.pumpAndSettle();
      store.files.remove('note.md');
      controller.refresh();
      await tester.pumpAndSettle();

      // The deleted file is gone; the selection falls back to welcome.md.
      expect(find.text('note.md'), findsNothing);
      expect(find.text('welcome.md'), findsWidgets);
    });

    testWidgets('a detached controller is inert', (tester) async {
      setWidth(tester, 1000);
      final store = _RwStore({'welcome.md': '# W'});
      final controller = EngramBrowserController();
      await tester.pumpWidget(
        harnessFor(repo(), engramFor(store), controller: controller),
      );
      await tester.pumpAndSettle();

      // Re-pump the same browser without a controller: didUpdateWidget detaches
      // the old one, so refresh() becomes a no-op rather than reaching a dead
      // state.
      await tester.pumpWidget(harnessFor(repo(), engramFor(store)));
      await tester.pumpAndSettle();
      controller.refresh(selectPath: 'anything.md'); // must not throw
      await tester.pumpAndSettle();
    });
  });

  group('new note', () {
    // AlertDialog.adaptive renders the Cupertino variant (CupertinoTextField)
    // on Apple platforms; the reset keeps this override from leaking.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Engram writable(EngramStore store) =>
        Engram(id: 'w', displayName: 'W', readOnly: false, store: store);

    // The dialog's field, distinct from the editor pane's own TextField.
    Finder dialogField() => find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));

    // Pump the browser over a writable [store]. The platform is forced Material
    // *before* pumping so the MaterialApp theme bakes it in and AlertDialog uses
    // a plain TextField; once baked, the override is reset (testWidgets checks
    // foundation debug vars are unset before tearDown runs).
    Future<void> pumpBrowser(WidgetTester tester, EngramStore store) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      setWidth(tester, 1000);
      await tester.pumpWidget(harnessFor(repo(), writable(store)));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byTooltip('New note'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog transition
    }

    testWidgets('a read-only engram shows no New note action', (tester) async {
      setWidth(tester, 1000);
      await tester.pumpWidget(harness(repo())); // tutorial: read-only
      await tester.pumpAndSettle();
      expect(find.byTooltip('New note'), findsNothing);
    });

    testWidgets('creates a note with a derived H1 and opens it in the editor',
        (tester) async {
      final store = _RwStore({}); // empty writable engram
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'My Great Idea');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.files['My Great Idea.md'], '# My Great Idea\n');
      final pane =
          tester.widget<MarkdownEditorPane>(find.byType(MarkdownEditorPane));
      expect(pane.path, 'My Great Idea.md');
    });

    testWidgets('title-cases an H1 from a dashed name', (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'the-beginning-of-infinity');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.files['the-beginning-of-infinity.md'],
          '# The Beginning Of Infinity\n');
    });

    testWidgets('a blank name falls back to Untitled', (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), '   ');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.files['Untitled.md'], '# Untitled\n');
    });

    testWidgets('avoids colliding with an existing note', (tester) async {
      final store = _RwStore({'Note.md': '# Note'});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Note');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.files['Note 2.md'], '# Note 2\n');
    });

    testWidgets('submitting from the keyboard creates the note',
        (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Keyboard Note');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(store.files['Keyboard Note.md'], '# Keyboard Note\n');
    });

    testWidgets('Cancel creates nothing', (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Nope');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.files, isEmpty);
    });
  });

  group('new folder', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Engram writable(EngramStore store) =>
        Engram(id: 'w', displayName: 'W', readOnly: false, store: store);

    Finder dialogField() => find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));

    Future<void> pumpBrowser(WidgetTester tester, EngramStore store) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      setWidth(tester, 1000);
      await tester.pumpWidget(harnessFor(repo(), writable(store)));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byTooltip('New folder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a read-only engram shows no New folder action', (tester) async {
      setWidth(tester, 1000);
      await tester.pumpWidget(harness(repo())); // tutorial: read-only
      await tester.pumpAndSettle();
      expect(find.byTooltip('New folder'), findsNothing);
    });

    testWidgets('an empty folder from listDirectories shows in the tree',
        (tester) async {
      final store = _RwStore({'welcome.md': '# W'}, directories: {'ideas'});
      await pumpBrowser(tester, store);

      // No file lives in it, yet the folder row is present.
      expect(find.text('ideas'), findsOneWidget);
    });

    testWidgets('creates an empty folder that appears in the tree',
        (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Ideas');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.dirs, contains('Ideas'));
      expect(find.text('Ideas'), findsOneWidget); // now visible in the tree
    });

    testWidgets('avoids colliding with an existing folder', (tester) async {
      final store = _RwStore({}, directories: {'Ideas'});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Ideas');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(store.dirs, contains('Ideas 2'));
    });

    testWidgets('Cancel creates nothing', (tester) async {
      final store = _RwStore({});
      await pumpBrowser(tester, store);

      await openDialog(tester);
      await tester.enterText(dialogField(), 'Nope');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.dirs, isEmpty);
    });
  });
}

/// An in-memory read-write store for the editing/file-management tests. Tracks
/// files and directories (including empty ones), the latter surfaced through
/// [listDirectories] like the filesystem backend.
class _RwStore extends EngramStore {
  _RwStore(this.files, {Set<String>? directories})
      : dirs = directories ?? <String>{};
  final Map<String, String> files;
  final Set<String> dirs;

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<List<String>> listDirectories() async => dirs.toList();

  @override
  Future<Uint8List> readBytes(String path) async =>
      Uint8List.fromList(utf8.encode(files[path]!));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      files[path] = utf8.decode(bytes);

  @override
  Future<void> createDirectory(String path) async {
    dirs.add(path);
    final segments = path.split('/');
    for (var i = 1; i < segments.length; i++) {
      dirs.add(segments.sublist(0, i).join('/'));
    }
  }
}

/// A store with a mix of visible and hidden entries.
class _DotStore extends EngramStore {
  @override
  Future<List<String>> list() async => [
        'welcome.md',
        '.hidden.md',
        '.git/config',
        'notes/first.md',
      ];

  @override
  Future<Uint8List> readBytes(String path) async =>
      Uint8List.fromList(utf8.encode('# $path'));

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}
