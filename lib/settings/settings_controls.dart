import 'package:flutter/material.dart';

import 'setting_control.dart';

/// Renders a single [SettingControl] as the right-hand side of a settings row.
///
/// One generic switch over the sealed control vocabulary — the same renderer
/// serves core settings and, later, plugin-contributed ones. Standard controls
/// use Flutter's adaptive/Material widgets (so they stay accessible, themed, and
/// e-ink/high-contrast safe); only controls with no native equivalent (colour
/// swatches, key caps) are custom-drawn. Colours come from the active
/// [ColorScheme], never a bespoke palette.
class SettingControlView extends StatelessWidget {
  const SettingControlView({super.key, required this.control});

  final SettingControl control;

  @override
  Widget build(BuildContext context) {
    return switch (control) {
      final ToggleControl c => Switch.adaptive(
        value: c.value,
        onChanged: c.onChanged,
      ),
      final SelectControl c => _Select(control: c),
      final SegmentedControl c => _Segmented(control: c),
      final SliderControl c => _Slider(control: c),
      final ColorControl c => _Swatches(control: c),
      final NumberControl c => _ReadonlyBox(
        text: '${c.value}',
        width: 64,
        mono: true,
      ),
      final TextControl c => _ReadonlyBox(text: c.value, width: 190),
      final HotkeyControl c => _Hotkey(keys: c.keys),
      final ButtonsControl c => _Buttons(control: c),
      final InfoControl c => Text(
        c.value,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    };
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.control});
  final SegmentedControl control;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final o in control.options)
          ButtonSegment<String>(value: o.id, label: Text(o.label)),
      ],
      selected: {control.selected},
      onSelectionChanged: control.onSelected == null
          ? null
          : (selection) => control.onSelected!(selection.first),
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.control});
  final SelectControl control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(control.value, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
    if (control.onChanged == null) return box;
    return PopupMenuButton<String>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: control.onChanged,
      itemBuilder: (context) => [
        for (final o in control.options)
          PopupMenuItem<String>(value: o, child: Text(o)),
      ],
      child: box,
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.control});
  final SliderControl control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '${_trim(control.value)}${control.unit ?? ''}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 170,
          child: Slider.adaptive(
            value: control.value.clamp(control.min, control.max),
            min: control.min,
            max: control.max,
            onChanged: control.onChanged,
          ),
        ),
      ],
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.control});
  final ColorControl control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hex in control.options)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Semantics(
              button: control.onChanged != null,
              selected: hex == control.value,
              label: hex,
              child: GestureDetector(
                onTap: control.onChanged == null
                    ? null
                    : () => control.onChanged!(hex),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _parseHex(hex),
                    borderRadius: BorderRadius.circular(6),
                    border: hex == control.value
                        ? Border.all(color: scheme.primary, width: 2)
                        : Border.all(color: scheme.outlineVariant),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Color _parseHex(String hex) {
    final v = hex.replaceFirst('#', '');
    return Color(int.parse('FF$v', radix: 16));
  }
}

class _Hotkey extends StatelessWidget {
  const _Hotkey({required this.keys});
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: keys.join(' '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final k in keys)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  k,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.control});
  final ButtonsControl control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final b in control.items)
          OutlinedButton(
            onPressed: b.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: b.danger ? scheme.error : scheme.onSurface,
              side: BorderSide(
                color: b.danger ? scheme.error : scheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            ),
            child: Text(b.label),
          ),
      ],
    );
  }
}

class _ReadonlyBox extends StatelessWidget {
  const _ReadonlyBox({
    required this.text,
    required this.width,
    this.mono = false,
  });
  final String text;
  final double width;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: mono ? TextAlign.center : TextAlign.start,
        style: TextStyle(fontSize: 13, fontFamily: mono ? 'monospace' : null),
      ),
    );
  }
}
