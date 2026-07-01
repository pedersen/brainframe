import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDesignLanguage', () {
    test('Apple platforms resolve to Cupertino', () {
      expect(
        resolveDesignLanguage(TargetPlatform.iOS),
        DesignLanguage.cupertino,
      );
      expect(
        resolveDesignLanguage(TargetPlatform.macOS),
        DesignLanguage.cupertino,
      );
    });

    test('non-Apple platforms resolve to Material', () {
      for (final platform in const [
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          resolveDesignLanguage(platform),
          DesignLanguage.material,
          reason: '$platform should be Material',
        );
      }
    });

    test('override wins over the platform default', () {
      expect(
        resolveDesignLanguage(
          TargetPlatform.iOS,
          override: DesignLanguage.material,
        ),
        DesignLanguage.material,
      );
      expect(
        resolveDesignLanguage(
          TargetPlatform.linux,
          override: DesignLanguage.cupertino,
        ),
        DesignLanguage.cupertino,
      );
    });
  });
}
