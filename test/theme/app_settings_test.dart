import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings.maybeOf / of', () {
    testWidgets('maybeOf returns null with no ancestor', (tester) async {
      AppSettings? found = const AppSettings(child: SizedBox());
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            found = AppSettings.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(found, isNull);
    });

    testWidgets('of finds the nearest AppSettings', (tester) async {
      late AppSettings found;
      await tester.pumpWidget(
        AppSettings(
          child: Builder(
            builder: (context) {
              found = AppSettings.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found.themeMode, ThemeMode.system);
    });
  });

  group('AppSettings.designFor', () {
    testWidgets('follows the platform when no override is set', (tester) async {
      late DesignLanguage design;
      await tester.pumpWidget(
        MaterialApp(
          home: AppSettings(
            child: Builder(
              builder: (context) {
                design = AppSettings.of(context).designFor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // The test platform reports as Android -> Material.
      expect(design, DesignLanguage.material);
    });

    testWidgets('honours a design override', (tester) async {
      late DesignLanguage design;
      await tester.pumpWidget(
        MaterialApp(
          home: AppSettings(
            designOverride: DesignLanguage.cupertino,
            child: Builder(
              builder: (context) {
                design = AppSettings.of(context).designFor(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(design, DesignLanguage.cupertino);
    });
  });

  group('AppSettings.updateShouldNotify', () {
    const base = AppSettings(child: SizedBox());

    test('true when the design override changes', () {
      const changed = AppSettings(
        designOverride: DesignLanguage.cupertino,
        child: SizedBox(),
      );
      expect(changed.updateShouldNotify(base), isTrue);
    });

    test('true when the theme mode changes', () {
      const changed = AppSettings(themeMode: ThemeMode.dark, child: SizedBox());
      expect(changed.updateShouldNotify(base), isTrue);
    });

    test('false when nothing relevant changes', () {
      const same = AppSettings(child: SizedBox());
      expect(same.updateShouldNotify(base), isFalse);
    });
  });
}
