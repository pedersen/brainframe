import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'engram/engram.dart';
import 'engram/engram_repository.dart';
import 'engram/engram_scope.dart';
import 'engram/engram_startup_gate.dart';
import 'engram/repository_scope.dart';
import 'engram/ui/engram_browser.dart';
import 'l10n/gen/app_localizations.dart';
import 'settings/app_settings_controller.dart';
import 'settings/settings_scope.dart';
import 'theme/app_settings.dart';
import 'theme/app_theme.dart';

/// The locales the app resolves the device against. The pseudo-locale (`en_XA`)
/// is a development/testing aid — it accents and pads every string to surface
/// hardcoded or overflow-prone text — so it is dropped from **release** builds
/// and real users never resolve to it. Parameterized on [releaseMode] (default
/// the ambient [kReleaseMode]) purely so both branches are testable.
List<Locale> appSupportedLocales({bool releaseMode = kReleaseMode}) {
  if (!releaseMode) return AppLocalizations.supportedLocales;
  return AppLocalizations.supportedLocales
      .where(
        (locale) =>
            !(locale.languageCode == 'en' && locale.countryCode == 'XA'),
      )
      .toList();
}

/// The BrainFrame application root.
///
/// A single [MaterialApp] keeps Material ancestors available everywhere, which
/// Flutter's `.adaptive` widgets rely on. The Cupertino feel on Apple
/// platforms comes from [AppSettings]-driven widgets such as `AppScaffold`,
/// not from forking the app root into a separate `CupertinoApp`.
///
/// The active engram is resolved and held below the `MaterialApp` by an
/// [EngramStartupGate] + `EngramScope`, so switching engrams rebuilds only the
/// content, never this root.
class BrainFrameApp extends StatefulWidget {
  const BrainFrameApp({
    super.key,
    required this.repository,
    this.resolveInitialEngram,
    this.settingsController,
  });

  /// Discovers and remembers engrams; supplies the startup engram and persists
  /// switches. Injected so tests (and later, alternate hosts) can substitute it.
  final EngramRepository repository;

  /// Resolves the engram to open first. Defaults to the repository's usual
  /// last-opened-or-tutorial logic; `main` supplies an override for the
  /// `--engram <path>` startup option.
  final Future<Engram> Function()? resolveInitialEngram;

  /// The mutable, persisted look-and-feel state that drives the theme and
  /// design language. `main` supplies one loaded from preferences; tests may
  /// omit it, in which case a default (system theme, no override, no
  /// persistence) is created and owned here.
  final AppSettingsController? settingsController;

  @override
  State<BrainFrameApp> createState() => _BrainFrameAppState();
}

class _BrainFrameAppState extends State<BrainFrameApp> {
  late final AppSettingsController _controller;

  /// Whether we created the controller and must dispose it (vs. one injected by
  /// `main`, whose lifetime it owns).
  late final bool _ownsController = widget.settingsController == null;

  @override
  void initState() {
    super.initState();
    _controller = widget.settingsController ?? AppSettingsController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      // The shared settings store, reachable from anywhere (incl. pushed routes)
      // so features and plugins can declare and persist their own settings.
      store: _controller.store,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => AppSettings(
          themeMode: _controller.themeMode,
          controller: _controller,
          // Above the MaterialApp so pushed routes (Settings → Housekeeping) can
          // reach the repository; EngramScope, which sits at `home`, cannot.
          child: RepositoryScope(
            repository: widget.repository,
            child: Builder(
              builder: (context) => MaterialApp(
                // Title is localized: onGenerateTitle runs inside a context that has
                // the localizations, so it re-resolves when the locale changes.
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: false,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: appSupportedLocales(),
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                // MaterialApp switches to these automatically when the platform
                // requests high contrast (MediaQuery.highContrast).
                highContrastTheme: AppTheme.lightHighContrast,
                highContrastDarkTheme: AppTheme.darkHighContrast,
                themeMode: AppSettings.of(context).themeMode,
                home: EngramStartupGate(
                  resolveInitialEngram:
                      widget.resolveInitialEngram ??
                      widget.repository.openInitialEngram,
                  onSwitched: (engram) =>
                      widget.repository.setLastOpened(engram.id),
                  child: _ActiveEngramThemeReporter(
                    controller: _controller,
                    child: EngramBrowser(repository: widget.repository),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bridges the active engram (which lives below the `MaterialApp` in
/// [EngramScope]) up to the [AppSettingsController] at the root, so per-engram
/// theme overrides resolve. Sits just inside [EngramScope]; its
/// [didChangeDependencies] fires on first build and on every engram switch.
class _ActiveEngramThemeReporter extends StatefulWidget {
  const _ActiveEngramThemeReporter({
    required this.controller,
    required this.child,
  });

  final AppSettingsController controller;
  final Widget child;

  @override
  State<_ActiveEngramThemeReporter> createState() =>
      _ActiveEngramThemeReporterState();
}

class _ActiveEngramThemeReporterState
    extends State<_ActiveEngramThemeReporter> {
  String? _reportedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engram = EngramScope.of(context).engram;
    if (engram.id != _reportedId) {
      _reportedId = engram.id;
      widget.controller.setActiveEngram(engram);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
