import 'package:flutter/material.dart';

import '../about/about_screen.dart';
import '../engram/repository_scope.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_settings.dart';
import 'app_settings_controller.dart';
import 'housekeeping_pane.dart';
import 'setting_control.dart';

/// Builds a category on demand, reading current state from [context] so its
/// controls reflect (and mutate) live settings. This is the unit a plugin
/// contributes.
typedef SettingsCategoryBuilder =
    SettingsCategory Function(BuildContext context);

/// The pluggable settings registry.
///
/// Core settings are always present via [buildCoreGroups]. Anything else — a
/// future plugin system — calls [registerCategory] to contribute a category
/// into a named group; the shell renders whatever is registered without
/// changing. Registration is keyed by category id, so re-registering (hot
/// reload, a plugin reloading) replaces rather than duplicates.
class SettingsRegistry {
  final List<_Entry> _entries = <_Entry>[];

  /// Contributes [builder] under [group] (e.g. the `plugins` group). [id] is the
  /// category id used for selection and de-duplication.
  void registerCategory({
    required String group,
    required String id,
    required SettingsCategoryBuilder builder,
  }) {
    _entries.removeWhere((e) => e.id == id);
    _entries.add(_Entry(group, id, builder));
  }

  /// Removes a previously registered category.
  void unregisterCategory(String id) => _entries.removeWhere((e) => e.id == id);

  /// The contributed groups, in first-registration order, each labelled via
  /// [label] (group id → display text).
  List<SettingsGroup> groups(
    BuildContext context, {
    required String Function(String groupId) label,
  }) {
    final order = <String>[];
    final byGroup = <String, List<SettingsCategory>>{};
    for (final e in _entries) {
      (byGroup[e.group] ??= (
        order..add(e.group),
        <SettingsCategory>[],
      ).$2).add(e.builder(context));
    }
    return [
      for (final g in order) SettingsGroup(label: label(g), items: byGroup[g]!),
    ];
  }
}

class _Entry {
  _Entry(this.group, this.id, this.builder);
  final String group;
  final String id;
  final SettingsCategoryBuilder builder;
}

/// The app-wide registry instance. Core seeds itself through [buildCoreGroups];
/// plugins call [SettingsRegistry.registerCategory] on this.
final SettingsRegistry settingsRegistry = SettingsRegistry();

/// The full ordered group list the shell renders: the built-in core group,
/// followed by any plugin-contributed groups.
List<SettingsGroup> buildSettingsGroups(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    ...buildCoreGroups(context),
    ...settingsRegistry.groups(
      context,
      label: (groupId) => switch (groupId) {
        'plugins' => l10n.settingsGroupPlugins,
        _ => groupId,
      },
    ),
  ];
}

/// The built-in "Core" group, seeded from BrainFrame's real settings. Controls
/// read and write [AppSettingsController], so the detail pane is live.
List<SettingsGroup> buildCoreGroups(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final controller = AppSettings.of(context).controller;

  return [
    SettingsGroup(
      label: l10n.settingsGroupCore,
      items: [
        SettingsCategory(
          id: 'appearance',
          name: l10n.settingsAppearanceName,
          initial: 'A',
          description: l10n.settingsAppearanceDesc,
          sections: [
            SettingSection(
              title: l10n.settingsSectionTheme,
              rows: [
                SettingRow(
                  name: l10n.settingsDefaultTheme,
                  description: l10n.settingsDefaultThemeDesc,
                  control: SegmentedControl(
                    selected: _themeId(
                      controller?.defaultTheme ?? ThemeMode.system,
                    ),
                    options: [
                      SegmentOption(
                        id: 'system',
                        label: l10n.settingsThemeSystem,
                      ),
                      SegmentOption(
                        id: 'light',
                        label: l10n.settingsThemeLight,
                      ),
                      SegmentOption(id: 'dark', label: l10n.settingsThemeDark),
                    ],
                    onSelected: controller == null
                        ? null
                        : (id) => controller.setDefaultTheme(_themeFromId(id)),
                  ),
                ),
                SettingRow(
                  name: l10n.settingsEngramTheme,
                  description: l10n.settingsEngramThemeDesc,
                  control: SegmentedControl(
                    selected:
                        (controller?.engramThemeChoice ??
                                EngramThemeChoice.followDefault)
                            .name,
                    options: [
                      SegmentOption(
                        id: 'followDefault',
                        label: l10n.settingsThemeFollowDefault,
                      ),
                      SegmentOption(
                        id: 'system',
                        label: l10n.settingsThemeSystem,
                      ),
                      SegmentOption(
                        id: 'light',
                        label: l10n.settingsThemeLight,
                      ),
                      SegmentOption(id: 'dark', label: l10n.settingsThemeDark),
                    ],
                    // Read-only/built-in engrams can't store an override, so the
                    // control is disabled (null handler) for them.
                    onSelected:
                        (controller == null || !controller.canOverridePerEngram)
                        ? null
                        : (id) => controller.setEngramThemeChoice(
                            _engramChoiceFromId(id),
                          ),
                  ),
                ),
              ],
            ),
            SettingSection(
              title: l10n.settingsSectionWindow,
              rows: [
                SettingRow(
                  name: l10n.settingsResetLayout,
                  description: l10n.settingsResetLayoutDesc,
                  control: ButtonsControl(
                    items: [
                      SettingButton(
                        label: l10n.settingsResetLayoutButton,
                        onPressed: controller == null
                            ? null
                            : () async {
                                await controller.resetWindowAndLayout();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.settingsResetLayoutDone,
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        SettingsCategory(
          id: 'housekeeping',
          name: l10n.settingsHousekeepingName,
          initial: 'H',
          description: l10n.settingsHousekeepingDesc,
          // Housekeeping renders a live list of forgettable engrams with actions.
          detail: (ctx) =>
              HousekeepingPane.forRepository(RepositoryScope.of(ctx)),
        ),
        SettingsCategory(
          id: 'about',
          name: l10n.aboutTitle,
          initial: 'i',
          description: l10n.settingsAboutDesc,
          // About renders its own identity/version/links layout inline.
          detail: (_) => const AboutPane(),
        ),
      ],
    ),
  ];
}

String _themeId(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
};

ThemeMode _themeFromId(String id) => switch (id) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

EngramThemeChoice _engramChoiceFromId(String id) => switch (id) {
  'system' => EngramThemeChoice.system,
  'light' => EngramThemeChoice.light,
  'dark' => EngramThemeChoice.dark,
  _ => EngramThemeChoice.followDefault,
};
