import 'package:brainframe/app.dart';
import 'package:brainframe/engram/engram_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('Home screen meets core accessibility guidelines', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      BrainFrameApp(
        repository: EngramRepository(
          preferences: SharedPreferencesAsync(),
          containerPathResolver: () async =>
              throw UnsupportedError('no filesystem in widget tests'),
        ),
      ),
    );
    await tester.pumpAndSettle(); // resolve the startup engram, then render home

    // Interactive elements are large enough, carry labels, and text has
    // sufficient contrast against its background.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
  });
}
