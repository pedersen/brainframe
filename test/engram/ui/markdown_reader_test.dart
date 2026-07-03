import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/ui/markdown_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

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

  testWidgets('shows a message when the file cannot be read', (tester) async {
    await tester.pumpWidget(_host(
      MarkdownReader(store: _MapStore(const {}), path: 'missing.md'),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open'), findsOneWidget);
  });
}
