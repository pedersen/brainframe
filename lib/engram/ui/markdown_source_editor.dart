import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Cross-platform monospace fallbacks, tried in order. No monospace font is
/// bundled, so this leans on whatever each platform ships; the last entry is
/// the generic family name Android resolves.
const List<String> _monospaceFallback = <String>[
  'Menlo', // macOS / iOS
  'Consolas', // Windows
  'DejaVu Sans Mono', // Linux
  'Courier New',
  'monospace',
];

/// A plain multiline source editor for one Markdown file — the swappable seam
/// (design: "The editing surface (a swappable seam)").
///
/// Its contract is deliberately narrow: [initialText] in, [onChanged] out, plus
/// an optional [focusNode] and [scrollController] the host owns so it can flush
/// saves on focus loss and drive scrolling. Nothing above it knows it is a
/// [TextField], so the internals can later be swapped for a code-editor package
/// behind this one widget without touching the save controller, toggle, or
/// browser.
class MarkdownSourceEditor extends StatefulWidget {
  const MarkdownSourceEditor({
    super.key,
    required this.initialText,
    this.onChanged,
    this.focusNode,
    this.scrollController,
  });

  /// The file's source when the editor is first built. If it changes to a
  /// different value (a different file loaded into the same widget slot), the
  /// editor adopts the new text — see [State.didUpdateWidget].
  final String initialText;

  /// Called on every edit with the full current text.
  final ValueChanged<String>? onChanged;

  /// Focus for the underlying field; the host supplies it to flush on focus
  /// loss.
  final FocusNode? focusNode;

  /// Scroll controller for the field's own vertical scrolling.
  final ScrollController? scrollController;

  @override
  State<MarkdownSourceEditor> createState() => _MarkdownSourceEditorState();
}

class _MarkdownSourceEditorState extends State<MarkdownSourceEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void didUpdateWidget(MarkdownSourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different file (or an external reset) arrived without the widget being
    // recreated. Adopt it, but don't clobber a matching in-progress buffer, and
    // place the caret at the end of the freshly loaded text.
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialText,
        selection: TextSelection.collapsed(offset: widget.initialText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Reduce Motion (and the e-ink target): don't animate the cursor's opacity
    // fade. The blink cadence itself is Flutter's and has no public disable, so
    // this turns off the animation the framework does expose.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: AppLocalizations.of(context).markdownEditorLabel,
      textField: true,
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        scrollController: widget.scrollController,
        onChanged: widget.onChanged,
        // Fill the pane and grow with content; the host bounds the height.
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        cursorOpacityAnimates: !reduceMotion,
        // Ambient text scaling and boldText apply automatically; the size is
        // never clamped. Only the family is overridden, to monospace.
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFamily: 'monospace',
          fontFamilyFallback: _monospaceFallback,
          height: 1.4,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}
