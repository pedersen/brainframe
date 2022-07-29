// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:brainframe/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brainframe/widgets/uplifts.dart';

void main() {
  var testapp = MaterialApp(
      title: 'Tester with Layout',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tester with layout'),
        ),
        body:
        Column(
            children: const <Widget>[
            Uplifts(),
          ],
        ),
      )
  );



  testWidgets('Test uplifts functioning', (WidgetTester tester) async {
    const uplift_key = Key("uplift_message");

    // Build our app and trigger a frame.
    await tester.pumpWidget(testapp);

    var textFinder = find.byKey(uplift_key);
    expect(textFinder, findsOneWidget);
    var text = textFinder.evaluate().single.widget as Text;
    var upliftLabelLength = text.data?.length ?? -1;
    expect(upliftLabelLength, greaterThanOrEqualTo(1));

  });
}
