import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// BrainFrame's Material themes, plus the Cupertino override that keeps the
/// Apple-platform look on-brand inside the single MaterialApp root.
///
/// These are static so [MaterialApp] can switch between the normal and
/// high-contrast variants automatically based on `MediaQuery.highContrast`.
/// Two other accessibility signals need no work here: the framework applies
/// `MediaQuery.boldText` to text automatically, and we add no mandatory
/// animations, so `MediaQuery.disableAnimations` (Reduce Motion) is respected
/// by construction. Text scaling is never clamped.
class AppTheme {
  const AppTheme._();

  /// BrainFrame brand indigo, used as the Material seed and Cupertino primary.
  static const Color seed = Color(0xFF4A4FBF);

  static ThemeData get light =>
      _material(Brightness.light, contrastLevel: 0.0);

  static ThemeData get dark => _material(Brightness.dark, contrastLevel: 0.0);

  static ThemeData get lightHighContrast =>
      _material(Brightness.light, contrastLevel: 1.0);

  static ThemeData get darkHighContrast =>
      _material(Brightness.dark, contrastLevel: 1.0);

  static ThemeData _material(
    Brightness brightness, {
    required double contrastLevel,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        contrastLevel: contrastLevel,
      ),
      // Cupertino widgets (used on Apple platforms via AppScaffold) inherit
      // this override instead of the default Material-derived blue.
      cupertinoOverrideTheme: const CupertinoThemeData(primaryColor: seed),
    );
  }
}
