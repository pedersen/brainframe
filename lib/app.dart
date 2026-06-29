import 'package:flutter/material.dart';

import 'home_page.dart';
import 'theme/app_settings.dart';
import 'theme/app_theme.dart';

/// The BrainFrame application root.
///
/// A single [MaterialApp] keeps Material ancestors available everywhere, which
/// Flutter's `.adaptive` widgets rely on. The Cupertino feel on Apple
/// platforms comes from [AppSettings]-driven widgets such as `AppScaffold`,
/// not from forking the app root into a separate `CupertinoApp`.
class BrainFrameApp extends StatelessWidget {
  const BrainFrameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSettings(
      // designOverride: null -> follow the platform. Set it to force a design
      // language anywhere (the themeability seam).
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'BrainFrame',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          // MaterialApp switches to these automatically when the platform
          // requests high contrast (MediaQuery.highContrast).
          highContrastTheme: AppTheme.lightHighContrast,
          highContrastDarkTheme: AppTheme.darkHighContrast,
          themeMode: AppSettings.of(context).themeMode,
          home: const HomePage(),
        ),
      ),
    );
  }
}
