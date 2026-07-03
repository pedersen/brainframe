import 'package:brainframe/engram/ui/file_tree.dart';
import 'package:brainframe/engram/ui/file_tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SizedBox(width: 280, child: child)));

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

  testWidgets('an empty engram shows a placeholder', (tester) async {
    await tester.pumpWidget(_host(FileTree(
      nodes: const [],
      selectedPath: null,
      onSelectFile: (_) {},
    )));
    expect(find.textContaining('no files'), findsOneWidget);
  });
}
