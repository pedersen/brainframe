import 'package:brainframe/app.dart';
import 'package:brainframe/engram/built_in_engrams.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  // No filesystem container in a plain widget test: the resolver throws, so
  // discovery degrades to the built-ins and startup opens the tutorial.
  BrainFrameApp app() => BrainFrameApp(
        repository: EngramRepository(
          preferences: SharedPreferencesAsync(),
          containerPathResolver: () async =>
              throw UnsupportedError('no filesystem in widget tests'),
        ),
      );

  testWidgets('opens into the tutorial engram browser on first run',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle(); // resolve the startup engram + list its files

    // The sidebar footer names the active engram; the tutorial's files show.
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget); // the notes/ folder
    // "welcome.md" appears as the app-bar title, a tree row, and the breadcrumb.
    expect(find.text('welcome.md'), findsWidgets);

    // The reader renders welcome.md's content (rich text from Markdown).
    expect(
      find.textContaining('Welcome to BrainFrame', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('resolveInitialEngram override wins over the repository default',
      (tester) async {
    // Mirrors how `main` supplies the --engram override: a resolver passed to
    // BrainFrameApp is used instead of the repository's last-opened/tutorial
    // logic. Here it opens the Help built-in, so the browser shows Help, not
    // the Tutorial the default would pick.
    await tester.pumpWidget(BrainFrameApp(
      repository: EngramRepository(
        preferences: SharedPreferencesAsync(),
        containerPathResolver: () async =>
            throw UnsupportedError('no filesystem in widget tests'),
      ),
      resolveInitialEngram: () async => builtInHelpEngram(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Tutorial'), findsNothing);
  });

  testWidgets('window title resolves through AppLocalizations', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // MaterialApp feeds onGenerateTitle's result into a Title widget; finding
    // 'BrainFrame' there proves the title is sourced from AppLocalizations, not
    // a hardcoded string.
    final title = tester.widget<Title>(find.byType(Title));
    expect(title.title, 'BrainFrame');
  });

  testWidgets('selecting a file opens it in the reader', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // The notes/ folder is expanded by default, so its file is visible.
    await tester.tap(find.text('first-note.md'));
    await tester.pumpAndSettle();

    expect(find.text('notes/first-note.md'), findsOneWidget); // breadcrumb
    expect(
      find.textContaining('Taking notes', findRichText: true),
      findsWidgets,
    );
  });
}
