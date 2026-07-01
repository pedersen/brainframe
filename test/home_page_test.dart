import 'package:brainframe/home_page.dart';
import 'package:brainframe/theme/app_settings.dart';
import 'package:brainframe/theme/design_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// HomePage renders through the Material AppScaffold (a Scaffold, which supplies
// the Material ancestor its SwitchListTile needs). The Cupertino AppScaffold
// path is exercised separately in test/widgets/app_scaffold_test.dart.
Widget _host() => const MaterialApp(
      home: AppSettings(
        designOverride: DesignLanguage.material,
        child: HomePage(),
      ),
    );

void main() {
  testWidgets('E-ink preview switch toggles on tap', (tester) async {
    await tester.pumpWidget(_host());

    final toggle = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });

  testWidgets('Welcome dialog dismisses on OK', (tester) async {
    await tester.pumpWidget(_host());

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsNothing);
  });
}
