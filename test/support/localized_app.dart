import 'package:brainframe/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

/// A [MaterialApp] pre-wired with the app's localization delegates and
/// supported locales, mirroring `lib/app.dart`. Widget tests that pump a widget
/// calling `AppLocalizations.of(context)` must provide these delegates, so use
/// this in place of a bare `MaterialApp(home: ...)`.
Widget localizedApp({required Widget home}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
