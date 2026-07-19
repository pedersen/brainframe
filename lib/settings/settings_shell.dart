import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import 'setting_control.dart';
import 'settings_controls.dart';
import 'settings_registry.dart';

/// The reusable settings surface: a master list of categories and a detail pane
/// that renders the selected category's controls.
///
/// Reflow is driven by the shell's **own measured width** (via [LayoutBuilder]),
/// not the global viewport, so it is correct embedded in any container:
///   - width ≥ 860 → wide split view, 264px sidebar
///   - 540–859     → medium split view, 212px sidebar
///   - < 540       → narrow stacked drill-in (list → detail, with a back bar)
class SettingsShell extends StatefulWidget {
  const SettingsShell({super.key, this.initialCategoryId});

  /// The category selected first. Defaults to the first registered category.
  final String? initialCategoryId;

  @override
  State<SettingsShell> createState() => _SettingsShellState();
}

enum _Mode { wide, medium, narrow }

class _SettingsShellState extends State<SettingsShell> {
  String? _selectedId;
  bool _phoneDetail = false;

  @override
  Widget build(BuildContext context) {
    final groups = buildSettingsGroups(context);
    final all = [for (final g in groups) ...g.items];
    if (all.isEmpty) return const SizedBox.shrink();

    final selectedId = _selectedId ?? widget.initialCategoryId ?? all.first.id;
    var current = all.first;
    for (final c in all) {
      if (c.id == selectedId) current = c;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final mode = w >= 860
            ? _Mode.wide
            : w >= 540
            ? _Mode.medium
            : _Mode.narrow;
        final isStack = mode == _Mode.narrow;
        final showMaster = !isStack || !_phoneDetail;
        final showDetail = !isStack || _phoneDetail;
        final scheme = Theme.of(context).colorScheme;

        final master = _Master(
          groups: groups,
          selectedId: current.id,
          isStack: isStack,
          width: mode == _Mode.wide ? 264 : 212,
          onSelect: (id) => setState(() {
            _selectedId = id;
            if (isStack) _phoneDetail = true;
          }),
        );

        final detail = _Detail(
          category: current,
          isStack: isStack,
          onBack: () => setState(() => _phoneDetail = false),
        );

        return DecoratedBox(
          decoration: BoxDecoration(color: scheme.surface),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showMaster) isStack ? Expanded(child: master) : master,
              if (showDetail) Expanded(child: detail),
            ],
          ),
        );
      },
    );
  }
}

class _Master extends StatelessWidget {
  const _Master({
    required this.groups,
    required this.selectedId,
    required this.isStack,
    required this.width,
    required this.onSelect,
  });

  final List<SettingsGroup> groups;
  final String selectedId;
  final bool isStack;
  final double width;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Text(
            l10n.settingsTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 13, 9, 5),
                  child: Text(
                    group.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.07 * 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final item in group.items)
                  _CategoryRow(
                    item: item,
                    active: item.id == selectedId,
                    isStack: isStack,
                    onTap: () => onSelect(item.id),
                  ),
              ],
            ],
          ),
        ),
      ],
    );

    return Container(
      width: isStack ? null : width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: isStack
            ? null
            : Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: column,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.active,
    required this.isStack,
    required this.onTap,
  });

  final SettingsCategory item;
  final bool active;
  final bool isStack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeBg = scheme.primary.withValues(alpha: 0.14);

    return Semantics(
      button: true,
      selected: active,
      label: item.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: isStack ? null : BorderRadius.circular(8),
        child: Container(
          margin: EdgeInsets.only(bottom: isStack ? 0 : 1),
          padding: EdgeInsets.symmetric(
            horizontal: isStack ? 12 : 9,
            vertical: isStack ? 13 : 7,
          ),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.transparent,
            borderRadius: isStack ? null : BorderRadius.circular(8),
            border: isStack
                ? Border(bottom: BorderSide(color: scheme.outlineVariant))
                : null,
          ),
          child: Row(
            children: [
              _IconTile(item: item),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              if (isStack)
                Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.item});
  final SettingsCategory item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: item.plugin
            ? scheme.primary.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.initial,
        style: TextStyle(
          fontSize: item.initial.length > 1 ? 9.5 : 11,
          fontWeight: FontWeight.w700,
          color: item.plugin ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.category,
    required this.isStack,
    required this.onBack,
  });

  final SettingsCategory category;
  final bool isStack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hPad = isStack ? 18.0 : 32.0;

    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isStack)
            InkWell(
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_left, size: 22, color: scheme.primary),
                    Text(
                      AppLocalizations.of(context).settingsTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // A category may render a bespoke detail pane (e.g. About) instead of
          // the standard header + control sections.
          if (category.detail != null)
            Expanded(child: category.detail!(context))
          else ...[
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, isStack ? 6 : 26, hPad, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.01 * 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 44),
                children: [
                  for (final section in category.sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: Text(
                        section.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.05 * 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final row in section.rows) _Row(row: row),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final SettingRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (row.description != null) ...[
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              row.description!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
    final control = SettingControlView(control: row.control);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // Below this width the label + control can't sit side by side without
      // crushing a wide control (e.g. the 4-option per-engram theme override),
      // so stack the control under the label.
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 12), control],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: label),
              const SizedBox(width: 24),
              control,
            ],
          );
        },
      ),
    );
  }
}
