import 'dart:convert';
import 'dart:typed_data';

import 'package:brainframe/engram/engram_store.dart';
import 'package:brainframe/engram/ui/file_viewer.dart';
import 'package:brainframe/engram/ui/markdown_editor_pane.dart';
import 'package:brainframe/engram/ui/markdown_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/localized_app.dart';

/// A tiny in-memory store returning fixed bytes per path.
class _MapStore extends EngramStore {
  _MapStore(this.files);
  final Map<String, Uint8List> files;

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<Uint8List> readBytes(String path) async {
    final bytes = files[path];
    if (bytes == null) throw StateError('no such file: $path');
    return bytes;
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {}
}

Uint8List _text(String s) => Uint8List.fromList(utf8.encode(s));

/// A valid 1×1 transparent PNG — enough for the viewer to render an [Image].
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9'
  'awAAAABJRU5ErkJggg==',
);

Widget _host(Widget child) => localizedApp(home: Scaffold(body: child));

void main() {
  group('fileExtension', () {
    test('returns the lower-cased extension without the dot', () {
      expect(fileExtension('a/b/photo.PNG'), 'png');
      expect(fileExtension('notes/first.md'), 'md');
      expect(fileExtension('book.EPUB'), 'epub');
    });

    test('returns empty for no extension or a dotfile', () {
      expect(fileExtension('README'), '');
      expect(fileExtension('notes/.gitignore'), '');
      expect(fileExtension('a/b/plainname'), '');
    });
  });

  group('type predicates', () {
    test('classify markdown and image paths', () {
      expect(isMarkdownPath('welcome.md'), isTrue);
      expect(isMarkdownPath('notes/a.markdown'), isTrue);
      expect(isMarkdownPath('notes/log.txt'), isTrue); // plain text renders too
      expect(isMarkdownPath('photo.png'), isFalse);

      for (final p in ['a.png', 'a.jpg', 'a.jpeg', 'a.gif', 'a.webp', 'a.bmp']) {
        expect(isImagePath(p), isTrue, reason: p);
      }
      expect(isImagePath('doc.pdf'), isFalse);
      expect(isImagePath('welcome.md'), isFalse);
    });
  });

  group('buildFileViewer dispatch', () {
    final store = _MapStore({
      'welcome.md': _text('# Hi'),
      'notes/log.txt': _text('plain text note'),
      'diagram.png': _onePixelPng,
      'book.epub': _text('not really an epub'),
    });

    testWidgets('markdown routes to MarkdownReader', (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(store: store, path: 'welcome.md')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownReader), findsOneWidget);
    });

    testWidgets('plain text routes to MarkdownReader and renders',
        (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(store: store, path: 'notes/log.txt')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownReader), findsOneWidget);
      expect(
        find.textContaining('plain text note', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('markdown defaults to read-only (no editor)', (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(store: store, path: 'welcome.md')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownReader), findsOneWidget);
      expect(find.byType(MarkdownEditorPane), findsNothing);
    });

    testWidgets('writable markdown routes to the editor pane', (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(
            store: store, path: 'welcome.md', readOnly: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownEditorPane), findsOneWidget);
      expect(find.byType(MarkdownReader), findsNothing);
    });

    testWidgets('readOnly:false does not affect images', (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(
            store: store, path: 'diagram.png', readOnly: false)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageFileViewer), findsOneWidget);
    });

    testWidgets('image routes to ImageFileViewer', (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(store: store, path: 'diagram.png')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageFileViewer), findsOneWidget);
    });

    testWidgets('unknown format routes to UnsupportedFileViewer',
        (tester) async {
      await tester.pumpWidget(
        _host(buildFileViewer(store: store, path: 'book.epub')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UnsupportedFileViewer), findsOneWidget);
    });
  });

  group('ImageFileViewer', () {
    testWidgets('shows the breadcrumb and renders the image', (tester) async {
      await tester.pumpWidget(_host(
        ImageFileViewer(
          store: _MapStore({'pics/diagram.png': _onePixelPng}),
          path: 'pics/diagram.png',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('pics/diagram.png'), findsOneWidget); // breadcrumb
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, contains('diagram.png'));
    });

    testWidgets('shows a message when the image cannot be read',
        (tester) async {
      await tester.pumpWidget(_host(
        ImageFileViewer(store: _MapStore(const {}), path: 'missing.png'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('starts fitted (BoxFit.contain, no scroll view)',
        (tester) async {
      await tester.pumpWidget(_host(
        ImageFileViewer(
          store: _MapStore({'diagram.png': _onePixelPng}),
          path: 'diagram.png',
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('toggles to actual size (natural size, scroll bars) and back',
        (tester) async {
      await tester.pumpWidget(_host(
        ImageFileViewer(
          store: _MapStore({'diagram.png': _onePixelPng}),
          path: 'diagram.png',
        ),
      ));
      await tester.pumpAndSettle();

      // The one button in the viewer flips the mode.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(tester.widget<Image>(find.byType(Image)).fit, isNull);
      // Two nested scroll views -> a two-axis scrollable, each with a Scrollbar.
      expect(find.byType(SingleChildScrollView), findsNWidgets(2));
      expect(find.byType(Scrollbar), findsNWidgets(2));

      // Flip back to fitted.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('resets to fitted when switched to a different image',
        (tester) async {
      final store = _MapStore({'a.png': _onePixelPng, 'b.png': _onePixelPng});
      await tester
          .pumpWidget(_host(ImageFileViewer(store: store, path: 'a.png')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton)); // into actual size
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNWidgets(2));

      // Reuse the same State (same tree position) with a different path.
      await tester
          .pumpWidget(_host(ImageFileViewer(store: store, path: 'b.png')));
      await tester.pumpAndSettle();

      expect(find.text('b.png'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing); // back to fitted
    });
  });

  group('UnsupportedFileViewer', () {
    testWidgets('shows the breadcrumb and an unsupported-format message',
        (tester) async {
      await tester.pumpWidget(
        _host(const UnsupportedFileViewer(path: 'library/book.epub')),
      );
      await tester.pumpAndSettle();

      expect(find.text('library/book.epub'), findsOneWidget); // breadcrumb
      expect(find.textContaining('book.epub'), findsWidgets);
      expect(find.textContaining("Can’t display"), findsOneWidget);
    });
  });
}
