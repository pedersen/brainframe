import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/ui/markdown_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

/// A tiny in-memory store for reader tests.
class _MapStore extends EngramStore {
  _MapStore(this.files);
  final Map<String, String> files;

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<Uint8List> readBytes(String path) async {
    final content = files[path];
    if (content == null) throw StateError('no such file: $path');
    return Uint8List.fromList(utf8.encode(content));
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}

Widget _host(Widget child) => localizedApp(home: Scaffold(body: child));

void main() {
  group('resolveIntraEngramLink', () {
    test('resolves a sibling link against the current directory', () {
      expect(
        resolveIntraEngramLink('notes/first.md', 'second.md'),
        'notes/second.md',
      );
      expect(resolveIntraEngramLink('welcome.md', 'notes/a.md'), 'notes/a.md');
    });

    test('handles ".." and "." segments', () {
      expect(resolveIntraEngramLink('notes/first.md', '../welcome.md'),
          'welcome.md');
      expect(resolveIntraEngramLink('a/b/c.md', './d.md'), 'a/b/d.md');
    });

    test('treats a leading slash as engram-absolute', () {
      expect(resolveIntraEngramLink('notes/a.md', '/welcome.md'), 'welcome.md');
    });

    test('percent-decodes segments so encoded spaces match real paths', () {
      // Markdown encodes spaces in link destinations; the engram's paths use
      // real spaces. Decoding is what makes them match (regression: silently
      // failing links to files whose names contain spaces).
      expect(
        resolveIntraEngramLink('book-notes/Atomic Habits/Atomic Habits MoC.md',
            'Habit%20Building%20Tools.md'),
        'book-notes/Atomic Habits/Habit Building Tools.md',
      );
      expect(
        resolveIntraEngramLink('a/b.md', 'sub%20dir/c%20d.md'),
        'a/sub dir/c d.md',
      );
    });

    test('falls back to the raw segment when encoding is malformed', () {
      expect(resolveIntraEngramLink('a.md', 'b%zz.md'), 'b%zz.md');
    });

    test('returns null for external links and root escapes', () {
      expect(resolveIntraEngramLink('a.md', 'https://example.com'), isNull);
      expect(resolveIntraEngramLink('a.md', 'mailto:x@y.z'), isNull);
      expect(resolveIntraEngramLink('a.md', '../../etc/passwd'), isNull);
    });
  });

  testWidgets('renders the breadcrumb and the file content', (tester) async {
    await tester.pumpWidget(_host(
      MarkdownReader(
        store: _MapStore({'notes/a.md': '# Hello world'}),
        path: 'notes/a.md',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('notes/a.md'), findsOneWidget); // breadcrumb
    expect(
      find.textContaining('Hello world', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('tapping a percent-encoded link navigates to the decoded path',
      (tester) async {
    const current = 'reading list/Reading List MoC.md';
    const target = 'reading list/Wildflowers of the Midwest.md';
    String? navigated;
    await tester.pumpWidget(_host(
      MarkdownReader(
        store: _MapStore({
          current: '[Wildflowers](Wildflowers%20of%20the%20Midwest.md)',
        }),
        path: current,
        availablePaths: const {current, target},
        onNavigateToFile: (path) => navigated = path,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('Wildflowers'));
    await tester.pumpAndSettle();

    expect(navigated, target);
  });

  testWidgets('content is top-aligned within a tall pane, not centered',
      (tester) async {
    await tester.pumpWidget(_host(
      MarkdownReader(store: _MapStore({'a.md': '# Short doc'}), path: 'a.md'),
    ));
    await tester.pumpAndSettle();

    // The breadcrumb sits near the top of the ~600px pane, not centered (~270).
    final y = tester.getTopLeft(find.text('a.md')).dy;
    expect(y, lessThan(120), reason: 'breadcrumb should be near the top');
  });

  testWidgets('shows a message when the file cannot be read', (tester) async {
    await tester.pumpWidget(_host(
      MarkdownReader(store: _MapStore(const {}), path: 'missing.md'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open'), findsOneWidget);
  });
}
