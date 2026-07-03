import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_settings.dart';
import '../theme/design_language.dart';

/// A page scaffold that adopts the active design language.
///
/// This is the one place Material and Cupertino genuinely diverge in
/// structure, so it is the one structural helper we keep: a Material
/// [Scaffold] + [AppBar], or a [CupertinoPageScaffold] +
/// [CupertinoNavigationBar]. Everywhere else, screens use Flutter's shared
/// widgets and `.adaptive` constructors directly.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  /// An optional leading control (e.g. a phone menu button). When null, each
  /// design falls back to its default leading behaviour.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final design = AppSettings.of(context).designFor(context);
    // The nav-bar/app-bar title is the screen's heading for assistive tech.
    final heading = Semantics(header: true, child: Text(title));

    switch (design) {
      case DesignLanguage.cupertino:
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: leading,
            middle: heading,
            trailing: (actions == null || actions!.isEmpty)
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ),
          child: SafeArea(child: body),
        );
      case DesignLanguage.material:
        return Scaffold(
          appBar: AppBar(leading: leading, title: heading, actions: actions),
          body: body,
        );
    }
  }
}
