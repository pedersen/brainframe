/// The data model for the pluggable settings surface.
///
/// Categories are **data, not hardcoded screens**: the core app and (later)
/// each plugin declare a [SettingsCategory], and the detail pane renders its
/// [SettingControl]s through a single generic switch. Adding a category — or a
/// plugin contributing one — never touches the shell.
library;

import 'package:flutter/widgets.dart';

/// A single control on the right-hand side of a settings row. Sealed so the
/// renderer can switch exhaustively over the whole control vocabulary.
sealed class SettingControl {
  const SettingControl();
}

/// An on/off switch.
class ToggleControl extends SettingControl {
  const ToggleControl({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
}

/// A single choice drawn from [options], shown as a dropdown-style box.
class SelectControl extends SettingControl {
  const SelectControl({
    required this.value,
    required this.options,
    this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;
}

/// One choice among a small, fixed set, shown inline as a segmented control.
/// Values are opaque ids; [SegmentOption.label] is the localized display text.
class SegmentedControl extends SettingControl {
  const SegmentedControl({
    required this.selected,
    required this.options,
    this.onSelected,
  });
  final String selected;
  final List<SegmentOption> options;
  final ValueChanged<String>? onSelected;
}

/// One option in a [SegmentedControl].
class SegmentOption {
  const SegmentOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// A numeric value chosen along a track.
class SliderControl extends SettingControl {
  const SliderControl({
    required this.value,
    required this.min,
    required this.max,
    this.unit,
    this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final String? unit;
  final ValueChanged<double>? onChanged;
}

/// A colour chosen from a fixed palette of hex swatches.
class ColorControl extends SettingControl {
  const ColorControl({
    required this.value,
    required this.options,
    this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String>? onChanged;
}

/// A free numeric entry.
class NumberControl extends SettingControl {
  const NumberControl({required this.value, this.onChanged});
  final num value;
  final ValueChanged<num>? onChanged;
}

/// A free text entry.
class TextControl extends SettingControl {
  const TextControl({required this.value, this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;
}

/// A read-only keyboard shortcut, shown as a row of key caps.
class HotkeyControl extends SettingControl {
  const HotkeyControl({required this.keys});
  final List<String> keys;
}

/// A row of action buttons.
class ButtonsControl extends SettingControl {
  const ButtonsControl({required this.items});
  final List<SettingButton> items;
}

/// One button in a [ButtonsControl].
class SettingButton {
  const SettingButton({
    required this.label,
    this.danger = false,
    this.onPressed,
  });
  final String label;
  final bool danger;
  final VoidCallback? onPressed;
}

/// A read-only informational value (version, license, …).
class InfoControl extends SettingControl {
  const InfoControl({required this.value});
  final String value;
}

/// One setting: a name, an optional longer description, and its control.
class SettingRow {
  const SettingRow({
    required this.name,
    this.description,
    required this.control,
  });
  final String name;
  final String? description;
  final SettingControl control;
}

/// A titled group of rows within a category's detail pane.
class SettingSection {
  const SettingSection({required this.title, required this.rows});
  final String title;
  final List<SettingRow> rows;
}

/// A settings category: one entry in the sidebar and one detail pane.
///
/// Most categories describe their detail pane as [sections] of control rows.
/// A category may instead supply [detail] — a custom widget rendered in place
/// of the header and sections — for panes that aren't a list of settings (e.g.
/// About, which embeds its own identity/version/links layout).
class SettingsCategory {
  const SettingsCategory({
    required this.id,
    required this.name,
    required this.initial,
    required this.description,
    this.plugin = false,
    this.sections = const [],
    this.detail,
  });

  /// Stable id used for selection and persistence.
  final String id;

  /// Sidebar label and detail-pane title.
  final String name;

  /// 1–2 characters shown in the sidebar icon tile.
  final String initial;

  /// Detail-pane subtitle.
  final String description;

  /// True when contributed by a plugin — styled and grouped apart from core.
  final bool plugin;

  final List<SettingSection> sections;

  /// A custom detail pane. When set, it replaces the header + [sections] for
  /// this category (see the class doc).
  final WidgetBuilder? detail;
}

/// An ordered, labelled group of categories in the sidebar (e.g. Core, Plugins).
class SettingsGroup {
  const SettingsGroup({required this.label, required this.items});
  final String label;
  final List<SettingsCategory> items;
}
