import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engram_store.dart';
import 'file_path_breadcrumb.dart';
import 'markdown_reader.dart';

/// Image extensions Flutter decodes natively via [Image.memory] — no extra
/// dependency. Lower-case, without the leading dot.
const Set<String> imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// Extensions rendered by [MarkdownReader]. Plain text (`.txt`) is included
/// because Markdown is a superset of plain text — a `.txt` file is already
/// valid Markdown input, so it renders as nicely-formatted text rather than
/// falling through to the unsupported placeholder. (One caveat: the Markdown
/// renderer treats a single newline as a soft break, so hard-wrapped plain text
/// reflows into paragraphs.)
const Set<String> markdownExtensions = {'md', 'markdown', 'txt'};

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
/// under the shared file-path breadcrumb, in one of two modes the user toggles
/// from a header button.
///
/// - **Fit to window** (default): scaled to fill the pane, so a whole image is
///   visible at a glance — the right default for small images and thumbnails.
/// - **Actual size**: the image at its natural pixel size, with scroll bars in
///   both axes when it overflows — needed to inspect detail in large images the
///   fitted view would shrink.
///
/// The image is exposed to screen readers via a generated label (the file has
/// no alt text of its own); a decode failure falls back to the same
/// unreadable-file message as a read failure.
class ImageFileViewer extends StatefulWidget {
  const ImageFileViewer({super.key, required this.store, required this.path});

  final EngramStore store;
  final String path;

  @override
  State<ImageFileViewer> createState() => _ImageFileViewerState();
}

class _ImageFileViewerState extends State<ImageFileViewer> {
  /// False = scaled to fit the pane; true = natural pixel size with scroll bars.
  bool _actualSize = false;

  // Separate controllers for the two nested scroll views used in actual-size
  // mode, so each axis has its own scroll bar.
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  @override
  void didUpdateWidget(ImageFileViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new image starts fitted, so switching files never lands the user
    // scrolled into the middle of the previous (differently sized) image.
    if (oldWidget.path != widget.path && _actualSize) {
      _actualSize = false;
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      // Keyed on path so selecting another image re-reads rather than reusing
      // the previous file's future.
      key: ValueKey(widget.path),
      future: widget.store.readBytes(widget.path),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
        if (snapshot.hasError) {
          return Center(
            child: Text(l10n.readerOpenError(widget.path),
                textAlign: TextAlign.center),
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
          Row(
            children: [
              Expanded(child: FilePathBreadcrumb(path: widget.path)),
              IconButton(
                icon: Icon(
                    _actualSize ? Icons.fullscreen_exit : Icons.fullscreen),
                tooltip: _actualSize
                    ? l10n.viewerImageFitToWindow
                    : l10n.viewerImageActualSize,
                onPressed: () => setState(() => _actualSize = !_actualSize),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _image(context, bytes)),
        ],
      ),
    );
  }

  /// The image itself, laid out per the current mode.
  Widget _image(BuildContext context, Uint8List bytes) {
    final l10n = AppLocalizations.of(context);
    final image = Image.memory(
      bytes,
      // No `fit` in actual-size mode: render at natural pixel size and let the
      // scroll views handle any overflow.
      fit: _actualSize ? null : BoxFit.contain,
      semanticLabel: l10n.viewerImageLabel(_fileName(widget.path)),
      errorBuilder: (context, error, stack) => Text(
        l10n.readerOpenError(widget.path),
        textAlign: TextAlign.center,
      ),
    );
    if (!_actualSize) return Center(child: image);

    // Two nested single-axis scroll views give a two-axis scrollable, each with
    // its own always-visible scroll bar (no hover on e-ink or touch).
    return Scrollbar(
      controller: _vertical,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertical,
        child: Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: image,
          ),
        ),
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
