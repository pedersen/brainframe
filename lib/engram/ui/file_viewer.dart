import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engram_store.dart';
import 'file_path_breadcrumb.dart';
import 'markdown_reader.dart';

/// Image extensions Flutter decodes natively via [Image.memory] — no extra
/// dependency. Lower-case, without the leading dot.
const Set<String> imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// Markdown extensions routed to [MarkdownReader].
const Set<String> markdownExtensions = {'md', 'markdown'};

/// The lower-cased extension of [path] (no dot), or `''` when it has none.
///
/// A leading dot with no earlier one (`.gitignore`) is treated as no extension,
/// not as the extension `gitignore`.
String fileExtension(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return '';
  return name.substring(dot + 1).toLowerCase();
}

bool isImagePath(String path) => imageExtensions.contains(fileExtension(path));

bool isMarkdownPath(String path) =>
    markdownExtensions.contains(fileExtension(path));

/// Builds the right content viewer for [path], dispatching on its extension.
///
/// Markdown renders in [MarkdownReader]; images render in [ImageFileViewer];
/// every other type falls through to [UnsupportedFileViewer]. That fall-through
/// is the seam future PDF and EPUB viewers slot into — add the extension check
/// and the widget, and the browser needs no further change.
///
/// [availablePaths] and [onNavigateToFile] are only consulted by the Markdown
/// reader (for intra-engram link navigation); other viewers ignore them.
Widget buildFileViewer({
  required EngramStore store,
  required String path,
  Set<String> availablePaths = const {},
  void Function(String path)? onNavigateToFile,
}) {
  if (isMarkdownPath(path)) {
    return MarkdownReader(
      store: store,
      path: path,
      availablePaths: availablePaths,
      onNavigateToFile: onNavigateToFile,
    );
  }
  if (isImagePath(path)) {
    return ImageFileViewer(store: store, path: path);
  }
  return UnsupportedFileViewer(path: path);
}

/// Views one raster image from an engram: reads [path] as bytes and renders it
/// scaled to fit under the shared file-path breadcrumb.
///
/// The image is exposed to screen readers via a generated label (the file has
/// no alt text of its own); a decode failure falls back to the same
/// unreadable-file message as a read failure.
class ImageFileViewer extends StatelessWidget {
  const ImageFileViewer({super.key, required this.store, required this.path});

  final EngramStore store;
  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      // Keyed on path so selecting another image re-reads rather than reusing
      // the previous file's future.
      key: ValueKey(path),
      future: store.readBytes(path),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
        if (snapshot.hasError) {
          return Center(
            child: Text(l10n.readerOpenError(path), textAlign: TextAlign.center),
          );
        }
        if (!snapshot.hasData) {
          return Center(
            child: Semantics(
              label: l10n.readerLoading,
              child: const CircularProgressIndicator.adaptive(),
            ),
          );
        }
        return _framed(context, snapshot.data!);
      },
    );
  }

  Widget _framed(BuildContext context, Uint8List bytes) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilePathBreadcrumb(path: path),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                semanticLabel: l10n.viewerImageLabel(_fileName(path)),
                errorBuilder: (context, error, stack) => Text(
                  l10n.readerOpenError(path),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The placeholder shown for a recognized file whose format has no viewer yet
/// (PDF, EPUB, and anything else). It keeps the shared breadcrumb header, then
/// states plainly that the format can't be displayed — the groundwork the real
/// PDF/EPUB viewers replace.
class UnsupportedFileViewer extends StatelessWidget {
  const UnsupportedFileViewer({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilePathBreadcrumb(path: path),
          Expanded(
            child: Center(
              child: Text(
                l10n.viewerUnsupportedFormat(_fileName(path)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fileName(String path) => path.split('/').last;
