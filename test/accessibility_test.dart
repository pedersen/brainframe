import 'package:brainframe/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home screen meets core accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const BrainFrameApp());
    await tester.pumpAndSettle();

    // Interactive elements are large enough, carry labels, and text has
    // sufficient contrast against its background.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });
}
