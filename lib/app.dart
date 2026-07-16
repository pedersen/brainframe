import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'engram/engram.dart';
import 'engram/engram_repository.dart';
import 'engram/engram_startup_gate.dart';
import 'engram/ui/engram_browser.dart';
import 'l10n/gen/app_localizations.dart';
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
      .where((locale) =>
          !(locale.languageCode == 'en' && locale.countryCode == 'XA'))
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
class BrainFrameApp extends StatelessWidget {
  const BrainFrameApp({
    super.key,
    required this.repository,
    this.resolveInitialEngram,
  });

  /// Discovers and remembers engrams; supplies the startup engram and persists
  /// switches. Injected so tests (and later, alternate hosts) can substitute it.
  final EngramRepository repository;

  /// Resolves the engram to open first. Defaults to the repository's usual
  /// last-opened-or-tutorial logic; `main` supplies an override for the
  /// `--engram <path>` startup option.
  final Future<Engram> Function()? resolveInitialEngram;

  @override
  Widget build(BuildContext context) {
    return AppSettings(
      // designOverride: null -> follow the platform. Set it to force a design
      // language anywhere (the themeability seam).
      child: Builder(
        builder: (context) => MaterialApp(
          // Title is localized: onGenerateTitle runs inside a context that has
          // the localizations, so it re-resolves when the locale changes.
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
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
                resolveInitialEngram ?? repository.openInitialEngram,
            onSwitched: (engram) => repository.setLastOpened(engram.id),
            child: EngramBrowser(repository: repository),
          ),
        ),
      ),
    );
  }
}
