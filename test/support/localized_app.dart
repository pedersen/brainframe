import 'package:brainframe/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// A [MaterialApp] pre-wired with the app's localization delegates and
/// supported locales, mirroring `lib/app.dart`. Widget tests that pump a widget
/// calling `AppLocalizations.of(context)` must provide these delegates, so use
/// this in place of a bare `MaterialApp(home: ...)`. Pass [locale] to force a
/// specific locale (e.g. the `en_XA` pseudo-locale) instead of the default.
Widget localizedApp({required Widget home, Locale? locale}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
