import 'package:flutter/widgets.dart';

/// The two design languages BrainFrame renders in.
///
/// We deliberately stay with Flutter's two first-class design systems rather
/// than wrapping a third-party UI framework. Native-look desktop packages
/// (Fluent, Yaru, …) can be added later behind this same seam without changing
/// screen code.
enum DesignLanguage { material, cupertino }

/// Resolves the design language for [platform].
///
/// Apple platforms get Cupertino; everything else gets Material. Pass
/// [override] to force a specific language on any platform — this is the
/// themeability seam that keeps one platform's look from being forced onto
/// another by accident.
DesignLanguage resolveDesignLanguage(
  TargetPlatform platform, {
  DesignLanguage? override,
}) {
  if (override != null) return override;
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return DesignLanguage.cupertino;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return DesignLanguage.material;
  }
}
