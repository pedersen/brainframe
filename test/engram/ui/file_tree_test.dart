import 'package:brainframe/engram/ui/file_tree.dart';
import 'package:brainframe/engram/ui/file_tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

Widget _host(Widget child) =>
    localizedApp(home: Scaffold(body: SizedBox(width: 280, child: child)));

void main() {
  testWidgets('renders folders and files; folders start expanded',
      (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['welcome.md', 'notes/first.md']),
      selectedPath: null,
      onSelectFile: (_) {},
    )));

    expect(find.text('welcome.md'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('first.md'), findsOneWidget); // visible: expanded default
  });

  testWidgets('folder and file rows carry localized semantics labels',
      (tester) async {
    // Exercises the placeholder-bearing AppLocalizations getters
    // (fileTreeFolder/fileTreeFile) end to end: the English ARB interpolates
    // the node name into the accessibility label a screen reader announces.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['welcome.md', 'notes/first.md']),
      selectedPath: null,
      onSelectFile: (_) {},
    )));

    // RegExp (substring) match: the row merges the localized label with the
    // child filename text, so the effective label contains, not equals, it.
    expect(find.bySemanticsLabel(RegExp('Folder notes')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('File welcome.md')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping a folder collapses and expands it', (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['notes/first.md']),
      selectedPath: null,
      onSelectFile: (_) {},
    )));

    expect(find.text('first.md'), findsOneWidget);
    await tester.tap(find.text('notes'));
    await tester.pumpAndSettle();
    expect(find.text('first.md'), findsNothing); // collapsed

    await tester.tap(find.text('notes'));
    await tester.pumpAndSettle();
    expect(find.text('first.md'), findsOneWidget); // expanded again
  });

  testWidgets('tapping a file reports its full path', (tester) async {
    String? tapped;
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['notes/first.md']),
      selectedPath: null,
      onSelectFile: (path) => tapped = path,
    )));

    await tester.tap(find.text('first.md'));
    expect(tapped, 'notes/first.md');
  });

  testWidgets('the selected file is marked selected for assistive tech',
      (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['welcome.md']),
      selectedPath: 'welcome.md',
      onSelectFile: (_) {},
    )));

    final row = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'File welcome.md');
    expect(row.properties.selected, isTrue);
    expect(row.properties.button, isTrue);
  });

  testWidgets('a long file name is not clipped and can scroll horizontally',
      (tester) async {
    const longName =
        'a-very-long-file-name-that-overflows-the-narrow-sidebar.md';
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree([longName]),
      selectedPath: null,
      onSelectFile: (_) {},
    )));

    // The full name is laid out (no ellipsis truncation).
    final text = tester.widget<Text>(find.text(longName));
    expect(text.overflow, isNot(TextOverflow.ellipsis));

    // Its row extends past the 280px sidebar, so the horizontal scroll view is
    // actually scrollable rather than clamping the name to the visible width.
    final horizontal = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate((w) =>
          w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
    );
    final controller = horizontal.controller!;
    expect(controller.position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('large engrams are virtualized: only visible rows are built',
      (tester) async {
    // A thousand files in a ~600px-tall viewport: a lazy list builds only the
    // handful on screen, not all thousand. Guards against a regression back to
    // an eager Column (which laid every row out on every frame).
    final files = [for (var i = 0; i < 1000; i++) 'note-$i.md'];
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(files),
      selectedPath: null,
      onSelectFile: (_) {},
    )));

    // Every file row carries a document glyph; only visible rows exist.
    final built = find.byIcon(Icons.description_outlined).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(100),
        reason: 'a virtualized list should build ~a screenful, not all 1000');
  });

  testWidgets('an empty engram shows a placeholder', (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: const [],
      selectedPath: null,
      onSelectFile: (_) {},
    )));
    expect(find.textContaining('no files'), findsOneWidget);
  });

  testWidgets('initialCollapsed seeds folders as collapsed', (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['notes/first.md']),
      selectedPath: null,
      onSelectFile: (_) {},
      initialCollapsed: const {'notes'},
    )));

    // The folder is shown but seeded collapsed, so its child is hidden.
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('first.md'), findsNothing);
  });

  testWidgets('onCollapsedChanged reports the full set on each toggle',
      (tester) async {
    Set<String>? latest;
    await tester.pumpWidget(_host(FileTree(
      nodes: buildFileTree(['notes/first.md']),
      selectedPath: null,
      onSelectFile: (_) {},
      onCollapsedChanged: (set) => latest = set,
    )));

    await tester.tap(find.text('notes')); // collapse
    await tester.pumpAndSettle();
    expect(latest, {'notes'});

    await tester.tap(find.text('notes')); // expand again
    await tester.pumpAndSettle();
    expect(latest, isEmpty);
  });
}
