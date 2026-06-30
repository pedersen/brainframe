import 'package:brainframe/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds and shows the home screen', (tester) async {
    await tester.pumpWidget(const BrainFrameApp());

    // Title (in the app bar/nav bar) and the headline both read "BrainFrame".
    expect(find.text('BrainFrame'), findsWidgets);
    expect(find.text('Your second brain and e-reader.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Get started opens the welcome dialog', (tester) async {
    await tester.pumpWidget(const BrainFrameApp());

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('BrainFrame is up and running.'), findsOneWidget);
  });
}
