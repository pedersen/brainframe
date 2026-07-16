import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engram_store.dart';
import 'file_path_breadcrumb.dart';

/// A read-only Markdown viewer for one file in an engram.
///
/// Reads [path] from [store] and renders it under a small file-path breadcrumb,
/// in a centered readable column. Rendering uses the ambient theme (Step 8 is
/// structure-only — the design handoff's bespoke typography is deferred).
///
/// Relative Markdown links that resolve to another file in [availablePaths]
/// navigate via [onNavigateToFile]; links with a URI scheme (`http:`, `mailto:`)
/// and links that resolve to nothing are ignored for now (no external opener in
/// the read-only milestone).
class MarkdownReader extends StatelessWidget {
  const MarkdownReader({
    super.key,
    required this.store,
    required this.path,
    this.availablePaths = const {},
    this.onNavigateToFile,
  });

  final EngramStore store;
  final String path;
  final Set<String> availablePaths;
  final void Function(String path)? onNavigateToFile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      // Keyed on path so selecting another file re-reads rather than reusing
      // the previous file's future.
      key: ValueKey(path),
      future: store.readString(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _centered(
              context, AppLocalizations.of(context).readerOpenError(path));
        }
        if (!snapshot.hasData) {
          return Center(
            child: Semantics(
              label: AppLocalizations.of(context).readerLoading,
              child: const CircularProgressIndicator.adaptive(),
            ),
          );
        }
        return _content(context, snapshot.data!);
      },
    );
  }

  Widget _content(BuildContext context, String markdown) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      // Top-aligned, not centered: reading starts at the top of the pane.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilePathBreadcrumb(path: path),
              const SizedBox(height: 12),
              MarkdownBody(
                data: markdown,
                // Selection is left off deliberately: selectable Markdown text
                // registers long-press-tappable nodes with no semantic label,
                // which fails the labeled-tap-target accessibility guideline.
                // Screen readers still read the rendered text.
                onTapLink: (text, href, title) => _handleLink(href),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLink(String? href) {
    if (href == null || onNavigateToFile == null) return;
    final target = _resolveIntraEngramLink(path, href);
    if (target != null && availablePaths.contains(target)) {
      onNavigateToFile!(target);
    }
  }

  Widget _centered(BuildContext context, String message) =>
      Center(child: Text(message, textAlign: TextAlign.center));
}

/// Resolves a relative Markdown [href] against the [currentPath]'s directory
/// into an engram-relative path, or null if it has a URI scheme (external) or
/// escapes above the engram root.
///
/// Kept top-level and pure so it is unit-testable without a widget.
String? resolveIntraEngramLink(String currentPath, String href) =>
    _resolveIntraEngramLink(currentPath, href);

String? _resolveIntraEngramLink(String currentPath, String href) {
  final uri = Uri.tryParse(href);
  if (uri == null || uri.hasScheme) return null; // http:, mailto:, … — external

  // Start from the current file's directory, unless the link is engram-absolute.
  final segments = href.startsWith('/')
      ? <String>[]
      : (currentPath.split('/')..removeLast());
  // Split on the raw '/' first so an encoded '%2F' is never treated as a path
  // separator, then percent-decode each segment. Markdown link destinations
  // encode spaces and other reserved characters (`Habit%20Building%20Tools.md`),
  // while the engram's own paths use the decoded form — decode so they match.
  for (final rawSegment in href.split('/')) {
    final segment = _decodeSegment(rawSegment);
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null; // escapes the engram root
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.isEmpty ? null : segments.join('/');
}

/// Percent-decodes a single path segment, falling back to the raw text if the
/// segment is not valid percent-encoding (e.g. a stray `%`).
String _decodeSegment(String segment) {
  try {
    return Uri.decodeComponent(segment);
  } on ArgumentError {
    return segment;
  }
}
