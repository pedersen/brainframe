import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../engram_store.dart';
import 'document_edit_controller.dart';
import 'file_path_breadcrumb.dart';
import 'markdown_reader.dart';
import 'markdown_source_editor.dart';

/// Which face of the editable pane is showing.
enum _Mode { edit, preview }

/// An editable Markdown pane for a writable engram: an Edit/Preview toggle and a
/// save-status chip in the header, over either the raw source editor (Edit) or
/// the existing read-only reader (Preview).
///
/// Only reached for Markdown files in a writable engram — a read-only engram or
/// a non-Markdown file dispatches elsewhere in `buildFileViewer`. It owns the
/// [DocumentEditController] for the open file for its whole lifetime, switching
/// files through it. Toggling to Preview and losing editor focus both flush, so
/// the reader always renders the current content and edits are never stranded.
class MarkdownEditorPane extends StatefulWidget {
  const MarkdownEditorPane({
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
  State<MarkdownEditorPane> createState() => _MarkdownEditorPaneState();
}

class _MarkdownEditorPaneState extends State<MarkdownEditorPane> {
  late final DocumentEditController _controller =
      DocumentEditController(store: widget.store);
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  _Mode _mode = _Mode.edit;

  /// The path whose text has been loaded into the controller, and that text.
  /// Until this matches [widget.path] the pane shows a loading spinner.
  String? _loadedPath;
  String _loadedText = '';
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
    _open(widget.path);
  }

  @override
  void didUpdateWidget(MarkdownEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _open(widget.path); // openFile flushes the outgoing file first
    }
  }

  Future<void> _open(String path) async {
    try {
      final text = await widget.store.readString(path);
      await _controller.openFile(path, text);
      if (!mounted || widget.path != path) return;
      setState(() {
        _loadedPath = path;
        _loadedText = text;
        _loadError = null;
        _mode = _Mode.edit; // a freshly opened file starts in Edit
      });
    } catch (error) {
      if (!mounted || widget.path != path) return;
      setState(() => _loadError = error);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {}); // refresh the save-status chip
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _controller.flush(); // focus-loss flush point
  }

  Future<void> _setMode(_Mode mode) async {
    if (mode == _mode) return;
    // Toggling to Preview flushes first so the reader renders current content.
    if (mode == _Mode.preview) await _controller.flush();
    if (mounted) setState(() => _mode = mode);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loadError != null) {
      return Center(
        child: Text(l10n.readerOpenError(widget.path),
            textAlign: TextAlign.center),
      );
    }
    if (_loadedPath != widget.path) {
      return Center(
        child: Semantics(
          label: l10n.readerLoading,
          child: const CircularProgressIndicator.adaptive(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          path: widget.path,
          mode: _mode,
          status: _controller.status,
          onModeChanged: _setMode,
          onSaveNow: _controller.flush,
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    switch (_mode) {
      case _Mode.edit:
        return MarkdownSourceEditor(
          key: ValueKey(widget.path),
          initialText: _loadedText,
          onChanged: _controller.edit,
          focusNode: _focusNode,
          scrollController: _scrollController,
        );
      case _Mode.preview:
        return MarkdownReader(
          store: widget.store,
          path: widget.path,
          availablePaths: widget.availablePaths,
          onNavigateToFile: widget.onNavigateToFile,
        );
    }
  }
}

/// The pane header: the file-path breadcrumb, the save-status chip, and the
/// Edit/Preview toggle.
class _Header extends StatelessWidget {
  const _Header({
    required this.path,
    required this.mode,
    required this.status,
    required this.onModeChanged,
    required this.onSaveNow,
  });

  final String path;
  final _Mode mode;
  final SaveStatus status;
  final ValueChanged<_Mode> onModeChanged;
  final VoidCallback onSaveNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: FilePathBreadcrumb(path: path)),
          _SaveStatusChip(status: status, onSaveNow: onSaveNow),
          const SizedBox(width: 12),
          _ModeToggle(mode: mode, onChanged: onModeChanged),
        ],
      ),
    );
  }
}

/// The Edit/Preview segmented toggle.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.editorModeGroupLabel,
      child: SegmentedButton<_Mode>(
        showSelectedIcon: false,
        segments: <ButtonSegment<_Mode>>[
          ButtonSegment(
            value: _Mode.edit,
            label: Text(l10n.editorModeEdit),
            icon: const Icon(Icons.edit_outlined),
          ),
          ButtonSegment(
            value: _Mode.preview,
            label: Text(l10n.editorModePreview),
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// The save-status chip: shows `saved` / `saving` / `unsaved` / `error`, and is
/// a tappable "save now" button when there is something to write.
class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.status, required this.onSaveNow});

  final SaveStatus status;
  final VoidCallback onSaveNow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, icon) = _describe(l10n);
    // Only dirty/error are worth a manual flush; saved is nothing to do and
    // saving is already in flight.
    final canSaveNow = status == SaveStatus.dirty || status == SaveStatus.error;
    final color = status == SaveStatus.error ? theme.colorScheme.error : null;

    return Semantics(
      button: canSaveNow,
      label: canSaveNow ? '$label, ${l10n.saveNowTooltip}' : label,
      child: Tooltip(
        message: canSaveNow ? l10n.saveNowTooltip : label,
        child: InkWell(
          onTap: canSaveNow ? onSaveNow : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, IconData) _describe(AppLocalizations l10n) {
    switch (status) {
      case SaveStatus.saved:
        return (l10n.saveStatusSaved, Icons.check_circle_outline);
      case SaveStatus.saving:
        return (l10n.saveStatusSaving, Icons.sync);
      case SaveStatus.dirty:
        return (l10n.saveStatusUnsaved, Icons.edit_note_outlined);
      case SaveStatus.error:
        return (l10n.saveStatusError, Icons.error_outline);
    }
  }
}
