import 'package:flutter/material.dart';

import '../settings/app_settings_controller.dart';
import 'design_language.dart';

/// App-wide, overridable look-and-feel settings, exposed to the widget tree.
///
/// [designOverride] is the themeability seam: leave it null to follow the host
/// platform (Cupertino on Apple, Material elsewhere), or set it to force a
/// specific design language anywhere. A future settings screen can lift this
/// into mutable state without any screen needing to change.
@immutable
class AppSettings extends InheritedWidget {
  const AppSettings({
    super.key,
    this.designOverride,
    this.themeMode = ThemeMode.system,
    this.controller,
    required super.child,
  });

  final DesignLanguage? designOverride;
  final ThemeMode themeMode;

  /// The mutable state backing these values, exposed so the settings screen can
  /// change them. Null in tests that construct [AppSettings] with fixed values.
  final AppSettingsController? controller;

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettings>();

  static AppSettings of(BuildContext context) {
    final settings = maybeOf(context);
    assert(settings != null, 'No AppSettings found in the widget tree.');
    return settings!;
  }

  /// The active design language: the platform default unless [designOverride]
  /// forces a choice. Requires a Material ancestor (the MaterialApp root).
  DesignLanguage designFor(BuildContext context) => resolveDesignLanguage(
    Theme.of(context).platform,
    override: designOverride,
  );

  @override
  bool updateShouldNotify(AppSettings oldWidget) =>
      designOverride != oldWidget.designOverride ||
      themeMode != oldWidget.themeMode;
}
